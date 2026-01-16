const std = @import("std");
const Allocator = std.mem.Allocator;
const User = @import("user.zig").User;

pub const Repository = struct {
    id: u64,
    name: []const u8,
    full_name: []const u8,
    owner: User,
    description: ?[]const u8,
    private: bool,
    fork: bool,
    created_at: []const u8,
    updated_at: []const u8,
    pushed_at: ?[]const u8,
    size: u64,
    stargazers_count: u32,
    watchers_count: u32,
    forks_count: u32,
    open_issues_count: u32,
    language: ?[]const u8,
    default_branch: []const u8,
    clone_url: []const u8,
    ssh_url: []const u8,
    html_url: []const u8,
    allocator: ?Allocator,

    pub fn deinit(self: *Repository) void {
        if (self.allocator) |alloc| {
            alloc.free(self.name);
            alloc.free(self.full_name);
            if (self.description) |desc| alloc.free(desc);
            alloc.free(self.created_at);
            alloc.free(self.updated_at);
            if (self.pushed_at) |pushed| alloc.free(pushed);
            if (self.language) |lang| alloc.free(lang);
            alloc.free(self.default_branch);
            alloc.free(self.clone_url);
            alloc.free(self.ssh_url);
            alloc.free(self.html_url);
            var owner = self.owner;
            owner.deinit();
        }
    }

    pub fn parseJson(allocator: Allocator, json_value: std.json.Value) !Repository {
        const obj = json_value.object;

        const description = if (obj.get("description")) |desc| blk: {
            if (desc == .null) break :blk null;
            break :blk try allocator.dupe(u8, desc.string);
        } else null;

        const pushed_at = if (obj.get("pushed_at")) |pushed| blk: {
            if (pushed == .null) break :blk null;
            break :blk try allocator.dupe(u8, pushed.string);
        } else null;

        const language = if (obj.get("language")) |lang| blk: {
            if (lang == .null) break :blk null;
            break :blk try allocator.dupe(u8, lang.string);
        } else null;

        return Repository{
            .id = @intCast(obj.get("id").?.integer),
            .name = try allocator.dupe(u8, obj.get("name").?.string),
            .full_name = try allocator.dupe(u8, obj.get("full_name").?.string),
            .owner = try User.parseJson(allocator, obj.get("owner").?),
            .description = description,
            .private = obj.get("private").?.bool,
            .fork = obj.get("fork").?.bool,
            .created_at = try allocator.dupe(u8, obj.get("created_at").?.string),
            .updated_at = try allocator.dupe(u8, obj.get("updated_at").?.string),
            .pushed_at = pushed_at,
            .size = @intCast(obj.get("size").?.integer),
            .stargazers_count = @intCast(obj.get("stargazers_count").?.integer),
            .watchers_count = @intCast(obj.get("watchers_count").?.integer),
            .forks_count = @intCast(obj.get("forks_count").?.integer),
            .open_issues_count = @intCast(obj.get("open_issues_count").?.integer),
            .language = language,
            .default_branch = try allocator.dupe(u8, obj.get("default_branch").?.string),
            .clone_url = try allocator.dupe(u8, obj.get("clone_url").?.string),
            .ssh_url = try allocator.dupe(u8, obj.get("ssh_url").?.string),
            .html_url = try allocator.dupe(u8, obj.get("html_url").?.string),
            .allocator = allocator,
        };
    }
};
