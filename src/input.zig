const std = @import("std");
const n = @import("native.zig");
const audio = @import("audio.zig");
const catalog = @import("catalog.zig");
var port: n.Id = null;
var source: n.Id = null;

pub fn listening() bool {
    return port != null and n.CGEventTapIsEnabled(port);
}
pub fn start() !void {
    if (listening()) return;
    stop();
    if (!n.CGPreflightListenEventAccess()) return error.InputPermissionRequired;
    var mask: u64 = 0;
    for ([_]u6{ 1, 2, 3, 4, 10, 11, 12, 25, 26 }) |kind| mask |= @as(u64, 1) << kind;
    port = n.CGEventTapCreate(1, 1, 1, mask, callback, null);
    if (port == null) return error.InputConnectionFailed;
    errdefer stop();
    source = n.CFMachPortCreateRunLoopSource(null, port, 0);
    if (source == null) return error.InputSourceFailed;
    n.CFRunLoopAddSource(n.CFRunLoopGetMain(), source, n.kCFRunLoopCommonModes);
    n.CGEventTapEnable(port, true);
}
pub fn stop() void {
    if (port == null) return;
    n.CGEventTapEnable(port, false);
    if (source != null) {
        n.CFRunLoopRemoveSource(n.CFRunLoopGetMain(), source, n.kCFRunLoopCommonModes);
        n.CFRelease(source);
        source = null;
    }
    n.CFMachPortInvalidate(port);
    n.CFRelease(port);
    port = null;
}
fn callback(_: n.Id, kind: u32, event: n.Id, _: n.Id) callconv(.c) n.Id {
    if (kind == 0xfffffffe) {
        if (n.CGPreflightListenEventAccess()) n.CGEventTapEnable(port, true);
    } else if (kind == 10 or kind == 11 or kind == 12) {
        if (n.CGEventGetIntegerValueField(event, 8) == 0) {
            const code = n.CGEventGetIntegerValueField(event, 9);
            if (code >= 0 and code <= 65535) {
                const key: u16 = @intCast(code);
                if (keyPressed(kind, key, n.CGEventGetFlags(event))) |pressed|
                    audio.send(catalog.keyboardSample(audio.controls.profile, key, pressed), false);
            }
        }
    } else if (mousePressed(kind)) |pressed| audio.send(catalog.mouseSample(audio.controls.mouse_profile, pressed), false);
    return event; // Listen-only; never inspect, retain or modify typed text.
}
pub fn keyPressed(kind: u32, key: u16, flags: u64) ?bool {
    return switch (kind) {
        10 => true,
        11 => false,
        12 => if (key == 57) true else blk: {
            const mask: u64 = switch (key) {
                54 => 0x10,
                55 => 0x08,
                56 => 0x02,
                58 => 0x20,
                59 => 0x01,
                60 => 0x04,
                61 => 0x40,
                62 => 0x2000,
                63 => 0x00800000,
                else => return null,
            };
            break :blk flags & mask != 0;
        },
        else => null,
    };
}
pub fn mousePressed(kind: u32) ?bool {
    return switch (kind) {
        1, 3, 25 => true,
        2, 4, 26 => false,
        else => null,
    };
}
test "modifier sides, caps lock, fn and mouse press/release" {
    for ([_][4]u16{ .{ 55, 54, 8, 16 }, .{ 59, 62, 1, 0x2000 }, .{ 58, 61, 32, 64 }, .{ 56, 60, 2, 4 } }) |pair| {
        const left = pair[0];
        const right = pair[1];
        const lm = pair[2];
        const rm = pair[3];
        try std.testing.expectEqual(@as(?bool, true), keyPressed(12, left, lm));
        try std.testing.expectEqual(@as(?bool, true), keyPressed(12, right, lm | rm));
        try std.testing.expectEqual(@as(?bool, false), keyPressed(12, left, rm));
        try std.testing.expectEqual(@as(?bool, false), keyPressed(12, right, 0));
        try std.testing.expectEqual(@as(?bool, true), keyPressed(12, right, rm));
        try std.testing.expectEqual(@as(?bool, true), keyPressed(12, left, lm | rm));
        try std.testing.expectEqual(@as(?bool, false), keyPressed(12, right, lm));
    }
    try std.testing.expectEqual(@as(?bool, true), keyPressed(12, 57, 0));
    try std.testing.expectEqual(@as(?bool, true), keyPressed(12, 63, 0x800000));
    try std.testing.expectEqual(@as(?bool, false), keyPressed(12, 63, 0));
    try std.testing.expect(keyPressed(12, 0, 0) == null);
    for ([_]u32{ 1, 3, 25 }) |kind| try std.testing.expectEqual(@as(?bool, true), mousePressed(kind));
    for ([_]u32{ 2, 4, 26 }) |kind| try std.testing.expectEqual(@as(?bool, false), mousePressed(kind));
    try std.testing.expect(mousePressed(5) == null);
    try std.testing.expect(mousePressed(22) == null);
}
