const std = @import("std");
const Allocator = std.mem.Allocator;
const PullRequest = @import("../models/pull_request.zig").PullRequest;
const Issue = @import("../models/issue.zig").Issue;
const GitHubClient = @import("../../infrastructure/github/client.zig").GitHubClient;
const Endpoints = @import("../../infrastructure/github/endpoints.zig").Endpoints;
const Cache = @import("../../infrastructure/storage/cache.zig").Cache;

pub const PRService = struct {
    allocator: Allocator,
    client: *GitHubClient,
    cache: ?*Cache,
    pull_requests: []PullRequest,
    pr_capacity: usize,
    issues: []Issue,
    issue_capacity: usize,

    pub fn init(allocator: Allocator, client: *GitHubClient, cache: ?*Cache) PRService {
        return PRService{
            .allocator = allocator,
            .client = client,
            .cache = cache,
            .pull_requests = &.{},
            .pr_capacity = 0,
            .issues = &.{},
            .issue_capacity = 0,
        };
    }

    pub fn deinit(self: *PRService) void {
        for (self.pull_requests) |*pr| {
            pr.deinit();
        }
        if (self.pr_capacity > 0) {
            self.allocator.free(self.pull_requests.ptr[0..self.pr_capacity]);
        }

        for (self.issues) |*issue| {
            issue.deinit();
        }
        if (self.issue_capacity > 0) {
            self.allocator.free(self.issues.ptr[0..self.issue_capacity]);
        }
    }

    pub fn fetchPullRequests(self: *PRService, owner: []const u8, repo: []const u8) ![]const PullRequest {
        const endpoint = try Endpoints.pullRequests(self.allocator, owner, repo);
        defer self.allocator.free(endpoint);

        var cache_key_buf: [256]u8 = undefined;
        const cache_key = std.fmt.bufPrint(&cache_key_buf, "prs_{s}_{s}", .{ owner, repo }) catch "prs";

        if (self.cache) |cache| {
            if (cache.get(cache_key)) |cached_data| {
                try self.parsePullRequests(cached_data);
                return self.pull_requests;
            }
        }

        var response = try self.client.get(endpoint);
        defer response.deinit();

        if (response.status == 200) {
            try self.parsePullRequests(response.body);

            if (self.cache) |cache| {
                cache.set(cache_key, response.body) catch {};
            }
        }

        return self.pull_requests;
    }

    pub fn fetchIssues(self: *PRService, owner: []const u8, repo: []const u8) ![]const Issue {
        const endpoint = try Endpoints.issues(self.allocator, owner, repo);
        defer self.allocator.free(endpoint);

        var cache_key_buf: [256]u8 = undefined;
        const cache_key = std.fmt.bufPrint(&cache_key_buf, "issues_{s}_{s}", .{ owner, repo }) catch "issues";

        if (self.cache) |cache| {
            if (cache.get(cache_key)) |cached_data| {
                try self.parseIssues(cached_data);
                return self.issues;
            }
        }

        var response = try self.client.get(endpoint);
        defer response.deinit();

        if (response.status == 200) {
            try self.parseIssues(response.body);

            if (self.cache) |cache| {
                cache.set(cache_key, response.body) catch {};
            }
        }

        return self.issues;
    }

    fn parsePullRequests(self: *PRService, json_data: []const u8) !void {
        for (self.pull_requests) |*pr| {
            pr.deinit();
        }

        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, json_data, .{}) catch return;
        defer parsed.deinit();

        if (parsed.value != .array) return;

        const count = parsed.value.array.items.len;
        if (count > self.pr_capacity) {
            if (self.pr_capacity > 0) {
                self.allocator.free(self.pull_requests.ptr[0..self.pr_capacity]);
            }
            const new_slice = try self.allocator.alloc(PullRequest, count);
            self.pull_requests = new_slice[0..0];
            self.pr_capacity = count;
        }

        var idx: usize = 0;
        for (parsed.value.array.items) |item| {
            const pr = PullRequest.parseJson(self.allocator, item) catch continue;
            self.pull_requests.ptr[idx] = pr;
            idx += 1;
        }
        self.pull_requests = self.pull_requests.ptr[0..idx];
    }

    fn parseIssues(self: *PRService, json_data: []const u8) !void {
        for (self.issues) |*issue| {
            issue.deinit();
        }

        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, json_data, .{}) catch return;
        defer parsed.deinit();

        if (parsed.value != .array) return;

        const count = parsed.value.array.items.len;
        if (count > self.issue_capacity) {
            if (self.issue_capacity > 0) {
                self.allocator.free(self.issues.ptr[0..self.issue_capacity]);
            }
            const new_slice = try self.allocator.alloc(Issue, count);
            self.issues = new_slice[0..0];
            self.issue_capacity = count;
        }

        var idx: usize = 0;
        for (parsed.value.array.items) |item| {
            if (item.object.get("pull_request") != null) continue;
            const issue = Issue.parseJson(self.allocator, item) catch continue;
            self.issues.ptr[idx] = issue;
            idx += 1;
        }
        self.issues = self.issues.ptr[0..idx];
    }
};

test "PRService initialization" {
    var client = GitHubClient.initWithToken(std.testing.allocator, "test");
    defer client.deinit();

    var service = PRService.init(std.testing.allocator, &client, null);
    defer service.deinit();

    try std.testing.expect(service.pull_requests.len == 0);
}
