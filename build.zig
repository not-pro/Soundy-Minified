const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = .{ .os_tag = .macos, .os_version_min = .{ .semver = .{ .major = 13, .minor = 0, .patch = 0 } } } });
    if (target.result.os.tag != .macos) @panic("Soundy Minified requires macOS 13+");
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .small });
    const sdk = std.mem.trim(u8, b.run(&.{ "xcrun", "--show-sdk-path" }), "\r\n ");
    const module = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = optimize != .debug,
    });
    const config = b.addOptions();
    config.addOption([]const u8, "source_sounds", b.root.joinString(b.allocator, "assets/sounds") catch @panic("OOM"));
    module.addOptions("config", config);
    module.addFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "System/Library/Frameworks" }) });
    module.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "usr/lib" }) });
    module.linkSystemLibrary("objc", .{});
    for ([_][]const u8{ "AppKit", "Foundation", "AVFAudio", "CoreGraphics", "CoreFoundation", "AudioToolbox" }) |framework| module.linkFramework(framework, .{});
    const exe = b.addExecutable(.{ .name = "soundy-minified", .root_module = module });
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    run.addPassthruArgs();
    b.step("run", "Run Soundy Minified (arguments follow --)").dependOn(&run.step);
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Test routing, input and translations").dependOn(&b.addRunArtifact(tests).step);
}
