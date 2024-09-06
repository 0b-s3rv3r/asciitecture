const std = @import("std");
const backend = @import("backend/main.zig");
const math = @import("math.zig");
const Cell = @import("Cell.zig");
const Color = backend.Color;
const Attribute = backend.Attribute;
const ScreenSize = backend.ScreenSize;
const Vec2 = math.Vec2;
const vec2 = math.vec2;

const Screen = @This();

buf: std.ArrayList(Cell),
size: ScreenSize,
refSize: ScreenSize,
scaleVec: Vec2,
center: Vec2,
view: View,

pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Screen {
    const capacity = width * height;

    var buf = try std.ArrayList(Cell).initCapacity(allocator, capacity);
    try buf.appendNTimes(
        .{
            .char = ' ',
            .fg = .{ .indexed = .default },
            .bg = .{ .indexed = .default },
            .attr = .reset,
        },
        capacity,
    );

    var screen = Screen{
        .buf = buf,
        .size = .{
            .width = width,
            .height = height,
        },
        .refSize = ScreenSize{ .width = width, .height = height },
        .scaleVec = vec2(1, 1),
        .center = Vec2.fromInt(width, height).div(&vec2(2, 2)),
        .view = undefined,
    };
    screen.setView(&vec2(0, 0));

    return screen;
}

pub fn resize(self: *Screen, width: usize, height: usize) !void {
    self.size.width = width;
    self.size.height = height;
    self.center = Vec2.fromInt(width, height).div(&vec2(2, 2));
    self.scaleVec = Vec2.fromInt(width, height).div(&Vec2.fromInt(self.refSize.width, self.refSize.height));
    try self.buf.resize(width * height);
}

pub fn setView(self: *Screen, pos: *const Vec2) void {
    const size = pos.add(&vec2(self.center.x() / 2, self.center.y() / 2));
    self.view = View{
        .pos = pos.*,
        .left = -size.x(),
        .right = size.x(),
        .bottom = -size.y(),
        .top = size.y(),
    };
}

pub fn writeCell(self: *Screen, x: usize, y: usize, style: *const Cell) void {
    const fitToScreen = x >= 0 and x < self.size.width and y >= 0 and y < self.size.height;
    if (fitToScreen) {
        self.buf.items[y * self.size.width + x] = style.*;
    }
}

pub fn writeCellF(self: *Screen, x: f32, y: f32, style: *const Cell) void {
    const screenPos = self.worldToScreen(&vec2(x, y));
    const fitToScreen = screenPos.x() >= 0 and screenPos.x() <= @as(f32, @floatFromInt(self.size.width - 1)) and screenPos.y() >= 0 and screenPos.y() < @as(f32, @floatFromInt(self.size.height - 1));
    if (fitToScreen) {
        const ix: usize = @intFromFloat(@round(screenPos.x()));
        const iy: usize = @intFromFloat(@round(screenPos.y()));
        self.buf.items[iy * self.size.width + ix] = style.*;
    }
}

pub fn readCell(self: *const Screen, x: usize, y: usize) Cell {
    if (x >= 0 and x < self.size.width and y >= 0 and y < self.size.height) {
        return self.buf.items[y * self.size.width + x];
    } else {
        @panic("Screen index out of bound");
    }
}

pub fn clear(self: *Screen) void {
    @memset(self.buf.items, Cell{
        .char = ' ',
        .fg = .{ .indexed = .default },
        .bg = .{ .indexed = .default },
        .attr = .reset,
    });
}

fn worldToScreen(self: *const Screen, pos: *const Vec2) Vec2 {
    return vec2(self.center.x() + (pos.x() - self.view.pos.x()) * self.scaleVec.x(), self.center.y() + (pos.y() - self.view.pos.y()) * self.scaleVec.y());
}

const View = struct {
    pos: Vec2,
    left: f32,
    right: f32,
    bottom: f32,
    top: f32,
};