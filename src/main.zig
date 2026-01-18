const std = @import("std");

pub const app = @import("app/app.zig");
pub const config = @import("app/config.zig");
pub const state = @import("app/state.zig");

pub const logger = @import("utils/logger.zig");
pub const http = @import("utils/http.zig");
pub const terminal = @import("utils/terminal.zig");

pub const github_auth = @import("infrastructure/github/auth.zig");
pub const github_client = @import("infrastructure/github/client.zig");
pub const github_endpoints = @import("infrastructure/github/endpoints.zig");

pub const notification = @import("domain/models/notification.zig");
pub const pull_request = @import("domain/models/pull_request.zig");
pub const issue = @import("domain/models/issue.zig");
pub const repository = @import("domain/models/repository.zig");
pub const user = @import("domain/models/user.zig");

pub const tui = @import("ui/tui.zig");
pub const theme = @import("ui/theme.zig");
pub const renderer = @import("ui/renderer.zig");

pub const list_widget = @import("ui/widgets/list.zig");
pub const input_widget = @import("ui/widgets/input.zig");
pub const table_widget = @import("ui/widgets/table.zig");
pub const modal_widget = @import("ui/widgets/modal.zig");
pub const statusbar_widget = @import("ui/widgets/statusbar.zig");

pub const dashboard_component = @import("ui/components/dashboard.zig");
pub const notifications_component = @import("ui/components/notifications.zig");
pub const pull_requests_component = @import("ui/components/pull_requests.zig");
pub const issues_component = @import("ui/components/issues.zig");
pub const repos_component = @import("ui/components/repos.zig");

pub const cache = @import("infrastructure/storage/cache.zig");
pub const git_clone = @import("infrastructure/git/clone.zig");

pub const notification_service = @import("domain/services/notification_service.zig");
pub const pr_service = @import("domain/services/pr_service.zig");
pub const repo_service = @import("domain/services/repo_service.zig");

pub const version = "0.1.0";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const stdout = std.fs.File.stdout();

    if (args.len > 1) {
        if (std.mem.eql(u8, args[1], "--version") or std.mem.eql(u8, args[1], "-v")) {
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "gix v{s}\n", .{version}) catch unreachable;
            try stdout.writeAll(msg);
            return;
        } else if (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h")) {
            try printHelp(stdout);
            return;
        } else if (std.mem.eql(u8, args[1], "--setup")) {
            try setupConfig(allocator, stdout);
            return;
        }
    }

    var application = app.App.init(allocator) catch |err| {
        switch (err) {
            error.NoToken => {
                try stdout.writeAll("Error: GitHub token not found.\n");
                try stdout.writeAll("Please set GITHUB_TOKEN environment variable or run: gix --setup\n");
                return;
            },
            else => return err,
        }
    };
    defer application.deinit();

    try application.run();
}

fn printHelp(stdout: std.fs.File) !void {
    try stdout.writeAll(
        \\gix - Modern GitHub TUI Client
        \\
        \\Usage: gix [OPTIONS]
        \\
        \\Options:
        \\  -v, --version    Show version information
        \\  -h, --help       Show this help message
        \\  --setup          Run initial setup wizard
        \\
        \\Key Bindings:
        \\  q            Quit
        \\  1-5          Switch between views
        \\  r            Refresh current view
        \\  /            Search
        \\  ?            Show help
        \\
        \\Environment Variables:
        \\  GITHUB_TOKEN    GitHub Personal Access Token
        \\
    );
}

fn setupConfig(allocator: std.mem.Allocator, stdout: std.fs.File) !void {
    const stdin = std.fs.File.stdin();

    try stdout.writeAll("gix Setup\n\n");
    try stdout.writeAll("Please enter your GitHub Personal Access Token:\n");
    try stdout.writeAll("(You can create one at: https://github.com/settings/tokens)\n");
    try stdout.writeAll("Token: ");

    var buf: [256]u8 = undefined;
    const bytes_read = try stdin.read(&buf);
    if (bytes_read == 0) return;

    var token = buf[0..bytes_read];
    if (token.len > 0 and token[token.len - 1] == '\n') {
        token = token[0 .. token.len - 1];
    }

    var cfg = config.Config.init(allocator);
    cfg.auth.token = try allocator.dupe(u8, token);

    const config_path = try config.Config.getDefaultPath(allocator);
    defer allocator.free(config_path);

    try cfg.save(config_path);
    cfg.deinit();

    try stdout.writeAll("\nConfiguration saved successfully!\n");
    try stdout.writeAll("You can now run: gix\n");
}

test "version is defined" {
    try std.testing.expectEqualStrings("0.1.0", version);
}
