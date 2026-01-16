const std = @import("std");
const Allocator = std.mem.Allocator;
const Auth = @import("auth.zig").Auth;
const Endpoints = @import("endpoints.zig").Endpoints;
const HttpClient = @import("../../utils/http.zig").HttpClient;

pub const GitHubClient = struct {
    allocator: Allocator,
    auth: Auth,
    http_client: HttpClient,
    rate_limit: RateLimiter,

    pub const RateLimiter = struct {
        limit: u32,
        remaining: u32,
        reset_at: i64,

        pub fn init() RateLimiter {
            return RateLimiter{
                .limit = 5000,
                .remaining = 5000,
                .reset_at = 0,
            };
        }

        pub fn checkLimit(self: *RateLimiter) !void {
            if (self.remaining == 0) {
                const now = std.time.timestamp();
                if (now < self.reset_at) {
                    return error.RateLimitExceeded;
                }
            }
        }

        pub fn updateFromHeaders(self: *RateLimiter, headers: []const HttpClient.Header) void {
            for (headers) |header| {
                if (std.mem.eql(u8, header.name, "X-RateLimit-Limit")) {
                    self.limit = std.fmt.parseInt(u32, header.value, 10) catch self.limit;
                } else if (std.mem.eql(u8, header.name, "X-RateLimit-Remaining")) {
                    self.remaining = std.fmt.parseInt(u32, header.value, 10) catch self.remaining;
                } else if (std.mem.eql(u8, header.name, "X-RateLimit-Reset")) {
                    self.reset_at = std.fmt.parseInt(i64, header.value, 10) catch self.reset_at;
                }
            }
        }
    };

    pub fn init(allocator: Allocator) !GitHubClient {
        const auth = try Auth.init(allocator);
        return GitHubClient{
            .allocator = allocator,
            .auth = auth,
            .http_client = HttpClient.init(allocator),
            .rate_limit = RateLimiter.init(),
        };
    }

    pub fn initWithToken(allocator: Allocator, token: []const u8) GitHubClient {
        return GitHubClient{
            .allocator = allocator,
            .auth = Auth.initWithToken(allocator, token),
            .http_client = HttpClient.init(allocator),
            .rate_limit = RateLimiter.init(),
        };
    }

    pub fn deinit(self: *GitHubClient) void {
        self.auth.deinit();
        self.http_client.deinit();
    }

    pub fn get(self: *GitHubClient, endpoint: []const u8) !HttpClient.Response {
        try self.rate_limit.checkLimit();

        const url = try Endpoints.buildUrl(self.allocator, endpoint);
        defer self.allocator.free(url);

        const auth_header = try self.auth.getAuthorizationHeader();
        defer self.allocator.free(auth_header);

        const headers = [_]HttpClient.Header{
            .{ .name = "Authorization", .value = auth_header },
            .{ .name = "Accept", .value = "application/vnd.github.v3+json" },
            .{ .name = "User-Agent", .value = "gix/0.1.0" },
        };

        const response = try self.http_client.send(.{
            .method = .GET,
            .url = url,
            .headers = &headers,
            .body = null,
        });

        return response;
    }

    pub fn post(self: *GitHubClient, endpoint: []const u8, body: []const u8) !HttpClient.Response {
        try self.rate_limit.checkLimit();

        const url = try Endpoints.buildUrl(self.allocator, endpoint);
        defer self.allocator.free(url);

        const auth_header = try self.auth.getAuthorizationHeader();
        defer self.allocator.free(auth_header);

        const headers = [_]HttpClient.Header{
            .{ .name = "Authorization", .value = auth_header },
            .{ .name = "Accept", .value = "application/vnd.github.v3+json" },
            .{ .name = "User-Agent", .value = "gix/0.1.0" },
            .{ .name = "Content-Type", .value = "application/json" },
        };

        const response = try self.http_client.send(.{
            .method = .POST,
            .url = url,
            .headers = &headers,
            .body = body,
        });

        return response;
    }

    pub fn patch(self: *GitHubClient, endpoint: []const u8, body: []const u8) !HttpClient.Response {
        try self.rate_limit.checkLimit();

        const url = try Endpoints.buildUrl(self.allocator, endpoint);
        defer self.allocator.free(url);

        const auth_header = try self.auth.getAuthorizationHeader();
        defer self.allocator.free(auth_header);

        const headers = [_]HttpClient.Header{
            .{ .name = "Authorization", .value = auth_header },
            .{ .name = "Accept", .value = "application/vnd.github.v3+json" },
            .{ .name = "User-Agent", .value = "gix/0.1.0" },
            .{ .name = "Content-Type", .value = "application/json" },
        };

        const response = try self.http_client.send(.{
            .method = .PATCH,
            .url = url,
            .headers = &headers,
            .body = body,
        });

        return response;
    }

    pub fn delete(self: *GitHubClient, endpoint: []const u8) !HttpClient.Response {
        try self.rate_limit.checkLimit();

        const url = try Endpoints.buildUrl(self.allocator, endpoint);
        defer self.allocator.free(url);

        const auth_header = try self.auth.getAuthorizationHeader();
        defer self.allocator.free(auth_header);

        const headers = [_]HttpClient.Header{
            .{ .name = "Authorization", .value = auth_header },
            .{ .name = "Accept", .value = "application/vnd.github.v3+json" },
            .{ .name = "User-Agent", .value = "gix/0.1.0" },
        };

        const response = try self.http_client.send(.{
            .method = .DELETE,
            .url = url,
            .headers = &headers,
            .body = null,
        });

        return response;
    }
};

test "GitHubClient with token" {
    var client = GitHubClient.initWithToken(std.testing.allocator, "test_token");
    defer client.deinit();

    try std.testing.expect(client.rate_limit.remaining == 5000);
}

test "RateLimiter" {
    var limiter = GitHubClient.RateLimiter.init();
    try std.testing.expect(limiter.remaining == 5000);

    try limiter.checkLimit();

    limiter.remaining = 0;
    limiter.reset_at = std.time.timestamp() + 3600;
    try std.testing.expectError(error.RateLimitExceeded, limiter.checkLimit());
}
