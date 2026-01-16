const std = @import("std");
const Terminal = @import("../../utils/terminal.zig").Terminal;
const Theme = @import("../theme.zig").Theme;
const PullRequest = @import("../../domain/models/pull_request.zig").PullRequest;

pub const PullRequestsView = struct {
    pull_requests: []const PullRequest,
    selected_index: usize,
    scroll_offset: usize,
    visible_height: u16,
    loading: bool,
    error_message: ?[]const u8,
    current_repo: ?struct { owner: []const u8, name: []const u8 },

    pub fn init() PullRequestsView {
        return PullRequestsView{
            .pull_requests = &.{},
            .selected_index = 0,
            .scroll_offset = 0,
            .visible_height = 20,
            .loading = false,
            .error_message = null,
            .current_repo = null,
        };
    }

    pub fn setPullRequests(self: *PullRequestsView, prs: []const PullRequest) void {
        self.pull_requests = prs;
        if (self.selected_index >= prs.len and prs.len > 0) {
            self.selected_index = prs.len - 1;
        }
        self.loading = false;
        self.error_message = null;
    }

    pub fn setLoading(self: *PullRequestsView, loading: bool) void {
        self.loading = loading;
    }

    pub fn moveUp(self: *PullRequestsView) void {
        if (self.selected_index > 0) {
            self.selected_index -= 1;
            self.adjustScroll();
        }
    }

    pub fn moveDown(self: *PullRequestsView) void {
        if (self.pull_requests.len > 0 and self.selected_index < self.pull_requests.len - 1) {
            self.selected_index += 1;
            self.adjustScroll();
        }
    }

    pub fn getSelected(self: *const PullRequestsView) ?PullRequest {
        if (self.pull_requests.len == 0) return null;
        return self.pull_requests[self.selected_index];
    }

    fn adjustScroll(self: *PullRequestsView) void {
        if (self.selected_index < self.scroll_offset) {
            self.scroll_offset = self.selected_index;
        }
        const visible = @as(usize, self.visible_height);
        if (self.selected_index >= self.scroll_offset + visible) {
            self.scroll_offset = self.selected_index - visible + 1;
        }
    }

    pub fn render(self: *const PullRequestsView, terminal: *Terminal, theme: *const Theme, start_row: u16, width: u16, height: u16) void {
        const visible_height = height -| 4;

        terminal.moveCursor(start_row, 2);
        terminal.setForeground256(theme.colors.primary);
        terminal.setBold();
        terminal.writeText("🔀 Pull Requests");
        terminal.resetAttributes();

        if (self.loading) {
            terminal.moveCursor(start_row + 2, 4);
            terminal.setForeground256(theme.colors.muted);
            terminal.writeText("Loading pull requests...");
            terminal.resetAttributes();
            return;
        }

        if (self.error_message) |msg| {
            terminal.moveCursor(start_row + 2, 4);
            terminal.setForeground256(theme.colors.error_color);
            terminal.writeText("Error: ");
            terminal.writeText(msg);
            terminal.resetAttributes();
            return;
        }

        if (self.pull_requests.len == 0) {
            terminal.moveCursor(start_row + 2, 4);
            terminal.setForeground256(theme.colors.muted);
            terminal.writeText("No pull requests. Select a repository first.");
            terminal.resetAttributes();
            return;
        }

        terminal.moveCursor(start_row + 1, 2);
        terminal.setForeground256(theme.colors.muted);
        var count_buf: [64]u8 = undefined;
        const count_text = std.fmt.bufPrint(&count_buf, "{d} pull requests", .{self.pull_requests.len}) catch "? pull requests";
        terminal.writeText(count_text);
        terminal.resetAttributes();

        var row: u16 = 0;
        const max_rows = @min(visible_height, @as(u16, @intCast(self.pull_requests.len -| self.scroll_offset)));

        while (row < max_rows) : (row += 1) {
            const item_index = self.scroll_offset + row;
            if (item_index >= self.pull_requests.len) break;

            const pr = self.pull_requests[item_index];
            const is_selected = item_index == self.selected_index;

            terminal.moveCursor(start_row + 3 + row, 2);

            if (is_selected) {
                terminal.setBackground256(theme.colors.selection);
            }

            const state_color = switch (pr.state) {
                .open => theme.colors.success,
                .closed => theme.colors.error_color,
                .merged => theme.colors.accent,
            };
            terminal.setForeground256(state_color);

            const state_icon = switch (pr.state) {
                .open => "○",
                .closed => "●",
                .merged => "◉",
            };
            terminal.writeText(state_icon);
            terminal.writeText(" ");

            terminal.setForeground256(theme.colors.muted);
            var num_buf: [16]u8 = undefined;
            const num_text = std.fmt.bufPrint(&num_buf, "#{d} ", .{pr.number}) catch "#? ";
            terminal.writeText(num_text);

            if (is_selected) {
                terminal.setForeground256(theme.colors.primary);
            } else {
                terminal.setForeground256(theme.colors.foreground);
            }

            const max_title_len = @as(usize, width -| 40);
            const title = if (pr.title.len > max_title_len)
                pr.title[0..max_title_len]
            else
                pr.title;
            terminal.writeText(title);

            if (pr.draft) {
                terminal.setForeground256(theme.colors.muted);
                terminal.writeText(" [draft]");
            }

            terminal.setForeground256(theme.colors.muted);
            terminal.writeText(" by ");
            terminal.writeText(pr.user.login);

            var stats_buf: [32]u8 = undefined;
            const stats_text = std.fmt.bufPrint(&stats_buf, " +{d} -{d}", .{ pr.additions, pr.deletions }) catch "";
            terminal.setForeground256(theme.colors.success);
            if (stats_text.len > 0 and stats_text[0] == '+') {
                terminal.writeText(stats_text[0..std.mem.indexOf(u8, stats_text, " -") orelse stats_text.len]);
            }
            terminal.setForeground256(theme.colors.error_color);
            if (std.mem.indexOf(u8, stats_text, " -")) |idx| {
                terminal.writeText(stats_text[idx..]);
            }

            terminal.resetAttributes();
        }
    }
};
