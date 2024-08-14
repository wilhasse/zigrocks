const version = @import("builtin").zig_version;
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = .{ .cwd_relative = "main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();
    exe.linkSystemLibrary("rocksdb");

    if (@hasDecl(@TypeOf(exe.*), "addLibraryPath")) {
        exe.addLibraryPath(.{ .cwd_relative = "./rocksdb" });
        exe.addIncludePath(.{ .cwd_relative = "./rocksdb/include" });
    } else {
        exe.addLibPath(.{ .path = "rocksdb" });
        exe.addIncludeDir(.{ .cwd_relative = "./rocksdb/include" });
    }

    b.installArtifact(exe);

    // And also the key-value store
    const kvExe = b.addExecutable(.{
        .name = "kv",
        .root_source_file = .{ .cwd_relative = "rocksdb.zig" },
        .target = target,
        .optimize = optimize,
    });

    kvExe.linkLibC();
    kvExe.linkSystemLibrary("rocksdb");

    if (@hasDecl(@TypeOf(kvExe.*), "addLibraryPath")) {
        kvExe.addLibraryPath(.{ .cwd_relative = "./rocksdb" });
        kvExe.addIncludePath(.{ .cwd_relative = "./rocksdb/include" });
    } else {
        kvExe.addLibPath(.{ .path = "rocksdb" });
        kvExe.addIncludeDir(.{ .cwd_relative = "./rocksdb/include" });
    }

    b.installArtifact(kvExe);
}
