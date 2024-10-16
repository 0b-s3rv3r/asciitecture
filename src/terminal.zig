const std = @import("std");
const cell_ = @import("cell.zig");
const Screen = @import("Screen.zig");
const RawScreen = @import("RawScreen.zig");
const Cell = cell_.Cell;
const Attribute = cell_.Attribute;
const Color = cell_.Color;

pub fn Terminal(comptime T: type) type {
    return struct {
        screen: Screen,
        last_screen: RawScreen,
        backend: T,
        target_delta: f32,
        delta_time: f32,
        speed: f32,
        fps: f32,
        minimized: bool,

        _current_time: i128,

        pub fn init(allocator: std.mem.Allocator, target_fps: f32, speed: f32) !Terminal(T) {
            var backend_ = try T.init();
            try backend_.rawMode();
            try backend_.hideCursor();
            try backend_.newScreen();
            try backend_.flush();
            const screen_size = try backend_.screenSize();
            const screen = try Screen.init(allocator, screen_size.cols, screen_size.rows);
            const last_screen = try RawScreen.init(allocator, screen_size.cols, screen_size.rows);
            const delta = 1 / target_fps;

            return .{
                .screen = screen,
                .last_screen = last_screen,
                .backend = backend_,
                .target_delta = delta,
                .delta_time = delta,
                .speed = speed,
                .fps = 0.0,
                .minimized = false,
                ._current_time = std.time.nanoTimestamp(),
            };
        }

        pub fn deinit(self: *Terminal(T)) !void {
            try self.backend.showCursor();
            try self.backend.clearScreen();
            try self.backend.endScreen();
            try self.backend.normalMode();
            try self.backend.flush();
            self.screen.buf.deinit();
            self.last_screen.buf.deinit();
        }

        pub fn draw(self: *Terminal(T)) !void {
            try self.handleResize();
            self.calcFps();
            if (!self.minimized) {
                try self.drawFrame();
            }
        }

        fn drawFrame(self: *Terminal(T)) !void {
            const buf = &self.screen;
            const last_buf = &self.last_screen;
            var backend = &self.backend;
            for (0..buf.size.rows) |y| {
                for (0..buf.size.cols) |x| {
                    const cell = buf.buf.items[y * buf.size.cols + x];
                    const last_cell = last_buf.buf.items[y * last_buf.size.cols + x];

                    if (!std.meta.eql(cell, last_cell)) {
                        try backend.setCursor(@intCast(x), @intCast(y));
                        try backend.setFg(cell.fg);
                        try backend.setBg(cell.bg);
                        if (cell.attr) |attr| {
                            try backend.setAttr(attr);
                        }
                        try backend.putChar(cell.char);
                    }
                }
            }
            try self.last_screen.replace(&self.screen.buf.items);
            try backend.flush();
            self.screen.clear();

            const new_time = std.time.nanoTimestamp();
            const draw_time = @as(f32, @floatFromInt(new_time - self._current_time)) / std.time.ns_per_s;
            self._current_time = new_time;

            if (draw_time < self.target_delta) {
                const delayTime = self.target_delta - draw_time;
                std.time.sleep(@intFromFloat(delayTime * std.time.ns_per_s));
                self.delta_time = draw_time + delayTime;
            } else {
                self.delta_time = draw_time;
            }
        }

        // This should be handled by a signal
        fn handleResize(self: *Terminal(T)) !void {
            const screen_size = try self.backend.screenSize();
            if (!std.meta.eql(screen_size, self.screen.size)) {
                if (screen_size.cols == 0 and screen_size.rows == 0) {
                    self.minimized = true;
                }
                try self.screen.resize(screen_size.cols, screen_size.rows);
                try self.last_screen.resize(screen_size.cols, screen_size.rows);
                try self.backend.clearScreen();
            }
            self.minimized = false;
        }

        fn calcFps(self: *Terminal(T)) void {
            self.fps = 1.0 / self.delta_time;
        }

        pub fn transition(self: *Terminal(T), animation: fn (*Screen) void) void {
            _ = self;
            _ = animation;
        }
    };
}

const LinuxTty = @import("backends/LinuxTty.zig");

test "frame draw benchmark" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const result = gpa.deinit();
        if (result == .leak) {
            @panic("memory leak occured");
        }
    }
    var term = try Terminal(LinuxTty).init(gpa.allocator(), 999, 1);

    const graphics = @import("graphics.zig");
    const math = @import("math.zig");
    graphics.drawLine(&term.screen, &math.vec2(50.0, 20.0), &math.vec2(-50.0, 20.0), &.{ .char = ' ', .fg = .{ .indexed = .red }, .bg = .{ .indexed = .red }, .attr = null });
    graphics.drawRectangle(&term.screen, 10, 10, &math.vec2(0.0, 0.0), 0, &.{ .char = ' ', .fg = .{ .indexed = .red }, .bg = .{ .indexed = .cyan }, .attr = null }, false);
    graphics.drawRectangle(&term.screen, 10, 10, &math.vec2(-20, -20), 0, &.{ .char = ' ', .fg = .{ .indexed = .red }, .bg = .{ .indexed = .cyan }, .attr = null }, false);

    try term.draw();
    const start = std.time.microTimestamp();
    try term.draw();
    const end = std.time.microTimestamp();
    const result = end - start;
    try term.deinit();
    std.debug.print("benchmark result: {d} qs\n", .{result});
}
