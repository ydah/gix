const std = @import("std");
const Terminal = @import("../../utils/terminal.zig").Terminal;
const Theme = @import("../theme.zig").Theme;

pub const DashboardView = struct {
    unread_notifications: usize,
    open_prs: usize,
    open_issues: usize,
    total_repos: usize,

    pub fn init() DashboardView {
        return DashboardView{
            .unread_notifications = 0,
            .open_prs = 0,
            .open_issues = 0,
            .total_repos = 0,
        };
    }

    pub fn updateStats(self: *DashboardView, notifications: usize, prs: usize, issues: usize, repos: usize) void {
        self.unread_notifications = notifications;
        self.open_prs = prs;
        self.open_issues = issues;
        self.total_repos = repos;
    }

    pub fn render(self: *const DashboardView, terminal: *Terminal, theme: *const Theme, start_row: u16, width: u16) void {
        terminal.moveCursor(start_row, 2);
        terminal.setForeground256(theme.colors.primary);
        terminal.setBold();
        terminal.writeText("📊 Dashboard");
        terminal.resetAttributes();

        terminal.moveCursor(start_row + 2, 4);
        terminal.setForeground256(theme.colors.foreground);
        terminal.writeText("Welcome to gix - Modern GitHub TUI Client");

        const box_width: u16 = @min(25, (width -| 10) / 4);
        const box_start: u16 = 4;

        self.renderStatBox(terminal, theme, start_row + 5, box_start, box_width, "📬 Notifications", self.unread_notifications, "unread");
        self.renderStatBox(terminal, theme, start_row + 5, box_start + box_width + 2, box_width, "🔀 Pull Requests", self.open_prs, "open");
        self.renderStatBox(terminal, theme, start_row + 5, box_start + (box_width + 2) * 2, box_width, "📝 Issues", self.open_issues, "open");
        self.renderStatBox(terminal, theme, start_row + 5, box_start + (box_width + 2) * 3, box_width, "📦 Repositories", self.total_repos, "total");

        terminal.moveCursor(start_row + 12, 4);
        terminal.setForeground256(theme.colors.muted);
        terminal.writeText("Quick Actions:");

        const actions = [_]struct { key: []const u8, desc: []const u8 }{
            .{ .key = "1", .desc = "Dashboard" },
            .{ .key = "2", .desc = "Notifications" },
            .{ .key = "3", .desc = "Pull Requests" },
            .{ .key = "4", .desc = "Issues" },
            .{ .key = "5", .desc = "Repositories" },
            .{ .key = "r", .desc = "Refresh" },
            .{ .key = "q", .desc = "Quit" },
        };

        var action_row: u16 = 0;
        for (actions) |action| {
            terminal.moveCursor(start_row + 14 + action_row, 6);
            terminal.setForeground256(theme.colors.accent);
            terminal.writeText("[");
            terminal.writeText(action.key);
            terminal.writeText("]");
            terminal.setForeground256(theme.colors.foreground);
            terminal.writeText(" ");
            terminal.writeText(action.desc);
            action_row += 1;
        }

        terminal.resetAttributes();
    }

    fn renderStatBox(
        self: *const DashboardView,
        terminal: *Terminal,
        theme: *const Theme,
        row: u16,
        col: u16,
        width: u16,
        title: []const u8,
        value: usize,
        label: []const u8,
    ) void {
        _ = self;

        terminal.setForeground256(theme.colors.border);
        terminal.moveCursor(row, col);
        terminal.writeText("┌");
        var i: u16 = 0;
        while (i < width - 2) : (i += 1) {
            terminal.writeText("─");
        }
        terminal.writeText("┐");

        terminal.moveCursor(row + 1, col);
        terminal.writeText("│");
        terminal.setForeground256(theme.colors.primary);
        const title_padding = (width -| @as(u16, @intCast(title.len)) -| 2) / 2;
        i = 0;
        while (i < title_padding) : (i += 1) {
            terminal.writeText(" ");
        }
        terminal.writeText(title);
        i = 0;
        const remaining = width -| title_padding -| @as(u16, @intCast(title.len)) -| 2;
        while (i < remaining) : (i += 1) {
            terminal.writeText(" ");
        }
        terminal.setForeground256(theme.colors.border);
        terminal.writeText("│");

        terminal.moveCursor(row + 2, col);
        terminal.writeText("│");
        terminal.setForeground256(theme.colors.accent);
        terminal.setBold();
        var num_buf: [16]u8 = undefined;
        const num_text = std.fmt.bufPrint(&num_buf, "{d}", .{value}) catch "?";
        const num_padding = (width -| @as(u16, @intCast(num_text.len)) -| 2) / 2;
        i = 0;
        while (i < num_padding) : (i += 1) {
            terminal.writeText(" ");
        }
        terminal.writeText(num_text);
        i = 0;
        const num_remaining = width -| num_padding -| @as(u16, @intCast(num_text.len)) -| 2;
        while (i < num_remaining) : (i += 1) {
            terminal.writeText(" ");
        }
        terminal.resetAttributes();
        terminal.setForeground256(theme.colors.border);
        terminal.writeText("│");

        terminal.moveCursor(row + 3, col);
        terminal.writeText("│");
        terminal.setForeground256(theme.colors.muted);
        const label_padding = (width -| @as(u16, @intCast(label.len)) -| 2) / 2;
        i = 0;
        while (i < label_padding) : (i += 1) {
            terminal.writeText(" ");
        }
        terminal.writeText(label);
        i = 0;
        const label_remaining = width -| label_padding -| @as(u16, @intCast(label.len)) -| 2;
        while (i < label_remaining) : (i += 1) {
            terminal.writeText(" ");
        }
        terminal.setForeground256(theme.colors.border);
        terminal.writeText("│");

        terminal.moveCursor(row + 4, col);
        terminal.writeText("└");
        i = 0;
        while (i < width - 2) : (i += 1) {
            terminal.writeText("─");
        }
        terminal.writeText("┘");

        terminal.resetAttributes();
    }
};
