const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Cache = struct {
    allocator: Allocator,
    store: std.StringHashMap(CacheEntry),
    max_size: usize,
    current_size: usize,
    default_ttl: i64,

    pub const CacheEntry = struct {
        data: []const u8,
        expires_at: i64,
        size: usize,
    };

    pub fn init(allocator: Allocator, max_size: usize, default_ttl: i64) Cache {
        return Cache{
            .allocator = allocator,
            .store = std.StringHashMap(CacheEntry).init(allocator),
            .max_size = max_size,
            .current_size = 0,
            .default_ttl = default_ttl,
        };
    }

    pub fn deinit(self: *Cache) void {
        var it = self.store.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.data);
        }
        self.store.deinit();
    }

    pub fn get(self: *Cache, key: []const u8) ?[]const u8 {
        const entry = self.store.get(key) orelse return null;
        const now = std.time.timestamp();

        if (now > entry.expires_at) {
            self.remove(key);
            return null;
        }

        return entry.data;
    }

    pub fn set(self: *Cache, key: []const u8, data: []const u8) !void {
        try self.setWithTtl(key, data, self.default_ttl);
    }

    pub fn setWithTtl(self: *Cache, key: []const u8, data: []const u8, ttl: i64) !void {
        const data_size = data.len;

        if (self.current_size + data_size > self.max_size) {
            self.evictExpired();
        }

        if (self.current_size + data_size > self.max_size) {
            self.evictOldest();
        }

        if (self.store.get(key)) |existing| {
            self.current_size -= existing.size;
            self.allocator.free(existing.data);
        }

        const owned_key = try self.allocator.dupe(u8, key);
        const owned_data = try self.allocator.dupe(u8, data);
        const expires_at = std.time.timestamp() + ttl;

        try self.store.put(owned_key, .{
            .data = owned_data,
            .expires_at = expires_at,
            .size = data_size,
        });

        self.current_size += data_size;
    }

    pub fn remove(self: *Cache, key: []const u8) void {
        if (self.store.fetchRemove(key)) |kv| {
            self.current_size -= kv.value.size;
            self.allocator.free(kv.key);
            self.allocator.free(kv.value.data);
        }
    }

    pub fn clear(self: *Cache) void {
        var it = self.store.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.data);
        }
        self.store.clearRetainingCapacity();
        self.current_size = 0;
    }

    fn evictExpired(self: *Cache) void {
        const now = std.time.timestamp();
        var keys_to_remove: [64][]const u8 = undefined;
        var remove_count: usize = 0;

        var it = self.store.iterator();
        while (it.next()) |entry| {
            if (now > entry.value_ptr.expires_at) {
                if (remove_count < keys_to_remove.len) {
                    keys_to_remove[remove_count] = entry.key_ptr.*;
                    remove_count += 1;
                }
            }
        }

        for (keys_to_remove[0..remove_count]) |key| {
            self.remove(key);
        }
    }

    fn evictOldest(self: *Cache) void {
        var oldest_key: ?[]const u8 = null;
        var oldest_time: i64 = std.math.maxInt(i64);

        var it = self.store.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.expires_at < oldest_time) {
                oldest_time = entry.value_ptr.expires_at;
                oldest_key = entry.key_ptr.*;
            }
        }

        if (oldest_key) |key| {
            self.remove(key);
        }
    }

    pub fn size(self: *const Cache) usize {
        return self.current_size;
    }

    pub fn count(self: *const Cache) usize {
        return self.store.count();
    }
};

test "Cache basic operations" {
    var cache = Cache.init(std.testing.allocator, 1024, 300);
    defer cache.deinit();

    try cache.set("key1", "value1");
    const value = cache.get("key1");
    try std.testing.expect(value != null);
    try std.testing.expectEqualStrings("value1", value.?);
}

test "Cache eviction" {
    var cache = Cache.init(std.testing.allocator, 20, 300);
    defer cache.deinit();

    try cache.set("key1", "12345678901234567890");
    try cache.set("key2", "short");

    try std.testing.expect(cache.count() <= 2);
}
