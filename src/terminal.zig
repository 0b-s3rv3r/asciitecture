const std = @import("std");
const style = @import("style.zig");
const Screen = @import("Screen.zig");
const Buffer = @import("Buffer.zig");
const Cell = style.Cell;
const Attribute = style.Attribute;
const Color = style.Color;
const IndexedColor = style.IndexedColor;
const Painter = @import("Painter.zig");

pub fn Terminal(comptime T: type) @TypeOf(T) {
    return struct {
        screen: Screen,
        last_screen: Buffer,
        backend: T,
        target_delta: f32,
        delta_time: f32,
        speed: f32,
        fps: f32,
        minimized: bool,
        _current_time: i128,
        _accumulator: f32,

        pub fn init(allocator: std.mem.Allocator, target_fps: f32, speed: f32) !Terminal(T) {
            var backend = try T.init();
            try backend.enterRawMode();
            try backend.hideCursor();
            try backend.newScreen();
            try backend.flush();
            var screen_size: [2]usize = undefined;
            try backend.screenSize(&screen_size);

            const screen = try Screen.init(allocator, screen_size[0], screen_size[1]);
            const delta = 1 / target_fps;

            return .{
                .screen = screen,
                .last_screen = try screen.buffer.clone(),
                .backend = backend,
                .target_delta = delta,
                .delta_time = delta,
                .speed = speed,
                .fps = 0.0,
                .minimized = false,
                ._current_time = std.time.nanoTimestamp(),
                ._accumulator = 0.0,
            };
        }

        pub fn deinit(self: *Terminal(T)) !void {
            self.screen.deinit();
            self.last_screen.deinit();
            try self.backend.exitRawMode();
            try self.backend.showCursor();
            try self.backend.clearScreen();
            try self.backend.endScreen();
            try self.backend.flush();
        }

        pub fn painter(self: *Terminal(T)) Painter {
            return Painter.init(&self.screen);
        }

        pub fn draw(self: *Terminal(T)) !void {
            try self.handleResize();
            self.calcFps();
            if (!self.minimized) {
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

                try self.drawFrame();
            }
        }

        fn drawFrame(self: *Terminal(T)) !void {
            for (0..self.screen.buffer.size.rows) |y| {
                for (0..self.screen.buffer.size.cols) |x| {
                    const cell = &self.screen.buffer.buf.items[y * self.screen.buffer.size.cols + x];
                    const last_cell = &self.last_screen.buf.items[y * self.last_screen.size.cols + x];

                    if (!std.meta.eql(cell, last_cell)) {
                        try self.backend.setAttr(@intFromEnum(Attribute.reset));
                        try self.backend.setCursor(@intCast(x), @intCast(y));
                        switch (cell.fg) {
                            .indexed => |*indexed| try self.backend.setIndexedFg(@intFromEnum(indexed.*)),
                            .rgb => |*rgb| try self.backend.setRgbFg(rgb.r, rgb.g, rgb.b),
                            else => {},
                        }
                        switch (cell.bg) {
                            .indexed => |*indexed| try self.backend.setIndexedBg(@intFromEnum(indexed.*)),
                            .rgb => |*rgb| try self.backend.setRgbBg(rgb.r, rgb.g, rgb.b),
                            else => {},
                        }
                        if (cell.attr != .none) {
                            try self.backend.setAttr(@intFromEnum(cell.attr));
                        }
                        try self.backend.putChar(cell.char);
                    }
                }
            }
            try self.last_screen.replace(&self.screen.buffer.buf.items);
            try self.backend.flush();
            self.screen.clear();
        }

        // This can be handled by the signal
        fn handleResize(self: *Terminal(T)) !void {
            var screen_size: [2]usize = undefined;
            try self.backend.screenSize(&screen_size);
            if (screen_size[0] != self.screen.buffer.size.cols or screen_size[0] != self.screen.buffer.size.cols) {
                if (screen_size[0] == 0 and screen_size[1] == 0) {
                    self.minimized = true;
                }
                try self.screen.resize(screen_size[0], screen_size[1]);
                try self.last_screen.resize(screen_size[0], screen_size[1]);
                try self.backend.clearScreen();
            }
            self.minimized = false;
        }

        fn calcFps(self: *Terminal(T)) void {
            self.fps = 1.0 / self.delta_time;
        }
    };
}

test "frame draw benchmark" {
    const LinuxTty = @import("LinuxTty.zig");
    const math = @import("math.zig");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const result = gpa.deinit();
        if (result == .leak) {
            @panic("memory leak occured");
        }
    }
    var term = try Terminal(LinuxTty).init(gpa.allocator(), 999, 1);
    var painter = term.painter();

    painter.setCell(&.{ .char = ' ', .style = .{ .fg = .{ .indexed = .red }, .bg = .{ .indexed = .red }, .attr = .none } });
    painter.drawLine(&math.vec2(50.0, 20.0), &math.vec2(-50.0, 20.0));
    painter.setCell(&.{ .char = ' ', .style = .{ .fg = .{ .indexed = .red }, .bg = .{ .indexed = .cyan }, .attr = .none } });
    painter.drawRectangle(10, 10, &math.vec2(0.0, 0.0), 0, false);
    painter.setCell(&.{ .char = ' ', .style = .{ .fg = .{ .indexed = .red }, .bg = .{ .indexed = .cyan }, .attr = .none } });
    painter.drawRectangle(10, 10, &math.vec2(-20, -20), 0, false);

    try term.draw();
    const start = std.time.microTimestamp();
    try term.draw();
    const end = std.time.microTimestamp();
    const result = end - start;
    try term.deinit();
    std.debug.print("benchmark result: {d} qs\n", .{result});
}
