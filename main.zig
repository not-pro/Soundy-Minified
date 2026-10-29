const std = @import("std");
const builtin = @import("builtin");
const n = @import("src/native.zig");
const audio = @import("src/audio.zig");
const ui = @import("src/ui.zig");
const i18n = @import("src/i18n.zig");
pub const tray = @embedFile("assets/icons/tray-template.png");
pub const version = std.mem.trim(u8, @embedFile("VERSION"), "\r\n ");

comptime {
    if (!builtin.is_test) @export(&main, .{ .name = "main" });
}

pub fn main(argc: c_int, argv: [*][*:0]u8) callconv(.c) c_int {
    const pool = n.pool();
    defer n.drain(pool);
    i18n.language = i18n.load(n.m0(n.Id, n.cls("NSUserDefaults"), "standardUserDefaults"));
    const bundle = n.m0(n.Id, n.cls("NSBundle"), "mainBundle");
    const bundled = n.m1(n.Id, n.m0(n.Id, bundle, "resourcePath"), "stringByAppendingPathComponent:", n.str("Sounds"));
    const fm = n.m0(n.Id, n.cls("NSFileManager"), "defaultManager");
    var is_dir: n.Bool = 0;
    const has_bundle = n.m2(n.Bool, fm, "fileExistsAtPath:isDirectory:", bundled, &is_dir) != 0 and is_dir != 0;
    audio.root = n.m0(n.Id, if (has_bundle) bundled else n.str(@import("config").source_sounds), "retain");
    defer n.release(audio.root);
    var check = false;
    var preview = false;
    var mouse = false;
    var smoke = false;
    var arg: usize = 1;
    while (arg < @as(usize, @intCast(argc))) : (arg += 1) {
        const value = std.mem.span(argv[arg]);
        if (std.mem.eql(u8, value, "--sounds-dir")) {
            arg += 1;
            if (arg >= @as(usize, @intCast(argc))) {
                n.log(i18n.text(.SoundsPathRequired));
                return 2;
            }
            n.release(audio.root);
            audio.root = n.m0(n.Id, n.str(std.mem.span(argv[arg])), "retain");
            if (audio.root == null) {
                n.log(i18n.text(.PathUtf8Required));
                return 2;
            }
        } else if (std.mem.eql(u8, value, "--check")) {
            check = true;
        } else if (std.mem.eql(u8, value, "--preview")) {
            preview = true;
        } else if (std.mem.eql(u8, value, "--preview-mouse")) {
            mouse = true;
        } else if (std.mem.eql(u8, value, "--smoke-test")) {
            smoke = true;
        } else if (std.mem.eql(u8, value, "--version")) {
            n.print("Soundy Minified " ++ version ++ "\n");
            return 0;
        } else if (std.mem.eql(u8, value, "--help") or std.mem.eql(u8, value, "-h")) {
            n.print(i18n.text(.Help));
            return 0;
        } else {
            n.log(i18n.text(.UnknownArgument));
            n.log(value);
            return 2;
        }
    }
    if (check) {
        audio.check() catch |err| return report(err, false);
        n.print("OK: 240 WAV decoded, 40 keyboard profiles, 15 mouse pairs; no input monitoring started\n");
    } else if (preview or mouse) {
        audio.controls.mouse_profile = 1;
        audio.start() catch |err| return report(err, false);
        defer audio.stop();
        audio.preview(mouse);
        _ = n.usleep(1_000_000);
    } else {
        ui.run(smoke) catch |err| return report(err, true);
    }
    return 0;
}
fn report(err: anyerror, graphical: bool) c_int {
    const message = if (audio.error_message.len > 0) audio.error_message else @errorName(err);
    n.log(message);
    if (graphical) ui.showError(message);
    return 1;
}

test {
    _ = @import("src/catalog.zig");
    _ = @import("src/input.zig");
    _ = @import("src/i18n.zig");
}
