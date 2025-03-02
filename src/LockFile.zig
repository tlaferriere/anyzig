/// A file-based locking mechanism for synchronizing operations between multiple processes
pub const LockFile = @This();

const std = @import("std");

path: []const u8,
file: std.fs.File,

pub fn lock(path: []const u8) !LockFile {
    if (std.fs.path.dirname(path)) |dir| {
        try std.fs.cwd().makePath(dir);
    }
    const file = try std.fs.cwd().createFile(path, .{});
    errdefer {
        file.close();
        std.fs.cwd().deleteFile(path) catch {};
    }

    try file.lock(.exclusive);

    // Write the current process ID to the lock file
    // This is helpful for debugging and allows other processes to detect stale locks
    var pid_buffer: [16]u8 = undefined;
    const pid_text = try std.fmt.bufPrint(&pid_buffer, "{d}", .{std.os.linux.getpid()});
    _ = try file.writeAll(pid_text);
    try file.sync();

    return LockFile{
        .file = file,
        .path = path,
    };
}

pub fn unlock(self: *LockFile) void {
    self.file.unlock();
    self.file.close();
    std.fs.cwd().deleteFile(self.path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => |e| std.debug.panic("failed to delete lock file '{s}' with {s}", .{ self.path, @errorName(e) }),
    };
}
