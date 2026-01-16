const std = @import("std");
const Allocator = std.mem.Allocator;
const Notification = @import("../models/notification.zig").Notification;
const GitHubClient = @import("../../infrastructure/github/client.zig").GitHubClient;
const Endpoints = @import("../../infrastructure/github/endpoints.zig").Endpoints;
const Cache = @import("../../infrastructure/storage/cache.zig").Cache;

pub const NotificationService = struct {
    allocator: Allocator,
    client: *GitHubClient,
    cache: ?*Cache,
    notifications: []Notification,
    capacity: usize,

    pub fn init(allocator: Allocator, client: *GitHubClient, cache: ?*Cache) NotificationService {
        return NotificationService{
            .allocator = allocator,
            .client = client,
            .cache = cache,
            .notifications = &.{},
            .capacity = 0,
        };
    }

    pub fn deinit(self: *NotificationService) void {
        for (self.notifications) |*notif| {
            notif.deinit();
        }
        if (self.capacity > 0) {
            self.allocator.free(self.notifications.ptr[0..self.capacity]);
        }
    }

    pub fn fetch(self: *NotificationService) ![]const Notification {
        const cache_key = "notifications";

        if (self.cache) |cache| {
            if (cache.get(cache_key)) |cached_data| {
                try self.parseNotifications(cached_data);
                return self.notifications;
            }
        }

        var response = try self.client.get(Endpoints.notifications);
        defer response.deinit();

        if (response.status == 200) {
            try self.parseNotifications(response.body);

            if (self.cache) |cache| {
                cache.set(cache_key, response.body) catch {};
            }
        }

        return self.notifications;
    }

    pub fn markAsRead(self: *NotificationService, thread_id: []const u8) !void {
        const endpoint = try Endpoints.notification(self.allocator, thread_id);
        defer self.allocator.free(endpoint);

        var response = try self.client.patch(endpoint, "{}");
        defer response.deinit();

        if (self.cache) |cache| {
            cache.remove("notifications");
        }
    }

    pub fn markAllAsRead(self: *NotificationService) !void {
        var response = try self.client.patch(Endpoints.notifications, "{\"read\": true}");
        defer response.deinit();

        if (self.cache) |cache| {
            cache.remove("notifications");
        }
    }

    fn parseNotifications(self: *NotificationService, json_data: []const u8) !void {
        for (self.notifications) |*notif| {
            notif.deinit();
        }

        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, json_data, .{}) catch return;
        defer parsed.deinit();

        if (parsed.value != .array) return;

        const count = parsed.value.array.items.len;
        if (count > self.capacity) {
            if (self.capacity > 0) {
                self.allocator.free(self.notifications.ptr[0..self.capacity]);
            }
            const new_slice = try self.allocator.alloc(Notification, count);
            self.notifications = new_slice[0..0];
            self.capacity = count;
        }

        var idx: usize = 0;
        for (parsed.value.array.items) |item| {
            const notif = Notification.parseJson(self.allocator, item) catch continue;
            self.notifications.ptr[idx] = notif;
            idx += 1;
        }
        self.notifications = self.notifications.ptr[0..idx];
    }

    pub fn getUnreadCount(self: *const NotificationService) usize {
        var count: usize = 0;
        for (self.notifications) |notif| {
            if (notif.unread) count += 1;
        }
        return count;
    }
};

test "NotificationService initialization" {
    var client = GitHubClient.initWithToken(std.testing.allocator, "test");
    defer client.deinit();

    var service = NotificationService.init(std.testing.allocator, &client, null);
    defer service.deinit();

    try std.testing.expect(service.notifications.len == 0);
}
