// Minimal typed calls to Apple's Objective-C runtime. No generated bindings.
const std = @import("std");
pub const Id = ?*anyopaque;
pub const Sel = ?*anyopaque;
pub const Bool = i8;
pub const Size = extern struct { width: f64, height: f64 };
pub extern "objc" fn objc_getClass([*:0]const u8) Id;
pub extern "objc" fn sel_registerName([*:0]const u8) Sel;
extern "objc" fn objc_msgSend() void;
pub extern "objc" fn objc_allocateClassPair(Id, [*:0]const u8, usize) Id;
pub extern "objc" fn objc_registerClassPair(Id) void;
pub extern "objc" fn class_addMethod(Id, Sel, *const anyopaque, [*:0]const u8) Bool;

pub const cls = objc_getClass;
pub const sel = sel_registerName;
pub fn m0(comptime R: type, obj: Id, name: [:0]const u8) R {
    return @as(*const fn (Id, Sel) callconv(.c) R, @ptrCast(&objc_msgSend))(obj, sel(name));
}
pub fn m1(comptime R: type, obj: Id, name: [:0]const u8, a: anytype) R {
    return @as(*const fn (Id, Sel, @TypeOf(a)) callconv(.c) R, @ptrCast(&objc_msgSend))(obj, sel(name), a);
}
pub fn m2(comptime R: type, obj: Id, name: [:0]const u8, a: anytype, b: anytype) R {
    return @as(*const fn (Id, Sel, @TypeOf(a), @TypeOf(b)) callconv(.c) R, @ptrCast(&objc_msgSend))(obj, sel(name), a, b);
}
pub fn m3(comptime R: type, obj: Id, name: [:0]const u8, a: anytype, b: anytype, c: anytype) R {
    return @as(*const fn (Id, Sel, @TypeOf(a), @TypeOf(b), @TypeOf(c)) callconv(.c) R, @ptrCast(&objc_msgSend))(obj, sel(name), a, b, c);
}
pub fn m4(comptime R: type, obj: Id, name: [:0]const u8, a: anytype, b: anytype, c: anytype, d: anytype) R {
    return @as(*const fn (Id, Sel, @TypeOf(a), @TypeOf(b), @TypeOf(c), @TypeOf(d)) callconv(.c) R, @ptrCast(&objc_msgSend))(obj, sel(name), a, b, c, d);
}
pub fn m5(comptime R: type, obj: Id, name: [:0]const u8, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype) R {
    return @as(*const fn (Id, Sel, @TypeOf(a), @TypeOf(b), @TypeOf(c), @TypeOf(d), @TypeOf(e)) callconv(.c) R, @ptrCast(&objc_msgSend))(obj, sel(name), a, b, c, d, e);
}
pub fn new(name: [:0]const u8) Id {
    return m0(Id, cls(name), "new");
}
pub fn alloc(name: [:0]const u8) Id {
    return m0(Id, cls(name), "alloc");
}
pub fn str(value: []const u8) Id {
    return m0(Id, m3(Id, alloc("NSString"), "initWithBytes:length:encoding:", value.ptr, value.len, @as(usize, 4)), "autorelease");
}
pub fn release(obj: Id) void {
    if (obj != null) m0(void, obj, "release");
}
pub fn text(obj: Id) []const u8 {
    const ptr = m0(?[*:0]const u8, obj, "UTF8String") orelse return "";
    return std.mem.span(ptr);
}
pub fn pool() Id {
    return new("NSAutoreleasePool");
}
pub fn drain(obj: Id) void {
    m0(void, obj, "drain");
}

pub extern "c" fn puts([*:0]const u8) c_int;
pub extern "c" fn write(c_int, [*]const u8, usize) isize;
pub extern "c" fn usleep(c_uint) c_int;
pub extern "c" fn getpid() c_int;
pub extern "c" fn exit(c_int) noreturn;
pub fn print(value: []const u8) void {
    _ = write(1, value.ptr, value.len);
}
pub fn log(value: []const u8) void {
    _ = write(2, value.ptr, value.len);
    _ = write(2, "\n", 1);
}

const Timespec = extern struct { sec: i64, nsec: i64 };
extern "c" fn clock_gettime(c_int, *Timespec) c_int;
pub fn now() u64 {
    var time: Timespec = undefined;
    _ = clock_gettime(6, &time); // CLOCK_MONOTONIC on Darwin
    return @as(u64, @intCast(time.sec)) * 1_000_000_000 + @as(u64, @intCast(time.nsec));
}
pub extern "c" fn dispatch_queue_create([*:0]const u8, Id) Id;
pub extern "c" fn dispatch_sync_f(Id, Id, *const fn (Id) callconv(.c) void) void;
pub extern "c" fn dispatch_async_f(Id, Id, *const fn (Id) callconv(.c) void) void;
pub extern "c" fn dispatch_release(Id) void;
extern "c" var _dispatch_main_q: u8;
pub fn mainQueue() Id {
    return @ptrCast(&_dispatch_main_q);
}

pub extern "CoreGraphics" fn CGPreflightListenEventAccess() bool;
pub extern "CoreGraphics" fn CGRequestListenEventAccess() bool;
pub extern "CoreGraphics" fn CGEventTapCreate(u32, u32, u32, u64, *const fn (Id, u32, Id, Id) callconv(.c) Id, Id) Id;
pub extern "CoreGraphics" fn CGEventTapEnable(Id, bool) void;
pub extern "CoreGraphics" fn CGEventTapIsEnabled(Id) bool;
pub extern "CoreGraphics" fn CGEventGetIntegerValueField(Id, u32) i64;
pub extern "CoreGraphics" fn CGEventGetFlags(Id) u64;
pub extern "CoreFoundation" fn CFMachPortCreateRunLoopSource(Id, Id, isize) Id;
pub extern "CoreFoundation" fn CFMachPortInvalidate(Id) void;
pub extern "CoreFoundation" fn CFRunLoopGetMain() Id;
pub extern "CoreFoundation" fn CFRunLoopAddSource(Id, Id, Id) void;
pub extern "CoreFoundation" fn CFRunLoopRemoveSource(Id, Id, Id) void;
pub extern "CoreFoundation" fn CFRelease(Id) void;
pub extern "CoreFoundation" const kCFRunLoopCommonModes: Id;
