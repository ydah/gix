const std = @import("std");
const Terminal = @import("../../utils/terminal.zig").Terminal;
const Theme = @import("../theme.zig").Theme;
const Issue = @import("../../domain/models/issue.zig").Issue;

pub const IssuesView = struct {
    issues: []const Issue,
    selected_index: usize,
    scroll_offset: usize,
    visible_height: u16,
    loading: bool,
    error_message: ?[]const u8,

    pub fn init() IssuesView {
        return IssuesView{
            .issues = &.{},
            .selected_index = 0,
            .scroll_offset = 0,
            .visible_height = 20,
            .loading = false,
            .error_message = null,
        };
    }

    pub fn setIssues(self: *IssuesView, issues: []const Issue) void {
        self.issues = issues;
        if (self.selected_index >= issues.len and issues.len > 0) {
            self.selected_index = issues.len - 1;
        }
        self.loading = false;
        self.error_message = null;
    }

    pub fn setLoading(self: *IssuesView, loading: bool) void {
        self.loading = loading;
    }

    pub fn moveUp(self: *IssuesView) void {
        if (self.selected_index > 0) {
            self.selected_index -= 1;
            self.adjustScroll();
        }
    }

    pub fn moveDown(self: *IssuesView) void {
        if (self.issues.len > 0 and self.selected_index < self.issues.len - 1) {
            self.selected_index += 1;
            self.adjustScroll();
        }
    }

    pub fn getSelected(self: *const IssuesView) ?Issue {
        if (self.issues.len == 0) return null;
        return self.issues[self.selected_index];
    }

    fn adjustScroll(self: *IssuesView) void {
        if (self.selected_index < self.scroll_offset) {
            self.scroll_offset = self.selected_index;
        }
        const visible = @as(usize, self.visible_height);
        if (self.selected_index >= self.scroll_offset + visible) {
            self.scroll_offset = self.selected_index - visible + 1;
        }
    }

    pub fn render(self: *const IssuesView, terminal: *Terminal, theme: *const Theme, start_row: u16, width: u16, height: u16) void {
        const visible_height = height -| 4;

        terminal.moveCursor(start_row, 2);
        terminal.setForeground256(theme.colors.primary);
        terminal.setBold();
        terminal.writeText("📝 Issues");
        terminal.resetAttributes();

        if (self.loading) {
            terminal.moveCursor(start_row + 2, 4);
            terminal.setForeground256(theme.colors.muted);
            terminal.writeText("Loading issues...");
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

        if (self.issues.len == 0) {
            terminal.moveCursor(start_row + 2, 4);
            terminal.setForeground256(theme.colors.muted);
            terminal.writeText("No issues. Select a repository first.");
            terminal.resetAttributes();
            return;
        }

        terminal.moveCursor(start_row + 1, 2);
        terminal.setForeground256(theme.colors.muted);
        var count_buf: [64]u8 = undefined;
        const count_text = std.fmt.bufPrint(&count_buf, "{d} issues", .{self.issues.len}) catch "? issues";
        terminal.writeText(count_text);
        terminal.resetAttributes();

        var row: u16 = 0;
        const max_rows = @min(visible_height, @as(u16, @intCast(self.issues.len -| self.scroll_offset)));

        while (row < max_rows) : (row += 1) {
            const item_index = self.scroll_offset + row;
            if (item_index >= self.issues.len) break;

            const issue = self.issues[item_index];
            const is_selected = item_index == self.selected_index;

            terminal.moveCursor(start_row + 3 + row, 2);

            if (is_selected) {
                terminal.setBackground256(theme.colors.selection);
            }

            const state_color = switch (issue.state) {
                .open => theme.colors.success,
                .closed => theme.colors.error_color,
            };
            terminal.setForeground256(state_color);

            const state_icon = switch (issue.state) {
                .open => "○",
                .closed => "●",
            };
            terminal.writeText(state_icon);
            terminal.writeText(" ");

            terminal.setForeground256(theme.colors.muted);
            var num_buf: [16]u8 = undefined;
            const num_text = std.fmt.bufPrint(&num_buf, "#{d} ", .{issue.number}) catch "#? ";
            terminal.writeText(num_text);

            if (is_selected) {
                terminal.setForeground256(theme.colors.primary);
            } else {
                terminal.setForeground256(theme.colors.foreground);
            }

            const max_title_len = @as(usize, width -| 30);
            const title = if (issue.title.len > max_title_len)
                issue.title[0..max_title_len]
            else
                issue.title;
            terminal.writeText(title);

            terminal.setForeground256(theme.colors.muted);
            terminal.writeText(" by ");
            terminal.writeText(issue.user.login);

            if (issue.comments > 0) {
                var comment_buf: [16]u8 = undefined;
                const comment_text = std.fmt.bufPrint(&comment_buf, " 💬{d}", .{issue.comments}) catch "";
                terminal.writeText(comment_text);
            }

            terminal.resetAttributes();
        }
    }
};
