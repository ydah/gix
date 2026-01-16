const std = @import("std");
const Allocator = std.mem.Allocator;
const User = @import("user.zig").User;

pub const PullRequest = struct {
    id: u64,
    number: u32,
    title: []const u8,
    body: ?[]const u8,
    state: PRState,
    user: User,
    created_at: []const u8,
    updated_at: []const u8,
    merged_at: ?[]const u8,
    closed_at: ?[]const u8,
    head: Branch,
    base: Branch,
    draft: bool,
    mergeable: ?bool,
    comments: u32,
    review_comments: u32,
    commits: u32,
    additions: u32,
    deletions: u32,
    changed_files: u32,
    html_url: []const u8,
    allocator: ?Allocator,

    pub const PRState = enum {
        open,
        closed,
        merged,

        pub fn fromString(s: []const u8) PRState {
            if (std.mem.eql(u8, s, "open")) return .open;
            if (std.mem.eql(u8, s, "closed")) return .closed;
            return .closed;
        }

        pub fn toString(self: PRState) []const u8 {
            return switch (self) {
                .open => "open",
                .closed => "closed",
                .merged => "merged",
            };
        }
    };

    pub const Branch = struct {
        ref: []const u8,
        sha: []const u8,
        repo_full_name: ?[]const u8,
    };

    pub const Label = struct {
        id: u64,
        name: []const u8,
        color: []const u8,
    };

    pub fn deinit(self: *PullRequest) void {
        if (self.allocator) |alloc| {
            alloc.free(self.title);
            if (self.body) |body| alloc.free(body);
            var user = self.user;
            user.deinit();
            alloc.free(self.created_at);
            alloc.free(self.updated_at);
            if (self.merged_at) |merged| alloc.free(merged);
            if (self.closed_at) |closed| alloc.free(closed);
            alloc.free(self.head.ref);
            alloc.free(self.head.sha);
            if (self.head.repo_full_name) |name| alloc.free(name);
            alloc.free(self.base.ref);
            alloc.free(self.base.sha);
            if (self.base.repo_full_name) |name| alloc.free(name);
            alloc.free(self.html_url);
        }
    }

    pub fn parseJson(allocator: Allocator, json_value: std.json.Value) !PullRequest {
        const obj = json_value.object;

        const body = if (obj.get("body")) |b| blk: {
            if (b == .null) break :blk null;
            break :blk try allocator.dupe(u8, b.string);
        } else null;

        const merged_at = if (obj.get("merged_at")) |m| blk: {
            if (m == .null) break :blk null;
            break :blk try allocator.dupe(u8, m.string);
        } else null;

        const closed_at = if (obj.get("closed_at")) |c| blk: {
            if (c == .null) break :blk null;
            break :blk try allocator.dupe(u8, c.string);
        } else null;

        const mergeable = if (obj.get("mergeable")) |m| blk: {
            if (m == .null) break :blk null;
            break :blk m.bool;
        } else null;

        const head_obj = obj.get("head").?.object;
        const base_obj = obj.get("base").?.object;

        const head_repo_name = if (head_obj.get("repo")) |repo| blk: {
            if (repo == .null) break :blk null;
            break :blk try allocator.dupe(u8, repo.object.get("full_name").?.string);
        } else null;

        const base_repo_name = if (base_obj.get("repo")) |repo| blk: {
            if (repo == .null) break :blk null;
            break :blk try allocator.dupe(u8, repo.object.get("full_name").?.string);
        } else null;

        var state = PRState.fromString(obj.get("state").?.string);
        if (merged_at != null) {
            state = .merged;
        }

        return PullRequest{
            .id = @intCast(obj.get("id").?.integer),
            .number = @intCast(obj.get("number").?.integer),
            .title = try allocator.dupe(u8, obj.get("title").?.string),
            .body = body,
            .state = state,
            .user = try User.parseJson(allocator, obj.get("user").?),
            .created_at = try allocator.dupe(u8, obj.get("created_at").?.string),
            .updated_at = try allocator.dupe(u8, obj.get("updated_at").?.string),
            .merged_at = merged_at,
            .closed_at = closed_at,
            .head = .{
                .ref = try allocator.dupe(u8, head_obj.get("ref").?.string),
                .sha = try allocator.dupe(u8, head_obj.get("sha").?.string),
                .repo_full_name = head_repo_name,
            },
            .base = .{
                .ref = try allocator.dupe(u8, base_obj.get("ref").?.string),
                .sha = try allocator.dupe(u8, base_obj.get("sha").?.string),
                .repo_full_name = base_repo_name,
            },
            .draft = obj.get("draft").?.bool,
            .mergeable = mergeable,
            .comments = @intCast(obj.get("comments").?.integer),
            .review_comments = @intCast(obj.get("review_comments").?.integer),
            .commits = @intCast(obj.get("commits").?.integer),
            .additions = @intCast(obj.get("additions").?.integer),
            .deletions = @intCast(obj.get("deletions").?.integer),
            .changed_files = @intCast(obj.get("changed_files").?.integer),
            .html_url = try allocator.dupe(u8, obj.get("html_url").?.string),
            .allocator = allocator,
        };
    }
};

test "PRState parsing" {
    try std.testing.expect(PullRequest.PRState.fromString("open") == .open);
    try std.testing.expect(PullRequest.PRState.fromString("closed") == .closed);
}
