const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Notification = struct {
    id: []const u8,
    repository: RepositoryInfo,
    subject: Subject,
    reason: NotificationReason,
    unread: bool,
    updated_at: []const u8,
    last_read_at: ?[]const u8,
    url: []const u8,
    allocator: ?Allocator,

    pub const RepositoryInfo = struct {
        id: u64,
        name: []const u8,
        full_name: []const u8,
        owner_login: []const u8,
        private: bool,
    };

    pub const Subject = struct {
        title: []const u8,
        url: ?[]const u8,
        latest_comment_url: ?[]const u8,
        type_: SubjectType,
    };

    pub const SubjectType = enum {
        Issue,
        PullRequest,
        Commit,
        Release,
        Discussion,
        CheckSuite,
        RepositoryVulnerabilityAlert,
        Unknown,

        pub fn fromString(s: []const u8) SubjectType {
            if (std.mem.eql(u8, s, "Issue")) return .Issue;
            if (std.mem.eql(u8, s, "PullRequest")) return .PullRequest;
            if (std.mem.eql(u8, s, "Commit")) return .Commit;
            if (std.mem.eql(u8, s, "Release")) return .Release;
            if (std.mem.eql(u8, s, "Discussion")) return .Discussion;
            if (std.mem.eql(u8, s, "CheckSuite")) return .CheckSuite;
            if (std.mem.eql(u8, s, "RepositoryVulnerabilityAlert")) return .RepositoryVulnerabilityAlert;
            return .Unknown;
        }

        pub fn toString(self: SubjectType) []const u8 {
            return switch (self) {
                .Issue => "Issue",
                .PullRequest => "PR",
                .Commit => "Commit",
                .Release => "Release",
                .Discussion => "Discussion",
                .CheckSuite => "CI",
                .RepositoryVulnerabilityAlert => "Security",
                .Unknown => "Unknown",
            };
        }
    };

    pub const NotificationReason = enum {
        assign,
        author,
        comment,
        invitation,
        manual,
        mention,
        review_requested,
        security_alert,
        state_change,
        subscribed,
        team_mention,
        ci_activity,
        unknown,

        pub fn fromString(s: []const u8) NotificationReason {
            if (std.mem.eql(u8, s, "assign")) return .assign;
            if (std.mem.eql(u8, s, "author")) return .author;
            if (std.mem.eql(u8, s, "comment")) return .comment;
            if (std.mem.eql(u8, s, "invitation")) return .invitation;
            if (std.mem.eql(u8, s, "manual")) return .manual;
            if (std.mem.eql(u8, s, "mention")) return .mention;
            if (std.mem.eql(u8, s, "review_requested")) return .review_requested;
            if (std.mem.eql(u8, s, "security_alert")) return .security_alert;
            if (std.mem.eql(u8, s, "state_change")) return .state_change;
            if (std.mem.eql(u8, s, "subscribed")) return .subscribed;
            if (std.mem.eql(u8, s, "team_mention")) return .team_mention;
            if (std.mem.eql(u8, s, "ci_activity")) return .ci_activity;
            return .unknown;
        }

        pub fn toString(self: NotificationReason) []const u8 {
            return switch (self) {
                .assign => "assigned",
                .author => "author",
                .comment => "comment",
                .invitation => "invitation",
                .manual => "manual",
                .mention => "mention",
                .review_requested => "review",
                .security_alert => "security",
                .state_change => "state",
                .subscribed => "subscribed",
                .team_mention => "team",
                .ci_activity => "ci",
                .unknown => "unknown",
            };
        }
    };

    pub fn deinit(self: *Notification) void {
        if (self.allocator) |alloc| {
            alloc.free(self.id);
            alloc.free(self.repository.name);
            alloc.free(self.repository.full_name);
            alloc.free(self.repository.owner_login);
            alloc.free(self.subject.title);
            if (self.subject.url) |url| alloc.free(url);
            if (self.subject.latest_comment_url) |url| alloc.free(url);
            alloc.free(self.updated_at);
            if (self.last_read_at) |last_read| alloc.free(last_read);
            alloc.free(self.url);
        }
    }

    pub fn parseJson(allocator: Allocator, json_value: std.json.Value) !Notification {
        const obj = json_value.object;
        const repo_obj = obj.get("repository").?.object;
        const subject_obj = obj.get("subject").?.object;

        const subject_url = if (subject_obj.get("url")) |url| blk: {
            if (url == .null) break :blk null;
            break :blk try allocator.dupe(u8, url.string);
        } else null;

        const latest_comment_url = if (subject_obj.get("latest_comment_url")) |url| blk: {
            if (url == .null) break :blk null;
            break :blk try allocator.dupe(u8, url.string);
        } else null;

        const last_read_at = if (obj.get("last_read_at")) |last_read| blk: {
            if (last_read == .null) break :blk null;
            break :blk try allocator.dupe(u8, last_read.string);
        } else null;

        return Notification{
            .id = try allocator.dupe(u8, obj.get("id").?.string),
            .repository = .{
                .id = @intCast(repo_obj.get("id").?.integer),
                .name = try allocator.dupe(u8, repo_obj.get("name").?.string),
                .full_name = try allocator.dupe(u8, repo_obj.get("full_name").?.string),
                .owner_login = try allocator.dupe(u8, repo_obj.get("owner").?.object.get("login").?.string),
                .private = repo_obj.get("private").?.bool,
            },
            .subject = .{
                .title = try allocator.dupe(u8, subject_obj.get("title").?.string),
                .url = subject_url,
                .latest_comment_url = latest_comment_url,
                .type_ = SubjectType.fromString(subject_obj.get("type").?.string),
            },
            .reason = NotificationReason.fromString(obj.get("reason").?.string),
            .unread = obj.get("unread").?.bool,
            .updated_at = try allocator.dupe(u8, obj.get("updated_at").?.string),
            .last_read_at = last_read_at,
            .url = try allocator.dupe(u8, obj.get("url").?.string),
            .allocator = allocator,
        };
    }
};

test "SubjectType parsing" {
    try std.testing.expect(Notification.SubjectType.fromString("PullRequest") == .PullRequest);
    try std.testing.expect(Notification.SubjectType.fromString("Issue") == .Issue);
    try std.testing.expect(Notification.SubjectType.fromString("Unknown") == .Unknown);
}

test "NotificationReason parsing" {
    try std.testing.expect(Notification.NotificationReason.fromString("mention") == .mention);
    try std.testing.expect(Notification.NotificationReason.fromString("review_requested") == .review_requested);
}
