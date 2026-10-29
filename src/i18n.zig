const std = @import("std");
const n = @import("native.zig");

pub const Text = enum { SoundsEnabled, AllowInput, RetryInput, KeyboardSound, MouseSound, PreviewMouse, PreviewKeyboard, Volume, LanguageMenu, Quit, Off, Click, Tooltip, InputUnavailable, Paused, StartFailed, OK, InputPermissionRequired, InputConnectionFailed, InputSourceFailed, MainLoopUnavailable, MainThreadRequired, AudioThreadStopped, AudioOutputFailed, PathUtf8Required, InvalidAudioFormat, WavTooLarge, AudioBufferFailed, IncompleteWav, InvalidSoundFile, SoundsPathRequired, UnknownArgument, Help };
pub const codes = [_][:0]const u8{ "en", "ru", "zh-Hans" };
pub var names: [codes.len][]const u8 = undefined;
const keys = std.meta.fieldNames(Text);
var messages: [keys.len][codes.len][]const u8 = undefined;
var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
var language: std.atomic.Value(usize) = .init(0);

pub fn current() usize {
    return language.load(.monotonic);
}
pub fn setLanguage(index: usize) void {
    language.store(if (index < codes.len) index else 0, .monotonic);
}
pub fn text(key: Text) []const u8 {
    return messages[@backingInt(key)][current()];
}

pub fn init() !void {
    const pool = n.pool();
    defer n.drain(pool);
    const bundle = n.m0(n.Id, n.cls("NSBundle"), "mainBundle");
    const bundled_app = std.mem.endsWith(u8, n.text(n.m0(n.Id, bundle, "bundlePath")), ".app");
    const path = if (bundled_app) n.m1(n.Id, n.m0(n.Id, bundle, "resourcePath"), "stringByAppendingPathComponent:", n.str("i18n.json")) else n.str(@import("config").source_translations);
    const data = n.m1(n.Id, n.cls("NSData"), "dataWithContentsOfFile:", path);
    if (data == null) return error.TranslationFileUnavailable;
    try parse(data);
}
fn parse(data: n.Id) !void {
    var err: n.Id = null;
    const parsed = n.m3(n.Id, n.cls("NSJSONSerialization"), "JSONObjectWithData:options:error:", data, @as(usize, 0), &err);
    if (parsed == null or n.m1(n.Bool, parsed, "isKindOfClass:", n.cls("NSDictionary")) == 0) return error.InvalidTranslations;
    var next_arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    errdefer next_arena.deinit();
    const allocator = next_arena.allocator();
    var new_names: @TypeOf(names) = undefined;
    var new_messages: @TypeOf(messages) = undefined;
    for (codes, 0..) |code, language_index| {
        const locale = n.m1(n.Id, parsed, "objectForKey:", n.str(code));
        if (locale == null or n.m1(n.Bool, locale, "isKindOfClass:", n.cls("NSDictionary")) == 0) return error.InvalidTranslations;
        // NSString UTF8String pointers may expire with the autorelease pool; own the bytes.
        new_names[language_index] = try allocator.dupe(u8, try string(n.m1(n.Id, locale, "objectForKey:", n.str("name"))));
        const table = n.m1(n.Id, locale, "objectForKey:", n.str("messages"));
        if (table == null or n.m1(n.Bool, table, "isKindOfClass:", n.cls("NSDictionary")) == 0) return error.InvalidTranslations;
        for (keys, 0..) |key, index| new_messages[index][language_index] = try allocator.dupe(u8, try string(n.m1(n.Id, table, "objectForKey:", n.str(key))));
    }
    arena.deinit();
    arena = next_arena;
    names = new_names;
    messages = new_messages;
}
fn string(value: n.Id) ![]const u8 {
    if (value == null or n.m1(n.Bool, value, "isKindOfClass:", n.cls("NSString")) == 0) return error.InvalidTranslations;
    const result = n.text(value);
    if (result.len == 0) return error.InvalidTranslations;
    return result;
}
pub fn deinit() void {
    arena.deinit();
    arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
}

pub fn fromCode(code: []const u8) ?usize {
    var parts = std.mem.tokenizeAny(u8, code, "-_");
    const first = parts.next() orelse return null;
    for ([_][]const u8{ "en", "ru", "zh" }, 0..) |prefix, i| if (std.ascii.eqlIgnoreCase(first, prefix)) return i;
    return null;
}
pub fn load(defaults: n.Id) usize {
    if (fromCode(n.text(n.m1(n.Id, defaults, "stringForKey:", n.str("language"))))) |saved| return saved;
    const preferred = n.m0(n.Id, n.cls("NSLocale"), "preferredLanguages");
    const count = n.m0(usize, preferred, "count");
    for (0..count) |i| if (fromCode(n.text(n.m1(n.Id, preferred, "objectAtIndex:", i)))) |found| return found;
    return 0;
}
pub fn mouseName(index: usize, buffer: []u8) []const u8 {
    if (index == 0) return text(.Off);
    return if (index == 15) std.fmt.bufPrint(buffer, "{s} C", .{text(.Click)}) catch unreachable else std.fmt.bufPrint(buffer, "{s} {d}", .{ text(.Click), index }) catch unreachable;
}

test "language resolution and runtime JSON translations" {
    const pool = n.pool();
    defer n.drain(pool);
    try init();
    defer deinit();
    const saved = current();
    defer setLanguage(saved);
    const before = try std.testing.allocator.dupe(u8, text(.InputConnectionFailed));
    defer std.testing.allocator.free(before);
    const temporary = n.pool();
    for (0..2000) |_| _ = n.str("Temporary UTF-8 conversion must not replace the application's translations");
    n.drain(temporary);
    try std.testing.expectEqualStrings(before, text(.InputConnectionFailed));
    try std.testing.expectEqual(@as(?usize, 1), fromCode("RU_ru"));
    try std.testing.expectEqual(@as(?usize, 2), fromCode("zh-Hans-CN"));
    try std.testing.expect(fromCode("de-DE") == null);
    for (codes, 0..) |code, i| {
        try std.testing.expectEqual(@as(?usize, i), fromCode(code));
        setLanguage(i);
        for (std.meta.tags(Text)) |key| try std.testing.expect(text(key).len > 0);
    }
    for ([_][]const u8{ "{", "[]", "{}", "{\"en\":null}", "{\"en\":{\"name\":1}}" }) |invalid| {
        const data = n.m2(n.Id, n.cls("NSData"), "dataWithBytes:length:", invalid.ptr, invalid.len);
        try std.testing.expectError(error.InvalidTranslations, parse(data));
        try std.testing.expect(text(.Quit).len > 0); // Failed validation preserves the previous table.
    }
}
