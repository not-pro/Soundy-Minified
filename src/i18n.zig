const std = @import("std");
const n = @import("native.zig");

pub const Text = enum { SoundsEnabled, AllowInput, RetryInput, KeyboardSound, MouseSound, PreviewMouse, PreviewKeyboard, Volume, LanguageMenu, Quit, Off, Click, Tooltip, InputUnavailable, Paused, StartFailed, OK, InputPermissionRequired, InputConnectionFailed, InputSourceFailed, MainLoopUnavailable, MainThreadRequired, AudioThreadStopped, AudioOutputFailed, PathUtf8Required, InvalidAudioFormat, WavTooLarge, AudioBufferFailed, IncompleteWav, InvalidSoundFile, SoundsPathRequired, UnknownArgument, Help };
pub const messages = [_][3][:0]const u8{
    .{ "Sounds Enabled", "Звуки включены", "启用音效" },
    .{ "Allow Input Monitoring…", "Разрешить мониторинг ввода…", "允许输入监控…" },
    .{ "Reconnect Input…", "Повторить подключение ввода…", "重新连接输入设备…" },
    .{ "Keyboard Sound", "Звук клавиатуры", "键盘音效" },
    .{ "Mouse Sound", "Звук мыши", "鼠标音效" },
    .{ "Preview Mouse Sound", "Послушать мышь", "试听鼠标音效" },
    .{ "Preview Keyboard Sound", "Послушать звук", "试听键盘音效" },
    .{ "Volume", "Громкость", "音量" },
    .{ "Language", "Язык", "语言" },
    .{ "Quit Soundy Minified", "Завершить Soundy Minified", "退出 Soundy Minified" },
    .{ "Off", "Выключен", "关闭" },
    .{ "Click", "Клик", "点击" },
    .{ "Soundy Minified — keyboard and mouse sounds", "Soundy Minified — звуки клавиатуры и мыши", "Soundy Minified — 键盘和鼠标音效" },
    .{ "Soundy Minified — input monitoring unavailable", "Soundy Minified — мониторинг ввода недоступен", "Soundy Minified — 输入监控不可用" },
    .{ "Soundy Minified — paused", "Soundy Minified — пауза", "Soundy Minified — 已暂停" },
    .{ "Could Not Start Soundy Minified", "Не удалось запустить Soundy Minified", "无法启动 Soundy Minified" },
    .{ "OK", "ОК", "好" },
    .{ "Input Monitoring permission is required", "Требуется доступ к мониторингу ввода", "需要授予输入监控权限" },
    .{ "Could not connect the keyboard and mouse. Restart Soundy Minified after granting access.", "Не удалось подключить клавиатуру и мышь. Перезапустите Soundy Minified после выдачи доступа.", "无法连接键盘和鼠标。授予权限后，请重新启动 Soundy Minified。" },
    .{ "Could not create the keyboard event source", "Не удалось создать источник событий клавиатуры", "无法创建键盘事件源" },
    .{ "The main run loop is unavailable", "Основной run loop недоступен", "主运行循环不可用" },
    .{ "Soundy Minified must run on the main thread", "Soundy Minified должен запускаться в основном потоке", "Soundy Minified 必须在主线程上运行" },
    .{ "The audio thread stopped during startup", "Аудиопоток завершился при запуске", "音频线程在启动时停止" },
    .{ "Could not start audio output", "Не удалось запустить аудиовыход", "无法启动音频输出" },
    .{ "The sounds path must be UTF-8", "Путь к звукам должен быть UTF-8", "音效路径必须采用 UTF-8 编码" },
    .{ "Invalid audio format or duration", "Недопустимый формат или длительность", "音频格式或时长无效" },
    .{ "WAV file is too large", "Слишком большой WAV", "WAV 文件过大" },
    .{ "Could not allocate an audio buffer", "Не удалось выделить аудиобуфер", "无法分配音频缓冲区" },
    .{ "Incomplete WAV file", "Неполный WAV", "WAV 文件不完整" },
    .{ "Invalid sound file", "Недопустимый звуковой файл", "音效文件无效" },
    .{ "--sounds-dir requires a WAV directory path", "--sounds-dir требует путь к WAV", "--sounds-dir 需要提供 WAV 目录路径" },
    .{ "Unknown argument", "Неизвестный аргумент", "未知参数" },
    .{ "Soundy Minified — keyboard and mouse sounds for macOS\n\n  --sounds-dir PATH  Custom WAV directory (bundled sounds by default)\n  --check            Validate 240 WAV files without audio or input monitoring\n  --preview          Play one keyboard sound and exit\n  --preview-mouse    Play one mouse click and exit\n  --version          Version\n", "Soundy Minified — звуки клавиатуры и мыши для macOS\n\n  --sounds-dir PATH  Свой каталог WAV (по умолчанию встроенные звуки)\n  --check            Проверить 240 WAV без звука и мониторинга ввода\n  --preview          Воспроизвести один звук и завершить работу\n  --preview-mouse    Воспроизвести клик мыши и завершить работу\n  --version          Версия\n", "Soundy Minified — macOS 键盘和鼠标音效\n\n  --sounds-dir PATH  自定义 WAV 目录（默认使用内置音效）\n  --check            检查 240 个 WAV 文件，不播放声音或监控输入\n  --preview          播放一个键盘音效后退出\n  --preview-mouse    播放一次鼠标点击音效后退出\n  --version          版本\n" },
};

pub const codes = [_][:0]const u8{ "en", "ru", "zh-Hans" };
pub const names = [_][:0]const u8{ "English", "Русский", "简体中文" };
pub var language: usize = 0;
pub fn text(key: Text) [:0]const u8 {
    return messages[@backingInt(key)][language];
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
test "languages and every translation are available" {
    try std.testing.expectEqual(@as(?usize, 1), fromCode("RU_ru"));
    try std.testing.expectEqual(@as(?usize, 2), fromCode("zh-Hans-CN"));
    try std.testing.expect(fromCode("de-DE") == null);
    for (codes, 0..) |code, i| try std.testing.expectEqual(@as(?usize, i), fromCode(code));
    for (messages) |row| for (row) |message| try std.testing.expect(message.len > 0);
}
