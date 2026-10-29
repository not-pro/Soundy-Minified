const std = @import("std");
const n = @import("native.zig");
const catalog = @import("catalog.zig");
const i18n = @import("i18n.zig");
const Id = n.Id;
const nil: Id = null;

pub var root: Id = null; // Owned NSString, configured before starting the worker.
pub var error_detail: [4096]u8 = undefined;
pub var error_message: []const u8 = "";

fn failure(path: Id, detail: []const u8) error{AudioFailed} {
    error_message = std.fmt.bufPrint(&error_detail, "{s}: {s}", .{ n.text(path), detail }) catch i18n.text(.AudioOutputFailed);
    return error.AudioFailed;
}

pub fn readBuffer(name: []const u8) !Id {
    const path = n.m1(Id, root, "stringByAppendingPathComponent:", n.str(name));
    var err: Id = null;
    const attrs = n.m2(Id, n.m0(Id, n.cls("NSFileManager"), "defaultManager"), "attributesOfItemAtPath:error:", path, &err);
    if (attrs == null) return failure(path, n.text(n.m0(Id, err, "localizedDescription")));
    const kind = n.m1(Id, attrs, "objectForKey:", n.str("NSFileType"));
    const size = n.m0(u64, n.m1(Id, attrs, "objectForKey:", n.str("NSFileSize")), "unsignedLongLongValue");
    if (!std.mem.eql(u8, n.text(kind), "NSFileTypeRegular") or size > 16 * 1024 * 1024)
        return failure(path, i18n.text(.InvalidSoundFile));
    const url = n.m1(Id, n.cls("NSURL"), "fileURLWithPath:", path);
    const file = n.m2(Id, n.alloc("AVAudioFile"), "initForReading:error:", url, &err);
    if (file == null) return failure(path, n.text(n.m0(Id, err, "localizedDescription")));
    defer n.release(file);
    const format = n.m0(Id, file, "processingFormat");
    const frames = n.m0(i64, file, "length");
    const rate = n.m0(f64, format, "sampleRate");
    const channels = n.m0(u32, format, "channelCount");
    if (frames <= 0 or frames > std.math.maxInt(u32) or !std.math.isFinite(rate) or rate < 8000 or rate > 192000 or @as(f64, @floatFromInt(frames)) / rate > 10 or channels < 1 or channels > 2)
        return failure(path, i18n.text(.InvalidAudioFormat));
    const capacity: u32 = @intCast(frames);
    const buffer = n.m2(Id, n.alloc("AVAudioPCMBuffer"), "initWithPCMFormat:frameCapacity:", format, capacity);
    if (buffer == null) return failure(path, i18n.text(.AudioBufferFailed));
    errdefer n.release(buffer);
    if (n.m2(n.Bool, file, "readIntoBuffer:error:", buffer, &err) == 0)
        return failure(path, n.text(n.m0(Id, err, "localizedDescription")));
    if (n.m0(u32, buffer, "frameLength") != capacity) return failure(path, i18n.text(.IncompleteWav));
    return buffer;
}

pub fn check() !void {
    for (catalog.files) |name| {
        const pool = n.pool();
        defer n.drain(pool);
        n.release(try readBuffer(name));
    }
}

const Sample = struct { buffer: Id = null, duration: u64 = 0, pool: usize = 0, last_play: u64 = 0 };
const Voice = struct { node: Id = null, busy_until: u64 = 0 };
const Pool = struct { format: Id = null, voices: [6]Voice = @splat(.{}) };
const Component = extern struct { kind: u32, subtype: u32, manufacturer: u32, flags: u32 = 0, mask: u32 = 0 };

const Player = struct {
    engine: Id = null,
    limiter: Id = null,
    samples: [240]Sample = @splat(.{}),
    pools: [240]Pool = @splat(.{}),
    pool_count: usize = 0,

    fn load(self: *Player) !void {
        self.engine = n.new("AVAudioEngine");
        if (self.engine == null) return failure(nil, i18n.text(.AudioOutputFailed));
        const mixer = n.m0(Id, self.engine, "mainMixerNode");
        self.limiter = n.m1(Id, n.alloc("AVAudioUnitEffect"), "initWithAudioComponentDescription:", Component{ .kind = 0x61756678, .subtype = 0x6c6d7472, .manufacturer = 0x6170706c });
        if (self.limiter == null) return failure(nil, i18n.text(.AudioOutputFailed));
        n.m1(void, self.engine, "attachNode:", self.limiter);
        n.m3(void, self.engine, "connect:to:format:", mixer, self.limiter, nil);
        n.m3(void, self.engine, "connect:to:format:", self.limiter, n.m0(Id, self.engine, "outputNode"), nil);
        for (catalog.files, 0..) |name, index| {
            const buffer = try readBuffer(name);
            self.samples[index].buffer = buffer;
            const format = n.m0(Id, buffer, "format");
            var pool_index: usize = 0;
            while (pool_index < self.pool_count) : (pool_index += 1) {
                if (n.m1(n.Bool, self.pools[pool_index].format, "isEqual:", format) != 0) break;
            }
            if (pool_index == self.pool_count) {
                self.pool_count += 1;
                const pool = &self.pools[pool_index];
                pool.format = format; // The sample buffer owns the format.
                // ponytail: six shared voices per PCM format; increase if bursts cut tails.
                for (&pool.voices) |*voice| {
                    voice.node = n.new("AVAudioPlayerNode");
                    if (voice.node == null) return failure(nil, i18n.text(.AudioOutputFailed));
                    n.m1(void, self.engine, "attachNode:", voice.node);
                    n.m3(void, self.engine, "connect:to:format:", voice.node, mixer, format);
                }
            }
            self.samples[index].pool = pool_index;
            self.samples[index].duration = @intFromFloat(@as(f64, @floatFromInt(n.m0(u32, buffer, "frameLength"))) / n.m0(f64, format, "sampleRate") * 1_000_000_000);
        }
        n.m0(void, self.engine, "prepare");
        var err: Id = null;
        if (n.m1(n.Bool, self.engine, "startAndReturnError:", &err) == 0)
            return failure(nil, n.text(n.m0(Id, err, "localizedDescription")));
    }

    fn play(self: *Player, index: usize, volume: u8) void {
        if (volume == 0) return;
        const now = n.now();
        const sample = &self.samples[index];
        // Keep the original per-file 15ms gate.
        if (sample.last_play != 0 and now - sample.last_play < 15_000_000) return;
        var voice = &self.pools[sample.pool].voices[0];
        for (&self.pools[sample.pool].voices) |*candidate| if (candidate.busy_until < voice.busy_until) {
            voice = candidate;
        };
        n.m1(void, voice.node, "setVolume:", @as(f32, @floatFromInt(@min(volume, 100))) / 100.0);
        const options: usize = if (voice.busy_until > now) 2 else 0; // AVAudioPlayerNodeBufferInterrupts
        n.m4(void, voice.node, "scheduleBuffer:atTime:options:completionHandler:", sample.buffer, nil, options, nil);
        if (n.m0(n.Bool, voice.node, "isPlaying") == 0) n.m0(void, voice.node, "play");
        voice.busy_until = now + sample.duration;
        sample.last_play = now;
    }

    fn deinit(self: *Player) void {
        if (self.engine != null) n.m0(void, self.engine, "stop");
        for (self.pools[0..self.pool_count]) |pool| for (pool.voices) |voice| n.release(voice.node);
        n.release(self.limiter);
        n.release(self.engine);
        for (self.samples) |sample| n.release(sample.buffer);
        self.* = .{};
    }
};

pub const Controls = struct { enabled: bool = true, profile: u8 = 0, mouse_profile: u8 = 0, volume: u8 = 25 };
pub var controls: Controls = .{}; // Only accessed by main-thread UI/input callbacks.
var player: Player = .{}; // Only accessed on the serial audio queue.
var queue: Id = null;
var start_error: ?anyerror = null;
const Command = struct {
    busy: std.atomic.Value(bool) = .init(false),
    index: usize = 0,
    volume: u8 = 0,
    at: u64 = 0,
    preview: bool = false,
};
var commands: [32]Command = @splat(.{});

pub fn start() !void {
    queue = n.dispatch_queue_create("dev.soundy.minified.audio", nil);
    if (queue == null) return error.AudioQueueFailed;
    n.dispatch_sync_f(queue, nil, initialize);
    if (start_error) |err| {
        stop();
        return err;
    }
}
fn initialize(_: Id) callconv(.c) void {
    const pool = n.pool();
    defer n.drain(pool);
    start_error = null;
    player.load() catch |err| {
        start_error = err;
    };
}
pub fn stop() void {
    if (queue == null) return;
    n.dispatch_sync_f(queue, nil, finish);
    n.dispatch_release(queue);
    queue = null;
}
fn finish(_: Id) callconv(.c) void {
    const pool = n.pool();
    defer n.drain(pool);
    player.deinit();
}
pub fn send(index: ?usize, is_preview: bool) void {
    if (queue == null or (!is_preview and !controls.enabled)) return;
    const sample = index orelse return;
    for (&commands) |*command| {
        if (command.busy.cmpxchgStrong(false, true, .acquire, .monotonic) != null) continue;
        command.index = sample;
        command.volume = controls.volume;
        command.at = n.now();
        command.preview = is_preview;
        n.dispatch_async_f(queue, command, execute);
        return;
    }
    // A full queue drops a sound, never stalls input.
}
fn execute(context: Id) callconv(.c) void {
    const command: *Command = @ptrCast(@alignCast(context.?));
    defer command.busy.store(false, .release);
    const pool = n.pool();
    defer n.drain(pool);
    if (command.preview or n.now() - command.at < 100_000_000) player.play(command.index, command.volume);
}
pub fn preview(mouse: bool) void {
    send(if (mouse) catalog.mouseSample(controls.mouse_profile, true) else catalog.keyboardSample(controls.profile, 0, true), true);
}
