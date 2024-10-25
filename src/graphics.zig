const std = @import("std");
const cell = @import("cell.zig");
const math = @import("math.zig");
const Screen = @import("Screen.zig");
const Cell = cell.Cell;
const Color = cell.Color;
const Attribute = cell.Attribute;
const Vec2 = math.Vec2;
const vec2 = math.vec2;
const pow = math.pow;

pub fn drawLine(screen: *Screen, p0: *const Vec2, p1: *const Vec2, style: *const Cell) void {
    var x0 = p0.x();
    var y0 = p0.y();
    const x1 = p1.x();
    const y1 = p1.y();

    const dx = @abs(x1 - x0);
    const dy = @abs(y1 - y0);
    const sx: f32 = if (x0 < x1) 1 else -1;
    const sy: f32 = if (y0 < y1) 1 else -1;
    var err = dx - dy;

    while (true) {
        screen.writeCellF(x0, y0, style);
        if (x0 == x1 and y0 == y1) break;
        const e2 = 2 * err;
        if (e2 > -dy) {
            err -= dy;
            x0 += sx;
        }
        if (e2 < dx) {
            err += dx;
            y0 += sy;
        }
    }
}

pub fn drawCubicSpline(screen: *Screen, p0: *const Vec2, p1: *const Vec2, p2: *const Vec2, p3: *const Vec2, style: *const Cell) void {
    const inc_val: f32 = 1.0 / 100.0;
    var t: f32 = 0;
    while (t <= 1.0) {
        const x = cubic_bezier(t, p0.x(), p1.x(), p2.x(), p3.x());
        const y = cubic_bezier(t, p0.y(), p1.y(), p2.y(), p3.y());
        screen.writeCellF(x, y, style);
        t = t + inc_val;
    }
}

fn cubic_bezier(t: f32, p0: f32, p1: f32, p2: f32, p3: f32) f32 {
    return pow(1 - t, 3) * p0 + 3 * pow(1 - t, 2) * t * p1 + 3 * (1 - t) * pow(t, 2) * p2 + pow(t, 3) * p3;
}

pub fn drawRectangle(screen: *Screen, width: f32, height: f32, position: *const Vec2, rotation_angle: f32, style: *const Cell, filling: bool) void {
    // const origin = vec2(position.x() + width / 2, position.y() + height / 2);
    const top_left = position;
    const top_right = vec2(position.x() + width - 1, position.y());
    const bottom_left = vec2(position.x(), position.y() + height - 1);
    const bottom_right = vec2(position.x() + width - 1, position.y() + height - 1);

    drawLine(screen, top_left, &top_right, style);
    drawLine(screen, &top_right, &bottom_right, style);
    drawLine(screen, &bottom_right, &bottom_left, style);
    drawLine(screen, &bottom_left, top_left, style);

    _ = rotation_angle;
    _ = filling;
}

pub const Border = enum(u8) {
    plain,
    thick,
    double_line,
    rounded,
};

pub fn drawPrettyRectangle(screen: *Screen, width: f32, height: f32, position: *const Vec2, borders: Border, fg: Color) void {
    const top_left = position;
    const top_right = vec2(position.x() + width - 1, position.y());
    const bottom_left = vec2(position.x(), position.y() + height - 1);
    const bottom_right = vec2(position.x() + width - 1, position.y() + height - 1);

    var horizontal_border = Cell{ .fg = fg, .bg = .{ .indexed = .default }, .attr = null, .char = undefined };
    var vertical_border = Cell{ .fg = fg, .bg = .{ .indexed = .default }, .attr = null, .char = undefined };
    var top_left_edge = Cell{ .fg = fg, .bg = .{ .indexed = .default }, .attr = null, .char = undefined };
    var top_right_edge = Cell{ .fg = fg, .bg = .{ .indexed = .default }, .attr = null, .char = undefined };
    var bottom_left_edge = Cell{ .fg = fg, .bg = .{ .indexed = .default }, .attr = null, .char = undefined };
    var bottom_right_edge = Cell{ .fg = fg, .bg = .{ .indexed = .default }, .attr = null, .char = undefined };

    switch (borders) {
        .plain => {
            horizontal_border.char = '─';
            vertical_border.char = '│';
            top_left_edge.char = '┌';
            top_right_edge.char = '┐';
            bottom_left_edge.char = '└';
            bottom_right_edge.char = '┘';
        },
        .thick => {
            horizontal_border.char = '━';
            vertical_border.char = '┃';
            top_left_edge.char = '┏';
            top_right_edge.char = '┓';
            bottom_left_edge.char = '┗';
            bottom_right_edge.char = '┛';
        },
        .double_line => {
            horizontal_border.char = '═';
            vertical_border.char = '║';
            top_left_edge.char = '╔';
            top_right_edge.char = '╗';
            bottom_left_edge.char = '╚';
            bottom_right_edge.char = '╝';
        },
        .rounded => {
            horizontal_border.char = '─';
            vertical_border.char = '│';
            top_left_edge.char = '╭';
            top_right_edge.char = '╮';
            bottom_left_edge.char = '╰';
            bottom_right_edge.char = '╯';
        },
    }

    drawLine(screen, &top_left.add(&vec2(1, 0)), &top_right.sub(&vec2(1, 0)), &horizontal_border);
    drawLine(screen, &top_right.add(&vec2(0, 1)), &bottom_right.sub(&vec2(0, 1)), &vertical_border);
    drawLine(screen, &bottom_right.sub(&vec2(1, 0)), &bottom_left.add(&vec2(1, 0)), &horizontal_border);
    drawLine(screen, &bottom_left.sub(&vec2(0, 1)), &top_left.add(&vec2(0, 1)), &vertical_border);

    screen.writeCellF(top_left.x(), top_left.y(), &top_left_edge);
    screen.writeCellF(top_right.x(), top_right.y(), &top_right_edge);
    screen.writeCellF(bottom_left.x(), bottom_left.y(), &bottom_left_edge);
    screen.writeCellF(bottom_right.x(), bottom_right.y(), &bottom_right_edge);
}

pub fn drawTriangle(screen: *Screen, verticies: [3]*const Vec2, rotation: f32, style: *const Cell, filling: bool) void {
    const p1 = verticies[0];
    const p2 = verticies[1];
    const p3 = verticies[2];

    drawLine(screen, p1, p2, style);
    drawLine(screen, p2, p3, style);
    drawLine(screen, p3, p1, style);

    _ = rotation;
    _ = filling;
}

pub fn drawCircle(screen: *Screen, position: *const Vec2, radius: f32, style: *const Cell, filling: bool) void {
    var x: f32 = 0;
    var y = radius;
    var d = 3 - 2 * radius;

    while (y > x) {
        screen.writeCellF(x + position.x(), y + position.y(), style);
        screen.writeCellF(y + position.x(), x + position.y(), style);
        screen.writeCellF(-y + position.x(), x + position.y(), style);
        screen.writeCellF(-x + position.x(), y + position.y(), style);
        screen.writeCellF(-x + position.x(), -y + position.y(), style);
        screen.writeCellF(-y + position.x(), -x + position.y(), style);
        screen.writeCellF(y + position.x(), -x + position.y(), style);
        screen.writeCellF(x + position.x(), -y + position.y(), style);

        if (d > 0) {
            d = d + 4 * (x - y) + 10;
            y -= 1;
        } else {
            d = d + 4 * x + 6;
        }

        x += 1;
    }

    _ = filling;
}

pub fn drawText(screen: *Screen, content: []const u8, pos: *const Vec2, fg: Color, bg: Color, attr: ?Attribute) void {
    var style = Cell{
        .fg = fg,
        .bg = bg,
        .attr = attr,
        .char = ' ',
    };

    for (0..content.len) |i| {
        style.char = content[i];
        screen.writeCellF(pos.x() + @as(f32, @floatFromInt(i)), pos.y(), &style);
    }
}

pub const Particle = struct {
    style: Cell,
    lifetime: f32,
    velocity: Vec2,
    position: Vec2,

    pub fn render(self: *const Particle, screen: *Screen) void {
        _ = self;
        _ = screen;
    }
};

pub const ParticleEffect = struct {
    particles: std.ArrayList(*Particle),
    duration: f32,
    elapsedTime: f32,
    emissionRate: f32,
    particleLifetime: f32,
    startStyle: Cell,
    endStyle: Cell,
    isActive: bool,
    postion: Vec2,

    pub fn render(self: *const ParticleEffect, screen: *Screen) void {
        _ = self;
        _ = screen;
    }
};

pub fn spriteFromStr(str: *const [][]u21) Sprite {
    return Sprite{ .image = str.* };
}

pub const Flip = enum(u8) {
    vertical,
    horizontal,
    none,
};

const Sprite = struct {
    image: [][]u21,

    // pub fn draw(self: *const Sprite, screen: *Screen, position: *const Vec2, rotation: f32, flip: Flip, style: *const Cell) void {
    //     switch (flip) {
    //         .vertical => {},
    //         .horizontal => {},
    //         else => {},
    //     }
    //
    //     var x: f32 = 0.0;
    //     var y: f32 = 0.0;
    //     for (self.canvas) |char| {
    //         style.char = char;
    //         screen.writeCellF(position.x() + x, position.y() + y, style);
    //         x += 1.0;
    //         y += 1.0;
    //         if (std.meta.eql(char, '\n')) {
    //             y += 1.0;
    //             x = 0.0;
    //         }
    //     }
    //
    //     _ = rotation;
    // }
};
