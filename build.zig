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

    exe.setOutputDir(".");

    if (exe.target.isDarwin()) {
        b.installFile("./rocksdb/librocksdb.7.8.dylib", "../librocksdb.7.8.dylib");
        exe.addRPath(".");
    }

    exe.install();

    // And also the key-value store
    const kvExe = b.addExecutable("kv", "rocksdb.zig");
    kvExe.linkLibC();
    kvExe.linkSystemLibraryName("rocksdb");

    if (@hasDecl(@TypeOf(kvExe.*), "addLibraryPath")) {
        kvExe.addLibraryPath("./rocksdb");
        kvExe.addIncludePath("./rocksdb/include");
    } else {
        kvExe.addLibPath("./rocksdb");
        kvExe.addIncludeDir("./rocksdb/include");
    }

    kvExe.setOutputDir(".");

    if (kvExe.target.isDarwin()) {
        b.installFile("./rocksdb/librocksdb.7.8.dylib", "../librocksdb.7.8.dylib");
        kvExe.addRPath(".");
    }

    kvExe.install();
}
