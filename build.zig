const builtin = @import("builtin");
const std = @import("std");
const zig = @import("zig");

pub fn build(b: *std.Build) !void {
    const zig_dep = b.dependency("zig", .{});

    const write = b.addWriteFiles();
    _ = write.addCopyDirectory(zig_dep.path("."), "", .{});
    const root = write.addCopyFile(b.path("zigroot/root.zig"), "src/root.zig");
    const zig_mod = b.createModule(.{
        .root_source_file = root,
    });

    const options = b.addOptions();
    zig_mod.addOptions("build_options", options);

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const anyzig = blk: {
        const exe = b.addExecutable(.{
            .name = "zig",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .single_threaded = true,
        });
        exe.root_module.addImport("zig", zig_mod);
        const install = b.addInstallArtifact(exe, .{});
        b.getInstallStep().dependOn(&install.step);

        const run = b.addRunArtifact(exe);
        run.step.dependOn(&install.step);
        if (b.args) |args| {
            run.addArgs(args);
        }
        b.step("run", "").dependOn(&run.step);
        break :blk exe;
    };

    const test_step = b.step("test", "");

    inline for (&.{ "-h", "--help" }) |flag| {
        const run = b.addRunArtifact(anyzig);
        run.setName(b.fmt("anyzig {s}", .{flag}));
        run.addArg(flag);
        run.addCheck(.{ .expect_stdout_match = "Usage: zig [command] [options]" });
        b.step(b.fmt("test{s}", .{flag}), "").dependOn(&run.step);
        test_step.dependOn(&run.step);
    }

    {
        const run = b.addRunArtifact(anyzig);
        run.setName("anyzig -no-command");
        run.addArg("-no-command");
        run.expectStdErrEqual("error: expected a command but got '-no-command'\n");
        test_step.dependOn(&run.step);
    }

    {
        const run = b.addRunArtifact(anyzig);
        run.setName("anyzig init (no version)");
        run.addArg("init");
        run.expectStdErrEqual("error: anyzig init requires a version, i.e. 'zig 0.13.0 init'\n");
        test_step.dependOn(&run.step);
    }

    const wrap_exe = b.addExecutable(.{
        .name = "wrap",
        .root_source_file = b.path("test/wrap.zig"),
        .target = b.graph.host,
    });

    inline for (std.meta.fields(ZigRelease)) |field| {
        const zig_version = field.name;
        const zig_release: ZigRelease = @enumFromInt(field.value);

        switch (builtin.os.tag) {
            .linux => switch (builtin.cpu.arch) {
                .x86_64 => switch (comptime zig_release) {
                    // fails to get dynamic linker on NixOS
                    .@"0.7.0",
                    .@"0.7.1",
                    .@"0.8.0",
                    .@"0.8.1",
                    .@"0.9.0",
                    .@"0.9.1",
                    => continue,
                    else => {},
                },
                else => {},
            },
            .macos => switch (builtin.cpu.arch) {
                .aarch64 => switch (comptime zig_release) {
                    .@"0.7.1" => continue, // HTTP download fails with "404 Not Found"
                    else => {},
                },
                else => {},
            },
            else => {},
        }

        const init_out = blk: {
            const init = b.addRunArtifact(wrap_exe);
            init.setName(b.fmt("zig {s} build init", .{zig_version}));
            init.addArg("--no-input");
            const out = init.addOutputDirectoryArg("out");
            init.addArtifactArg(anyzig);
            init.addArg(zig_version);
            init.addArg(switch (zig_release.getInitKind()) {
                .simple => "init",
                .exe_and_lib => "init-exe",
            });
            break :blk out;
        };

        {
            const run = b.addRunArtifact(wrap_exe);
            run.setName(b.fmt("zig {s} version", .{zig_version}));
            run.addDirectoryArg(init_out);
            _ = run.addOutputDirectoryArg("out");
            run.addArtifactArg(anyzig);
            run.addArg("version");
            run.expectStdOutEqual(zig_version ++ "\n");
            test_step.dependOn(&run.step);
        }

        const build_enabled = switch (b.graph.host.result.os.tag) {
            .macos => switch (b.graph.host.result.cpu.arch) {
                .aarch64 => switch (zig_release) {
                    .@"0.7.0" => false, // crashes for some reason?
                    .@"0.9.0", .@"0.9.1" => false, // panics
                    .@"0.10.0", .@"0.10.1" => false, // error(link): undefined reference to symbol 'dyld_stub_binder'
                    else => true,
                },
                else => true,
            },
            else => true,
        };

        // TODO: test more than just 'zig build'
        if (build_enabled) {
            const run = b.addRunArtifact(wrap_exe);
            run.setName(b.fmt("zig {s} build", .{zig_version}));
            run.addDirectoryArg(init_out);
            _ = run.addOutputDirectoryArg("out");
            run.addArtifactArg(anyzig);
            run.addArg("build");
            b.step(b.fmt("test-{s}-build", .{zig_version}), "").dependOn(&run.step);
            test_step.dependOn(&run.step);
        }
    }
}

const ZigRelease = enum {
    @"0.7.0",
    @"0.7.1",
    @"0.8.0",
    @"0.8.1",
    @"0.9.0",
    @"0.9.1",
    @"0.10.0",
    @"0.10.1",
    @"0.11.0",
    @"0.12.0",
    @"0.12.1",
    @"0.13.0",

    pub fn getInitKind(self: ZigRelease) enum { simple, exe_and_lib } {
        return if (@intFromEnum(self) >= @intFromEnum(ZigRelease.@"0.12.0")) .simple else .exe_and_lib;
    }
};
