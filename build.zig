const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    _ = b.addModule("console", .{
        .root_source_file = b.path("console.zig"),
    });

    const tests = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("tests.zig"),
        .target = target,
        .optimize = mode,
    });
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests.step);
}
