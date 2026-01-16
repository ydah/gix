const std = @import("std");
const Terminal = @import("../utils/terminal.zig").Terminal;
const Theme = @import("theme.zig").Theme;
const Renderer = @import("renderer.zig").Renderer;

const DashboardView = @import("components/dashboard.zig").DashboardView;
const NotificationsView = @import("components/notifications.zig").NotificationsView;
const PullRequestsView = @import("components/pull_requests.zig").PullRequestsView;
const IssuesView = @import("components/issues.zig").IssuesView;
const ReposView = @import("components/repos.zig").ReposView;

const Notification = @import("../domain/models/notification.zig").Notification;
const PullRequest = @import("../domain/models/pull_request.zig").PullRequest;
const Issue = @import("../domain/models/issue.zig").Issue;
const Repository = @import("../domain/models/repository.zig").Repository;

pub const TUI = struct {
    allocator: std.mem.Allocator,
    terminal: Terminal,
    renderer: Renderer,
    theme: Theme,
    running: bool,
    current_view: View,

    dashboard: DashboardView,
    notifications_view: NotificationsView,
    prs_view: PullRequestsView,
    issues_view: IssuesView,
    repos_view: ReposView,

    status_message: ?[]const u8,
    needs_refresh: bool,

    pub const View = enum {
        dashboard,
        notifications,
        pull_requests,
        issues,
        repositories,
    };

    pub fn init(allocator: std.mem.Allocator, theme_name: []const u8) !TUI {
        var terminal = try Terminal.init();
        const theme = Theme.fromName(theme_name);
        const renderer = Renderer.init(allocator, &terminal, theme);

        return TUI{
            .allocator = allocator,
            .terminal = terminal,
            .renderer = renderer,
            .theme = theme,
            .running = false,
            .current_view = .dashboard,
            .dashboard = DashboardView.init(),
            .notifications_view = NotificationsView.init(),
            .prs_view = PullRequestsView.init(),
            .issues_view = IssuesView.init(),
            .repos_view = ReposView.init(),
            .status_message = null,
            .needs_refresh = true,
        };
    }

    pub fn deinit(self: *TUI) void {
        self.stop();
        self.renderer.deinit();
        self.terminal.deinit();
    }

    pub fn start(self: *TUI) !void {
        try self.terminal.enableRawMode();
        self.terminal.enterAlternateScreen();
        self.terminal.hideCursor();
        self.running = true;
    }

    pub fn stop(self: *TUI) void {
        if (self.running) {
            self.terminal.showCursor();
            self.terminal.leaveAlternateScreen();
            self.terminal.disableRawMode();
            self.running = false;
        }
    }

    pub fn isRunning(self: *TUI) bool {
        return self.running;
    }

    pub fn needsRefresh(self: *TUI) bool {
        const result = self.needs_refresh;
        self.needs_refresh = false;
        return result;
    }

    pub fn requestRefresh(self: *TUI) void {
        self.needs_refresh = true;
    }

    pub fn setNotifications(self: *TUI, notifications: []const Notification) void {
        self.notifications_view.setNotifications(notifications);
    }

    pub fn setPullRequests(self: *TUI, prs: []const PullRequest) void {
        self.prs_view.setPullRequests(prs);
    }

    pub fn setIssues(self: *TUI, issues: []const Issue) void {
        self.issues_view.setIssues(issues);
    }

    pub fn setRepositories(self: *TUI, repos: []const Repository) void {
        self.repos_view.setRepositories(repos);
    }

    pub fn updateDashboard(self: *TUI, notifications: usize, prs: usize, issues: usize, repos: usize) void {
        self.dashboard.updateStats(notifications, prs, issues, repos);
    }

    pub fn setLoading(self: *TUI, loading: bool) void {
        self.notifications_view.setLoading(loading);
        self.prs_view.setLoading(loading);
        self.issues_view.setLoading(loading);
        self.repos_view.setLoading(loading);
    }

    pub fn setStatusMessage(self: *TUI, message: ?[]const u8) void {
        self.status_message = message;
    }

    pub const InputResult = struct {
        should_quit: bool,
        should_refresh: bool,
        selected_repo: ?struct { owner: []const u8, name: []const u8 },
    };

    pub fn handleInput(self: *TUI) !InputResult {
        var result = InputResult{
            .should_quit = false,
            .should_refresh = false,
            .selected_repo = null,
        };

        if (try self.terminal.readKey()) |key| {
            switch (key) {
                .char => |c| {
                    switch (c) {
                        'q' => result.should_quit = true,
                        '1' => self.current_view = .dashboard,
                        '2' => self.current_view = .notifications,
                        '3' => self.current_view = .pull_requests,
                        '4' => self.current_view = .issues,
                        '5' => self.current_view = .repositories,
                        'r', 'R' => result.should_refresh = true,
                        'j' => self.moveDown(),
                        'k' => self.moveUp(),
                        '/' => {
                            if (self.current_view == .repositories) {
                                self.repos_view.toggleSearchMode();
                            }
                        },
                        else => {},
                    }
                },
                .escape => result.should_quit = true,
                .arrow_up => self.moveUp(),
                .arrow_down => self.moveDown(),
                .page_up => self.pageUp(),
                .page_down => self.pageDown(),
                .enter => {
                    if (self.current_view == .repositories) {
                        if (self.repos_view.getSelected()) |repo| {
                            result.selected_repo = .{
                                .owner = repo.owner.login,
                                .name = repo.name,
                            };
                        }
                    }
                },
                else => {},
            }
        }

        return result;
    }

    fn moveUp(self: *TUI) void {
        switch (self.current_view) {
            .notifications => self.notifications_view.moveUp(),
            .pull_requests => self.prs_view.moveUp(),
            .issues => self.issues_view.moveUp(),
            .repositories => self.repos_view.moveUp(),
            else => {},
        }
    }

    fn moveDown(self: *TUI) void {
        switch (self.current_view) {
            .notifications => self.notifications_view.moveDown(),
            .pull_requests => self.prs_view.moveDown(),
            .issues => self.issues_view.moveDown(),
            .repositories => self.repos_view.moveDown(),
            else => {},
        }
    }

    fn pageUp(self: *TUI) void {
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            self.moveUp();
        }
    }

    fn pageDown(self: *TUI) void {
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            self.moveDown();
        }
    }

    pub fn render(self: *TUI) void {
        self.terminal.updateSize();
        self.renderer.clear();
        self.renderHeader();
        self.renderContent();
        self.renderStatusBar();
        self.renderer.flush();
    }

    fn renderHeader(self: *TUI) void {
        self.renderer.moveTo(0, 0);
        self.terminal.setBackground256(self.theme.colors.selection);
        self.terminal.setForeground256(self.theme.colors.primary);
        self.terminal.setBold();
        self.terminal.writeText(" gix ");
        self.terminal.resetAttributes();
        self.terminal.writeText(" │ ");

        const views = [_]struct { key: []const u8, name: []const u8, view: View }{
            .{ .key = "1", .name = "Dashboard", .view = .dashboard },
            .{ .key = "2", .name = "Notifications", .view = .notifications },
            .{ .key = "3", .name = "PRs", .view = .pull_requests },
            .{ .key = "4", .name = "Issues", .view = .issues },
            .{ .key = "5", .name = "Repos", .view = .repositories },
        };

        for (views) |v| {
            self.terminal.writeText("[");
            self.terminal.setForeground256(self.theme.colors.accent);
            self.terminal.writeText(v.key);
            self.terminal.resetAttributes();
            self.terminal.writeText("] ");
            if (self.current_view == v.view) {
                self.terminal.setForeground256(self.theme.colors.primary);
                self.terminal.setBold();
            }
            self.terminal.writeText(v.name);
            self.terminal.resetAttributes();
            self.terminal.writeText("  ");
        }

        const col = self.terminal.width -| 20;
        self.terminal.moveCursor(0, col);
        self.terminal.setForeground256(self.theme.colors.muted);
        self.terminal.writeText("gix v0.1.0");
        self.terminal.resetAttributes();
    }

    fn renderContent(self: *TUI) void {
        const content_height = self.terminal.height -| 3;

        switch (self.current_view) {
            .dashboard => self.dashboard.render(&self.terminal, &self.theme, 2, self.terminal.width),
            .notifications => self.notifications_view.render(&self.terminal, &self.theme, 2, self.terminal.width, content_height),
            .pull_requests => self.prs_view.render(&self.terminal, &self.theme, 2, self.terminal.width, content_height),
            .issues => self.issues_view.render(&self.terminal, &self.theme, 2, self.terminal.width, content_height),
            .repositories => self.repos_view.render(&self.terminal, &self.theme, 2, self.terminal.width, content_height),
        }
    }

    fn renderStatusBar(self: *TUI) void {
        const row = self.terminal.height - 1;
        self.terminal.moveCursor(row, 0);
        self.terminal.setBackground256(self.theme.colors.selection);
        self.terminal.setForeground256(self.theme.colors.foreground);

        if (self.status_message) |msg| {
            self.terminal.writeText(" ");
            self.terminal.writeText(msg);
        } else {
            const help_text = switch (self.current_view) {
                .dashboard => " q:Quit │ r:Refresh │ 1-5:Navigate",
                .notifications => " q:Quit │ r:Refresh │ ↑↓/jk:Navigate │ Enter:Open │ m:Mark Read",
                .pull_requests => " q:Quit │ r:Refresh │ ↑↓/jk:Navigate │ Enter:Open",
                .issues => " q:Quit │ r:Refresh │ ↑↓/jk:Navigate │ Enter:Open",
                .repositories => " q:Quit │ r:Refresh │ ↑↓/jk:Navigate │ Enter:Select │ /:Search",
            };
            self.terminal.writeText(help_text);
        }

        var col: u16 = 60;
        while (col < self.terminal.width) : (col += 1) {
            self.terminal.writeText(" ");
        }

        self.terminal.resetAttributes();
    }
};

test "TUI initialization" {
    var tui = try TUI.init(std.testing.allocator, "dark");
    defer tui.deinit();
    try std.testing.expect(!tui.running);
    try std.testing.expect(tui.current_view == .dashboard);
}
