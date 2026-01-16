const std = @import("std");
const Allocator = std.mem.Allocator;
const Config = @import("../../app/config.zig").Config;
const HttpClient = @import("../../utils/http.zig").HttpClient;

pub const Auth = struct {
    token: []const u8,
    allocator: Allocator,
    owned: bool,

    pub const Header = HttpClient.Header;

    pub fn init(allocator: Allocator) !Auth {
        if (std.posix.getenv("GITHUB_TOKEN")) |token| {
            return Auth{
                .token = token,
                .allocator = allocator,
                .owned = false,
            };
        }

        const config_path = try Config.getDefaultPath(allocator);
        defer allocator.free(config_path);

        var config = try Config.load(allocator, config_path);
        defer config.deinit();

        if (config.auth.token) |token| {
            const owned_token = try allocator.dupe(u8, token);
            return Auth{
                .token = owned_token,
                .allocator = allocator,
                .owned = true,
            };
        }

        return error.NoToken;
    }

    pub fn initWithToken(allocator: Allocator, token: []const u8) Auth {
        return Auth{
            .token = token,
            .allocator = allocator,
            .owned = false,
        };
    }

    pub fn deinit(self: *Auth) void {
        if (self.owned) {
            self.allocator.free(self.token);
        }
    }

    pub fn getAuthorizationHeader(self: *const Auth) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{self.token});
    }

    pub fn getHeaders(self: *const Auth) ![3]Header {
        return [3]Header{
            .{ .name = "Authorization", .value = try self.getAuthorizationHeader() },
            .{ .name = "Accept", .value = "application/vnd.github.v3+json" },
            .{ .name = "User-Agent", .value = "gix/0.1.0" },
        };
    }
};

test "Auth with token" {
    const auth = Auth.initWithToken(std.testing.allocator, "test_token");
    try std.testing.expectEqualStrings("test_token", auth.token);
}
