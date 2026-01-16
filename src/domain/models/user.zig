const std = @import("std");
const Allocator = std.mem.Allocator;

pub const User = struct {
    id: u64,
    login: []const u8,
    avatar_url: []const u8,
    html_url: []const u8,
    type_: UserType,
    allocator: ?Allocator,

    pub const UserType = enum {
        User,
        Organization,
        Bot,

        pub fn fromString(s: []const u8) UserType {
            if (std.mem.eql(u8, s, "Organization")) return .Organization;
            if (std.mem.eql(u8, s, "Bot")) return .Bot;
            return .User;
        }
    };

    pub fn deinit(self: *User) void {
        if (self.allocator) |alloc| {
            alloc.free(self.login);
            alloc.free(self.avatar_url);
            alloc.free(self.html_url);
        }
    }

    pub fn parseJson(allocator: Allocator, json_value: std.json.Value) !User {
        const obj = json_value.object;

        return User{
            .id = @intCast(obj.get("id").?.integer),
            .login = try allocator.dupe(u8, obj.get("login").?.string),
            .avatar_url = try allocator.dupe(u8, obj.get("avatar_url").?.string),
            .html_url = try allocator.dupe(u8, obj.get("html_url").?.string),
            .type_ = UserType.fromString(obj.get("type").?.string),
            .allocator = allocator,
        };
    }
};

test "User type parsing" {
    try std.testing.expect(User.UserType.fromString("User") == .User);
    try std.testing.expect(User.UserType.fromString("Organization") == .Organization);
    try std.testing.expect(User.UserType.fromString("Bot") == .Bot);
}
