const std = @import("std");
const Allocator = std.mem.Allocator;
const User = @import("user.zig").User;

pub const Issue = struct {
    id: u64,
    number: u32,
    title: []const u8,
    body: ?[]const u8,
    state: IssueState,
    user: User,
    comments: u32,
    created_at: []const u8,
    updated_at: []const u8,
    closed_at: ?[]const u8,
    html_url: []const u8,
    labels: []Label,
    allocator: ?Allocator,

    pub const IssueState = enum {
        open,
        closed,

        pub fn fromString(s: []const u8) IssueState {
            if (std.mem.eql(u8, s, "open")) return .open;
            return .closed;
        }

        pub fn toString(self: IssueState) []const u8 {
            return switch (self) {
                .open => "open",
                .closed => "closed",
            };
        }
    };

    pub const Label = struct {
        id: u64,
        name: []const u8,
        color: []const u8,
        description: ?[]const u8,
    };

    pub fn deinit(self: *Issue) void {
        if (self.allocator) |alloc| {
            alloc.free(self.title);
            if (self.body) |body| alloc.free(body);
            var user = self.user;
            user.deinit();
            alloc.free(self.created_at);
            alloc.free(self.updated_at);
            if (self.closed_at) |closed| alloc.free(closed);
            alloc.free(self.html_url);
            for (self.labels) |label| {
                alloc.free(label.name);
                alloc.free(label.color);
                if (label.description) |desc| alloc.free(desc);
            }
            if (self.labels.len > 0) {
                alloc.free(self.labels);
            }
        }
    }

    pub fn parseJson(allocator: Allocator, json_value: std.json.Value) !Issue {
        const obj = json_value.object;

        const body = if (obj.get("body")) |b| blk: {
            if (b == .null) break :blk null;
            break :blk try allocator.dupe(u8, b.string);
        } else null;

        const closed_at = if (obj.get("closed_at")) |c| blk: {
            if (c == .null) break :blk null;
            break :blk try allocator.dupe(u8, c.string);
        } else null;

        var labels: []Label = &.{};
        if (obj.get("labels")) |labels_json| {
            if (labels_json == .array and labels_json.array.items.len > 0) {
                labels = try allocator.alloc(Label, labels_json.array.items.len);
                var idx: usize = 0;
                for (labels_json.array.items) |label_json| {
                    const label_obj = label_json.object;
                    const description = if (label_obj.get("description")) |d| blk: {
                        if (d == .null) break :blk null;
                        break :blk try allocator.dupe(u8, d.string);
                    } else null;

                    labels[idx] = .{
                        .id = @intCast(label_obj.get("id").?.integer),
                        .name = try allocator.dupe(u8, label_obj.get("name").?.string),
                        .color = try allocator.dupe(u8, label_obj.get("color").?.string),
                        .description = description,
                    };
                    idx += 1;
                }
            }
        }

        return Issue{
            .id = @intCast(obj.get("id").?.integer),
            .number = @intCast(obj.get("number").?.integer),
            .title = try allocator.dupe(u8, obj.get("title").?.string),
            .body = body,
            .state = IssueState.fromString(obj.get("state").?.string),
            .user = try User.parseJson(allocator, obj.get("user").?),
            .comments = @intCast(obj.get("comments").?.integer),
            .created_at = try allocator.dupe(u8, obj.get("created_at").?.string),
            .updated_at = try allocator.dupe(u8, obj.get("updated_at").?.string),
            .closed_at = closed_at,
            .html_url = try allocator.dupe(u8, obj.get("html_url").?.string),
            .labels = labels,
            .allocator = allocator,
        };
    }
};

test "IssueState parsing" {
    try std.testing.expect(Issue.IssueState.fromString("open") == .open);
    try std.testing.expect(Issue.IssueState.fromString("closed") == .closed);
}
