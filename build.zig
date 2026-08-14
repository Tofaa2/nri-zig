const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    // -----------------------------------------------------------------------
    // The binding module. Consumers import it via .module("root") from their
    // build.zig.zon dependency; it compiles against the NRI headers vendored
    // in the thirdparty/nri submodule, so no cmake run is needed to use the
    // bindings themselves (only to produce libNRI for linking).
    // -----------------------------------------------------------------------
    const mod = b.addModule("root", .{
        .link_libc = true,
        .link_libcpp = true,
        .optimize = optimize,
        .target = target,
        .root_source_file = b.path("src/nri.zig"),
    });
    mod.addIncludePath(b.path("thirdparty/nri/Include"));
    mod.addIncludePath(b.path("thirdparty/nri/Include/Extensions"));

    // -----------------------------------------------------------------------
    // Optional example: builds libNRI from the submodule (cmake) and links a
    // small program that enumerates adapters through the bindings. This is
    // also what `zig build` runs to validate the whole pipeline.
    // -----------------------------------------------------------------------
    const exe = b.addExecutable(.{
        .name = "nri-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("nri", mod);
    _ = buildNri(b, exe, optimize, target);
    b.installArtifact(exe);

    const run_artifact = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the example (enumerates adapters)");
    run_step.dependOn(&run_artifact.step);
}

/// Builds the NRI shared library (via cmake in the thirdparty/nri submodule)
/// and links it into `exe`. Also usable by consumers of the package: call
/// `nri_zig.buildNri(b, exe, optimize, target)` from their own build.zig.
pub fn buildNri(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    optimize: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
) *std.Build.Step {
    _ = optimize;

    const nriRunSh = struct {
        fn func(bu: *std.Build, script_name: []const u8, args: []const []const u8) *std.Build.Step.Run {
            const is_w32 = builtin.os.tag == .windows;

            const file_format = if (is_w32) ".bat" else ".sh";
            const full_file = std.fmt.allocPrint(bu.allocator, "{s}{s}", .{ script_name, file_format }) catch @panic("OOM");

            const runner = if (is_w32)
                &[_][]const u8{ "cmd.exe", "/c" }
            else
                &[_][]const u8{"bash"};

            const cmd = bu.addSystemCommand(runner);

            cmd.addArg(full_file);
            cmd.addArgs(args);

            cmd.cwd = bu.path("thirdparty/nri");

            return cmd;
        }
    }.func;

    const deploy = nriRunSh(b, "1-Deploy", &.{
        "-DNRI_STATIC_LIBRARY=OFF",
        std.fmt.allocPrint(b.allocator, "-DCMAKE_CXX_COMPILER={s}", .{b.path("scripts/nri-cxx-wrapper.sh").getPath(b)}) catch @panic("OOM"),
    });
    const cmake_build = nriRunSh(b, "2-Build", &.{});
    const prepare = nriRunSh(b, "3-PrepareSDK", &.{});

    cmake_build.step.dependOn(&deploy.step);
    prepare.step.dependOn(&cmake_build.step);

    exe.step.dependOn(&prepare.step);

    exe.root_module.link_libc = true;
    exe.root_module.link_libcpp = true;

    exe.root_module.addIncludePath(b.path("thirdparty/nri/_NRI_SDK/Include"));
    exe.root_module.addIncludePath(b.path("thirdparty/nri/_NRI_SDK/Include/Extensions"));

    if (target.result.os.tag == .windows) {
        exe.root_module.addLibraryPath(b.path("thirdparty/nri/_NRI_SDK/Lib/Release"));
    } else {
        exe.root_module.addLibraryPath(b.path("thirdparty/nri/_NRI_SDK/Lib"));
        exe.root_module.addLibraryPath(b.path("thirdparty/nri/_Bin"));
    }

    exe.root_module.linkSystemLibrary("NRI", .{});

    return &prepare.step;
}