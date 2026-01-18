const std = @import("std");
const Allocator = std.mem.Allocator;

pub const CloneResult = struct {
    success: bool,
    message: []const u8,
    path: ?[]const u8,
    allocator: Allocator,

    pub fn deinit(self: *CloneResult) void {
        self.allocator.free(self.message);
        if (self.path) |p| {
            self.allocator.free(p);
        }
    }
};

pub const CloneOptions = struct {
    depth: ?u32 = null,
    branch: ?[]const u8 = null,
    single_branch: bool = false,
    recursive: bool = false,
    quiet: bool = true,
};

pub const GitClone = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) GitClone {
        return GitClone{
            .allocator = allocator,
        };
    }

    pub fn clone(self: *GitClone, url: []const u8, dest: ?[]const u8, options: CloneOptions) !CloneResult {
        var args = std.ArrayList([]const u8).init(self.allocator);
        defer args.deinit();

        try args.append("git");
        try args.append("clone");

        if (options.quiet) {
            try args.append("--quiet");
        }

        if (options.depth) |d| {
            try args.append("--depth");
            const depth_str = try std.fmt.allocPrint(self.allocator, "{d}", .{d});
            try args.append(depth_str);
        }

        if (options.branch) |b| {
            try args.append("--branch");
            try args.append(b);
        }

        if (options.single_branch) {
            try args.append("--single-branch");
        }

        if (options.recursive) {
            try args.append("--recursive");
        }

        try args.append(url);

        if (dest) |d| {
            try args.append(d);
        }

        const argv = args.items;

        var child = std.process.Child.init(argv, self.allocator);
        child.stderr_behavior = .Pipe;
        child.stdout_behavior = .Pipe;

        try child.spawn();

        const stderr = child.stderr.?;
        const stdout = child.stdout.?;

        var stderr_output = std.ArrayList(u8).init(self.allocator);
        defer stderr_output.deinit();
        var stdout_output = std.ArrayList(u8).init(self.allocator);
        defer stdout_output.deinit();

        var stderr_buf: [4096]u8 = undefined;
        var stdout_buf: [4096]u8 = undefined;

        while (true) {
            const stderr_read = stderr.read(&stderr_buf) catch break;
            if (stderr_read == 0) break;
            try stderr_output.appendSlice(stderr_buf[0..stderr_read]);
        }

        while (true) {
            const stdout_read = stdout.read(&stdout_buf) catch break;
            if (stdout_read == 0) break;
            try stdout_output.appendSlice(stdout_buf[0..stdout_read]);
        }

        const result = child.wait();

        const exit_code = result.Exited;
        const success = exit_code == 0;

        const dest_path = if (dest) |d|
            try self.allocator.dupe(u8, d)
        else
            try extractRepoName(self.allocator, url);

        const message = if (success)
            try std.fmt.allocPrint(self.allocator, "Successfully cloned to {s}", .{dest_path orelse "current directory"})
        else
            try self.allocator.dupe(u8, stderr_output.items);

        return CloneResult{
            .success = success,
            .message = message,
            .path = if (success) dest_path else null,
            .allocator = self.allocator,
        };
    }

    pub fn cloneFromGitHub(self: *GitClone, owner: []const u8, repo: []const u8, dest: ?[]const u8, use_ssh: bool, options: CloneOptions) !CloneResult {
        const url = if (use_ssh)
            try std.fmt.allocPrint(self.allocator, "git@github.com:{s}/{s}.git", .{ owner, repo })
        else
            try std.fmt.allocPrint(self.allocator, "https://github.com/{s}/{s}.git", .{ owner, repo });
        defer self.allocator.free(url);

        return self.clone(url, dest, options);
    }
};

fn extractRepoName(allocator: Allocator, url: []const u8) !?[]const u8 {
    var name = url;

    if (std.mem.endsWith(u8, name, ".git")) {
        name = name[0 .. name.len - 4];
    }

    if (std.mem.lastIndexOf(u8, name, "/")) |idx| {
        name = name[idx + 1 ..];
    } else if (std.mem.lastIndexOf(u8, name, ":")) |idx| {
        name = name[idx + 1 ..];
    }

    if (name.len > 0) {
        return try allocator.dupe(u8, name);
    }
    return null;
}

test "extractRepoName from HTTPS URL" {
    const allocator = std.testing.allocator;

    const result = try extractRepoName(allocator, "https://github.com/owner/repo.git");
    defer if (result) |r| allocator.free(r);

    try std.testing.expectEqualStrings("repo", result.?);
}

test "extractRepoName from SSH URL" {
    const allocator = std.testing.allocator;

    const result = try extractRepoName(allocator, "git@github.com:owner/repo.git");
    defer if (result) |r| allocator.free(r);

    try std.testing.expectEqualStrings("repo", result.?);
}

test "GitClone init" {
    const allocator = std.testing.allocator;
    const git_clone = GitClone.init(allocator);
    _ = git_clone;
}
