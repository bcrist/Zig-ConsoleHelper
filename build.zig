const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    _ = b.addModule("console", .{
        .root_source_file = b.path("console.zig"),
    });

    const tests = b.addExecutable(.{
        .name = "test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests.zig"),
            .target = target,
            .optimize = mode,
        }),
    });
    b.step("test", "Run all tests").dependOn(&b.addRunArtifact(tests).step);
}
