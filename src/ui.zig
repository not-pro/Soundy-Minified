const std = @import("std");
const n = @import("native.zig");
const audio = @import("audio.zig");
const input = @import("input.zig");
const catalog = @import("catalog.zig");
const i18n = @import("i18n.zig");
const Id = n.Id;
const nil: Id = null;
var app: Id = null;
var delegate: Id = null;
var menu: Id = null;
var status: Id = null;
var defaults: Id = null;
var smoke_test = false;
var smoke_domain: Id = null;

fn integer(key: []const u8) i64 {
    return n.m1(i64, defaults, "integerForKey:", n.str(key));
}
fn save(key: []const u8, value: i64) void {
    n.m2(void, defaults, "setInteger:forKey:", value, n.str(key));
}
fn exists(key: []const u8) bool {
    return n.m1(Id, defaults, "objectForKey:", n.str(key)) != null;
}

pub fn run(smoke: bool) !void {
    smoke_test = smoke;
    app = n.m0(Id, n.cls("NSApplication"), "sharedApplication");
    _ = n.m1(n.Bool, app, "setActivationPolicy:", @as(i64, 1));
    if (smoke) {
        var buffer: [80]u8 = undefined;
        smoke_domain = n.m0(Id, n.str(try std.fmt.bufPrint(&buffer, "dev.soundy.minified.smoke.{d}", .{n.getpid()})), "retain");
        defaults = n.m1(Id, n.alloc("NSUserDefaults"), "initWithSuiteName:", smoke_domain);
    } else defaults = n.m0(Id, n.m0(Id, n.cls("NSUserDefaults"), "standardUserDefaults"), "retain");
    defer n.release(defaults);
    if (exists("enabled")) audio.controls.enabled = n.m1(n.Bool, defaults, "boolForKey:", n.str("enabled")) != 0;
    const keyboard = integer("profile");
    audio.controls.profile = if (keyboard >= 0 and keyboard < 40) @intCast(keyboard) else 0;
    const mouse = integer("mouseProfile");
    audio.controls.mouse_profile = if (mouse >= 0 and mouse <= 15) @intCast(mouse) else 0;
    if (exists("volume")) audio.controls.volume = @intCast(std.math.clamp(integer("volume"), 0, 100));
    try audio.start();
    defer audio.stop();
    const class = n.objc_allocateClassPair(n.cls("NSObject"), "SoundyMinifiedDelegate", 0);
    if (class == null) return error.DelegateClassFailed;
    const methods = .{
        .{ "applicationDidFinishLaunching:", &didLaunch },
        .{ "applicationWillTerminate:", &willTerminate },
        .{ "menuWillOpen:", &menuWillOpen },
        .{ "action:", &action },
        .{ "smokeFinish:", &smokeFinish },
    };
    inline for (methods) |method| {
        if (n.class_addMethod(class, n.sel(method[0]), @ptrCast(method[1]), "v@:@") == 0) return error.DelegateMethodFailed;
    }
    n.objc_registerClassPair(class);
    delegate = n.m0(Id, class, "new");
    defer n.release(delegate);
    n.m1(void, app, "setDelegate:", delegate);
    n.m0(void, app, "run");
}

fn didLaunch(_: Id, _: n.Sel, _: Id) callconv(.c) void {
    menu = n.new("NSMenu");
    n.m1(void, menu, "setAutoenablesItems:", @as(n.Bool, 0));
    n.m1(void, menu, "setDelegate:", delegate);
    status = n.m0(Id, n.m1(Id, n.m0(Id, n.cls("NSStatusBar"), "systemStatusBar"), "statusItemWithLength:", @as(f64, -1)), "retain");
    const button = n.m0(Id, status, "button");
    const bytes = @import("root").tray;
    const data = n.m2(Id, n.cls("NSData"), "dataWithBytes:length:", bytes.ptr, @as(usize, bytes.len));
    const image = n.m1(Id, n.alloc("NSImage"), "initWithData:", data);
    if (image == null) @panic("embedded tray image must decode");
    defer n.release(image);
    n.m1(void, image, "setSize:", n.Size{ .width = 18, .height = 18 });
    n.m1(void, image, "setTemplate:", @as(n.Bool, 1));
    n.m1(void, button, "setImage:", image);
    n.m1(void, button, "setAccessibilityLabel:", n.str("Soundy Minified"));
    n.m1(void, status, "setMenu:", menu);
    refresh();
    if (smoke_test) _ = n.m5(Id, n.cls("NSTimer"), "scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:", @as(f64, 0.25), delegate, n.sel("smokeFinish:"), nil, @as(n.Bool, 0));
}
fn willTerminate(_: Id, _: n.Sel, _: Id) callconv(.c) void {
    input.stop();
    audio.stop();
    if (smoke_test) {
        n.m1(void, defaults, "removePersistentDomainForName:", smoke_domain);
        n.release(smoke_domain);
    }
    n.release(status);
    n.release(menu);
}
fn menuWillOpen(_: Id, _: n.Sel, _: Id) callconv(.c) void {
    refresh();
}
fn action(_: Id, _: n.Sel, sender: Id) callconv(.c) void {
    const tag = n.m0(i64, sender, "tag");
    switch (tag) {
        1 => {
            audio.controls.enabled = !audio.controls.enabled;
            n.m2(void, defaults, "setBool:forKey:", @as(n.Bool, @intFromBool(audio.controls.enabled)), n.str("enabled"));
        },
        2 => {
            if (!n.CGPreflightListenEventAccess()) {
                _ = n.CGRequestListenEventAccess();
                const url = n.m1(Id, n.cls("NSURL"), "URLWithString:", n.str("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"));
                _ = n.m1(n.Bool, n.m0(Id, n.cls("NSWorkspace"), "sharedWorkspace"), "openURL:", url);
            }
        },
        3 => audio.preview(false),
        4 => audio.preview(true),
        5 => {
            n.m1(void, app, "terminate:", nil);
            return;
        },
        100...139 => {
            audio.controls.profile = @intCast(tag - 100);
            save("profile", tag - 100);
            audio.preview(false);
        },
        200...215 => {
            audio.controls.mouse_profile = @intCast(tag - 200);
            save("mouseProfile", tag - 200);
            audio.preview(true);
        },
        300...400 => {
            audio.controls.volume = @intCast(tag - 300);
            save("volume", tag - 300);
        },
        500...502 => {
            i18n.language = @intCast(tag - 500);
            n.m2(void, defaults, "setObject:forKey:", n.str(i18n.codes[i18n.language]), n.str("language"));
        },
        else => return,
    }
    refresh();
}
fn item(parent: Id, title: []const u8, tag: i64, checked: bool) Id {
    const result = n.m3(Id, n.alloc("NSMenuItem"), "initWithTitle:action:keyEquivalent:", n.str(title), if (tag == 0) @as(n.Sel, null) else n.sel("action:"), n.str(""));
    n.m1(void, result, "setTarget:", delegate);
    n.m1(void, result, "setTag:", tag);
    n.m1(void, result, "setState:", @as(i64, @intFromBool(checked)));
    n.m1(void, result, "setEnabled:", @as(n.Bool, @intFromBool(tag != 0)));
    n.m1(void, parent, "addItem:", result);
    n.release(result); // The parent menu retains it.
    return result;
}
fn submenu(title: []const u8) Id {
    const parent = item(menu, title, 0, false);
    n.m1(void, parent, "setEnabled:", @as(n.Bool, 1));
    const child = n.new("NSMenu");
    n.m1(void, child, "setAutoenablesItems:", @as(n.Bool, 0));
    n.m1(void, parent, "setSubmenu:", child);
    n.release(child);
    return child;
}
fn separator() void {
    n.m1(void, menu, "addItem:", n.m0(Id, n.cls("NSMenuItem"), "separatorItem"));
}
fn refresh() void {
    const granted = n.CGPreflightListenEventAccess();
    if (!granted or !input.listening()) input.stop();
    var input_error = false;
    if (granted and !input.listening() and !smoke_test) input.start() catch {
        input_error = true;
        n.log(i18n.text(.InputConnectionFailed));
    };
    n.m0(void, menu, "removeAllItems");
    const controls = audio.controls;
    _ = item(menu, i18n.text(.SoundsEnabled), 1, controls.enabled);
    if (!granted) {
        _ = item(menu, i18n.text(.AllowInput), 2, false);
    } else if (!input.listening()) {
        _ = item(menu, i18n.text(.RetryInput), 2, false);
    }
    if (input_error) _ = item(menu, i18n.text(.InputConnectionFailed), 0, false);
    separator();
    const keyboard_menu = submenu(i18n.text(.KeyboardSound));
    for (catalog.keyboards, 0..) |keyboard, index| _ = item(keyboard_menu, keyboard.name, @as(i64, @intCast(index)) + 100, controls.profile == index);
    const mouse_menu = submenu(i18n.text(.MouseSound));
    var buffer: [128]u8 = undefined;
    for (0..16) |index| _ = item(mouse_menu, i18n.mouseName(index, &buffer), @as(i64, @intCast(index)) + 200, controls.mouse_profile == index);
    _ = item(menu, i18n.text(.PreviewMouse), 4, false);
    _ = item(menu, i18n.text(.PreviewKeyboard), 3, false);
    separator();
    const volume_menu = submenu(i18n.text(.Volume));
    for ([_]u8{ 0, 10, 25, 50, 75, 100 }) |volume| _ = item(volume_menu, std.fmt.bufPrint(&buffer, "{d}%", .{volume}) catch unreachable, @as(i64, volume) + 300, controls.volume == volume);
    const language_menu = submenu(i18n.text(.LanguageMenu));
    for (i18n.names, 0..) |name, index| _ = item(language_menu, name, @as(i64, @intCast(index)) + 500, i18n.language == index);
    separator();
    _ = item(menu, i18n.text(.Quit), 5, false);
    const button = n.m0(Id, status, "button");
    const unavailable = !granted or !input.listening();
    n.m1(void, button, "setTitle:", n.str(if (unavailable) " !" else if (controls.enabled) "" else " Ⅱ"));
    n.m1(void, button, "setToolTip:", n.str(i18n.text(if (unavailable) .InputUnavailable else if (controls.enabled) .Tooltip else .Paused)));
}

fn require(condition: bool) void {
    if (!condition) @panic("menu smoke test failed");
}
fn findSubmenu(key: i18n.Text) Id {
    return n.m0(Id, n.m1(Id, menu, "itemWithTitle:", n.str(i18n.text(key))), "submenu");
}
fn smokeFinish(_: Id, _: n.Sel, _: Id) callconv(.c) void {
    for (0..3) |language| {
        const option = n.m1(Id, findSubmenu(.LanguageMenu), "itemAtIndex:", @as(i64, @intCast(language)));
        action(delegate, n.sel("action:"), option);
        require(i18n.load(defaults) == language);
        require(n.m0(usize, findSubmenu(.KeyboardSound), "numberOfItems") == 40);
        require(n.m0(usize, findSubmenu(.MouseSound), "numberOfItems") == 16);
        require(n.m0(usize, findSubmenu(.LanguageMenu), "numberOfItems") == 3);
        for (0..3) |index| {
            const entry = n.m1(Id, findSubmenu(.LanguageMenu), "itemAtIndex:", @as(i64, @intCast(index)));
            require(std.mem.eql(u8, n.text(n.m0(Id, entry, "title")), i18n.names[index]));
            require(n.m0(i64, entry, "state") == @as(i64, @intFromBool(index == language)));
        }
        var buffer: [128]u8 = undefined;
        for ([_]usize{ 0, 1, 15 }) |index| {
            const entry = n.m1(Id, findSubmenu(.MouseSound), "itemAtIndex:", @as(i64, @intCast(index)));
            require(std.mem.eql(u8, n.text(n.m0(Id, entry, "title")), i18n.mouseName(index, &buffer)));
        }
        for ([_]i18n.Text{ .SoundsEnabled, .PreviewMouse, .PreviewKeyboard, .Volume, .Quit }) |key|
            require(n.m1(Id, menu, "itemWithTitle:", n.str(i18n.text(key))) != null);
        const button = n.m0(Id, status, "button");
        require(n.m0(n.Bool, n.m0(Id, button, "image"), "isTemplate") != 0);
        require(std.mem.eql(u8, n.text(n.m0(Id, button, "toolTip")), i18n.text(.InputUnavailable)));
        require(!input.listening());
        n.print("OK: ");
        n.print(i18n.codes[language]);
        n.print(" menu, language selection and saved preference; no input monitoring started\n");
    }
    // Exercise the actual action callbacks with isolated settings.
    action(delegate, n.sel("action:"), n.m1(Id, findSubmenu(.KeyboardSound), "itemAtIndex:", @as(i64, 39)));
    require(audio.controls.profile == 39 and integer("profile") == 39);
    action(delegate, n.sel("action:"), n.m1(Id, findSubmenu(.MouseSound), "itemAtIndex:", @as(i64, 15)));
    require(audio.controls.mouse_profile == 15 and integer("mouseProfile") == 15);
    action(delegate, n.sel("action:"), n.m1(Id, findSubmenu(.Volume), "itemAtIndex:", @as(i64, 5)));
    require(audio.controls.volume == 100 and integer("volume") == 100);
    const old = audio.controls.enabled;
    action(delegate, n.sel("action:"), n.m1(Id, menu, "itemAtIndex:", @as(i64, 0)));
    require(audio.controls.enabled != old);
    require((n.m1(n.Bool, defaults, "boolForKey:", n.str("enabled")) != 0) == audio.controls.enabled);
    n.print("OK: keyboard, mouse, volume and pause actions persist; isolated smoke settings\n");
    n.m1(void, app, "terminate:", nil);
}
pub fn showError(message: []const u8) void {
    const alert = n.new("NSAlert");
    defer n.release(alert);
    n.m1(void, alert, "setMessageText:", n.str(i18n.text(.StartFailed)));
    _ = n.m1(Id, alert, "addButtonWithTitle:", n.str(i18n.text(.OK)));
    n.m1(void, alert, "setInformativeText:", n.str(message));
    _ = n.m0(i64, alert, "runModal");
}
