const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Endpoints = struct {
    pub const base_url = "https://api.github.com";

    pub const notifications = "/notifications";
    pub const user = "/user";
    pub const repos = "/user/repos";

    pub fn notification(allocator: Allocator, thread_id: []const u8) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "/notifications/threads/{s}", .{thread_id});
    }

    pub fn pullRequests(allocator: Allocator, owner: []const u8, repo: []const u8) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/pulls", .{ owner, repo });
    }

    pub fn pullRequest(allocator: Allocator, owner: []const u8, repo: []const u8, number: u32) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/pulls/{d}", .{ owner, repo, number });
    }

    pub fn issues(allocator: Allocator, owner: []const u8, repo: []const u8) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/issues", .{ owner, repo });
    }

    pub fn issue(allocator: Allocator, owner: []const u8, repo: []const u8, number: u32) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/issues/{d}", .{ owner, repo, number });
    }

    pub fn repository(allocator: Allocator, owner: []const u8, repo: []const u8) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "/repos/{s}/{s}", .{ owner, repo });
    }

    pub fn searchRepos(allocator: Allocator, query: []const u8) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "/search/repositories?q={s}", .{query});
    }

    pub fn buildUrl(allocator: Allocator, endpoint: []const u8) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "{s}{s}", .{ base_url, endpoint });
    }
};

test "Endpoints building" {
    const allocator = std.testing.allocator;

    const pr_endpoint = try Endpoints.pullRequest(allocator, "owner", "repo", 123);
    defer allocator.free(pr_endpoint);
    try std.testing.expectEqualStrings("/repos/owner/repo/pulls/123", pr_endpoint);

    const url = try Endpoints.buildUrl(allocator, Endpoints.notifications);
    defer allocator.free(url);
    try std.testing.expectEqualStrings("https://api.github.com/notifications", url);
}
