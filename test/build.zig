const std = @import("std");
const nri_zig_build = @import("nri_zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const nri_zig = b.dependency("nri_zig", .{ .target = target, .optimize = optimize });

    const exe = b.addExecutable(.{
        .name = "nri-test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("nri", nri_zig.module("root"));
    _ = nri_zig_build.buildNri(nri_zig, exe, optimize, target);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the test");
    run_step.dependOn(&run_cmd.step);
}