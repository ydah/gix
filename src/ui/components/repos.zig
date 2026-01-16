const std = @import("std");
const Terminal = @import("../../utils/terminal.zig").Terminal;
const Theme = @import("../theme.zig").Theme;
const Repository = @import("../../domain/models/repository.zig").Repository;

pub const ReposView = struct {
    repositories: []const Repository,
    selected_index: usize,
    scroll_offset: usize,
    visible_height: u16,
    loading: bool,
    error_message: ?[]const u8,
    search_query: [128]u8,
    search_len: usize,
    search_mode: bool,

    pub fn init() ReposView {
        return ReposView{
            .repositories = &.{},
            .selected_index = 0,
            .scroll_offset = 0,
            .visible_height = 20,
            .loading = false,
            .error_message = null,
            .search_query = undefined,
            .search_len = 0,
            .search_mode = false,
        };
    }

    pub fn setRepositories(self: *ReposView, repos: []const Repository) void {
        self.repositories = repos;
        if (self.selected_index >= repos.len and repos.len > 0) {
            self.selected_index = repos.len - 1;
        }
        self.loading = false;
        self.error_message = null;
    }

    pub fn setLoading(self: *ReposView, loading: bool) void {
        self.loading = loading;
    }

    pub fn moveUp(self: *ReposView) void {
        if (self.selected_index > 0) {
            self.selected_index -= 1;
            self.adjustScroll();
        }
    }

    pub fn moveDown(self: *ReposView) void {
        if (self.repositories.len > 0 and self.selected_index < self.repositories.len - 1) {
            self.selected_index += 1;
            self.adjustScroll();
        }
    }

    pub fn getSelected(self: *const ReposView) ?Repository {
        if (self.repositories.len == 0) return null;
        return self.repositories[self.selected_index];
    }

    fn adjustScroll(self: *ReposView) void {
        if (self.selected_index < self.scroll_offset) {
            self.scroll_offset = self.selected_index;
        }
        const visible = @as(usize, self.visible_height);
        if (self.selected_index >= self.scroll_offset + visible) {
            self.scroll_offset = self.selected_index - visible + 1;
        }
    }

    pub fn toggleSearchMode(self: *ReposView) void {
        self.search_mode = !self.search_mode;
        if (!self.search_mode) {
            self.search_len = 0;
        }
    }

    pub fn render(self: *const ReposView, terminal: *Terminal, theme: *const Theme, start_row: u16, width: u16, height: u16) void {
        const visible_height = height -| 5;

        terminal.moveCursor(start_row, 2);
        terminal.setForeground256(theme.colors.primary);
        terminal.setBold();
        terminal.writeText("📦 Repositories");
        terminal.resetAttributes();

        if (self.search_mode) {
            terminal.moveCursor(start_row + 1, 2);
            terminal.setForeground256(theme.colors.accent);
            terminal.writeText("Search: ");
            terminal.setForeground256(theme.colors.foreground);
            if (self.search_len > 0) {
                terminal.writeText(self.search_query[0..self.search_len]);
            } else {
                terminal.setForeground256(theme.colors.muted);
                terminal.writeText("Type to search...");
            }
            terminal.resetAttributes();
        }

        if (self.loading) {
            terminal.moveCursor(start_row + 3, 4);
            terminal.setForeground256(theme.colors.muted);
            terminal.writeText("Loading repositories...");
            terminal.resetAttributes();
            return;
        }

        if (self.error_message) |msg| {
            terminal.moveCursor(start_row + 3, 4);
            terminal.setForeground256(theme.colors.error_color);
            terminal.writeText("Error: ");
            terminal.writeText(msg);
            terminal.resetAttributes();
            return;
        }

        if (self.repositories.len == 0) {
            terminal.moveCursor(start_row + 3, 4);
            terminal.setForeground256(theme.colors.muted);
            terminal.writeText("No repositories found");
            terminal.resetAttributes();
            return;
        }

        terminal.moveCursor(start_row + 2, 2);
        terminal.setForeground256(theme.colors.muted);
        var count_buf: [64]u8 = undefined;
        const count_text = std.fmt.bufPrint(&count_buf, "{d} repositories", .{self.repositories.len}) catch "? repositories";
        terminal.writeText(count_text);
        terminal.resetAttributes();

        var row: u16 = 0;
        const max_rows = @min(visible_height, @as(u16, @intCast(self.repositories.len -| self.scroll_offset)));

        while (row < max_rows) : (row += 1) {
            const item_index = self.scroll_offset + row;
            if (item_index >= self.repositories.len) break;

            const repo = self.repositories[item_index];
            const is_selected = item_index == self.selected_index;

            terminal.moveCursor(start_row + 4 + row, 2);

            if (is_selected) {
                terminal.setBackground256(theme.colors.selection);
            }

            if (repo.private) {
                terminal.setForeground256(theme.colors.warning);
                terminal.writeText("🔒 ");
            } else {
                terminal.setForeground256(theme.colors.success);
                terminal.writeText("📂 ");
            }

            if (is_selected) {
                terminal.setForeground256(theme.colors.primary);
            } else {
                terminal.setForeground256(theme.colors.foreground);
            }

            const max_name_len = @as(usize, width -| 50);
            const name = if (repo.full_name.len > max_name_len)
                repo.full_name[0..max_name_len]
            else
                repo.full_name;
            terminal.writeText(name);

            terminal.setForeground256(theme.colors.muted);

            if (repo.language) |lang| {
                terminal.writeText(" [");
                const max_lang_len: usize = 10;
                const lang_text = if (lang.len > max_lang_len) lang[0..max_lang_len] else lang;
                terminal.writeText(lang_text);
                terminal.writeText("]");
            }

            var stats_buf: [32]u8 = undefined;
            const stats_text = std.fmt.bufPrint(&stats_buf, " ⭐{d} 🍴{d}", .{ repo.stargazers_count, repo.forks_count }) catch "";
            terminal.writeText(stats_text);

            terminal.resetAttributes();
        }
    }
};
