const std = @import("std");
const at = @import("asciitecture");
const LinuxTty = at.LinuxTty;
const Terminal = at.Terminal;
const Painter = at.Painter;
const Input = at.input.Input;
const Vec2 = at.math.Vec2;
const vec2 = at.math.vec2;
const Shape = at.math.Shape;
const ParticleEmitter = at.ParticleEmitter;
const Animation = at.sprite.Animation;
const spriteFromStr = at.sprite.spriteFromStr;
const Style = at.style.Style;
const Color = at.style.Color;
const IndexedColor = at.style.IndexedColor;
const Paragraph = at.widgets.Paragraph;
const Menu = at.widgets.Menu;
const TextArea = at.widgets.TextArea;
const Line = at.math.Line;
const Sprite = at.sprite.Sprite;
const Rectangle = at.math.Rectangle;

pub fn main() !void {
    // init
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("memory leak occured");

    var term = try Terminal(LinuxTty).init(gpa.allocator(), 75, .{ .rows = 35, .cols = 105 });
    defer term.deinit() catch |err| @panic(@errorName(err));

    var painter = term.painter();

    var input = try Input.init();
    defer input.deinit() catch |err| @panic(@errorName(err));

    // game state
    var player_pos = vec2(0, (35 / 2) - 4);
    var player_velocity = vec2(0, 0);
    var name: [10]u8 = undefined;
    var name_len: usize = undefined;
    var player_collider = Shape{ .rectangle = Rectangle.init(&player_pos, 3, 3) };
    var floor_collider = Shape{ .line = Line.init(&vec2(-105 / 2, (35 / 2) - 1), &vec2(105 / 2, (35 / 2) - 1)) };
    const box_collider = Shape{ .rectangle = Rectangle.init(&vec2(-30, (35 / 2) - 6), 10, 5) };
    const colliders = [_]*const Shape{ &floor_collider, &box_collider };
    const gravity = vec2(0, 0.5);
    player_pos.v[1] -= 1;

    const idle =
        \\ o
        \\/|\
        \\/ \
    ;
    const walk_right =
        \\ o
        \\(|\
        \\/ )
    ;
    const walk_right2 =
        \\ o
        \\(|\
        \\ ) 
    ;
    const walk_right3 =
        \\ o
        \\\|(
        \\/ )
    ;
    const walk_left =
        \\ o
        \\/|)
        \\( \
    ;
    const walk_left2 =
        \\ o
        \\/|)
        \\ ( 
    ;
    const walk_left3 =
        \\ o
        \\)|/
        \\( \
    ;

    const player_style = Style{ .fg = IndexedColor.green };

    var anim_right = Animation.init(gpa.allocator(), 2, true);
    defer anim_right.deinit();
    try anim_right.frames.append(&spriteFromStr(walk_right, &player_style));
    try anim_right.frames.append(&spriteFromStr(walk_right2, &player_style));
    try anim_right.frames.append(&spriteFromStr(walk_right3, &player_style));

    var anim_left = Animation.init(gpa.allocator(), 2, true);
    defer anim_left.deinit();
    try anim_left.frames.append(&spriteFromStr(walk_left, &player_style));
    try anim_left.frames.append(&spriteFromStr(walk_left2, &player_style));
    try anim_left.frames.append(&spriteFromStr(walk_left3, &player_style));

    var idle_sprite = spriteFromStr(idle, &player_style);

    var logo = try Paragraph.init(gpa.allocator(), &[_][]const u8{"ASCIItecture"}, &.{
        .border_style = .{
            .border = .rounded,
            .style = .{
                .fg = IndexedColor.cyan,
                .attr = .bold,
            },
        },
        .text_style = .{
            .fg = IndexedColor.red,
            .attr = .bold,
        },
        .filling = true,
        .animation = .{
            .speed = 5,
            .looping = true,
        },
    });
    defer logo.deinit();

    var npc_cloud = try Paragraph.init(gpa.allocator(), &[_][]const u8{
        "Hello!",
        "Use:",
        "->/<- to move right/left",
        "c to jump",
        "x to blow the bubbles",
    }, &.{
        .border_style = .{
            .border = .rounded,
            .style = .{
                .fg = IndexedColor.white,
                .attr = .bold,
            },
        },
        .text_style = .{
            .fg = IndexedColor.white,
            .attr = .bold,
        },
        .filling = false,
        .animation = .{
            .speed = 15,
            .looping = false,
        },
    });
    defer npc_cloud.deinit();

    var fire = try ParticleEmitter.init(gpa.allocator(), &.{
        .pos = vec2(55, (35 / 2) - 2),
        .amount = 100,
        .chars = &[_]u21{' '},
        .fg_color = null,
        .bg_color = .{
            .start = .{ .r = 190, .g = 60, .b = 30 },
            .end = .{ .r = 0, .g = 0, .b = 0 },
        },
        .color_var = 5,
        .start_angle = 30,
        .end_angle = 150,
        .life = 2,
        .life_var = 1,
        .speed = 10,
        .speed_var = 5,
        .emission_rate = 100 / 2,
        .gravity = vec2(0, 0),
        .duration = std.math.inf(f32),
    });
    defer fire.deinit();

    var bubbles = try ParticleEmitter.init(gpa.allocator(), &.{
        .pos = player_pos,
        .amount = 50,
        .chars = &[_]u21{'○'},
        .fg_color = .{
            .start = .{ .r = 125, .g = 125, .b = 125 },
            .end = .{ .r = 125, .g = 125, .b = 125 },
        },
        .bg_color = null,
        .color_var = 50,
        .start_angle = 60,
        .end_angle = 120,
        .life = 2,
        .life_var = 1,
        .speed = 20,
        .speed_var = 5,
        .emission_rate = 50 / 2,
        .gravity = vec2(0, 0),
        .duration = std.math.inf(f32),
    });
    defer bubbles.deinit();

    // menu
    {
        var menu = Menu.init(gpa.allocator(), &.{
            .width = 50,
            .height = 21,
            .orientation = .vertical,
            .padding = 1,
            .border = .{
                .border = .rounded,
                .style = .{
                    .fg = IndexedColor.white,
                },
                .filling = false,
            },
            .element = .{
                .style = .{
                    .fg = IndexedColor.white,
                },
                .filling = false,
            },
            .selection = .{
                .element_style = .{
                    .fg = IndexedColor.red,
                },
                .text_style = .{
                    .fg = IndexedColor.red,
                },
                .filling = false,
            },
            .text_style = .{
                .fg = IndexedColor.white,
            },
        });
        defer menu.deinit();

        try menu.items.append("play");
        try menu.items.append("exit");

        while (true) {
            try menu.draw(&painter, &vec2(-25, -12.5));
            try term.draw();
            if (input.nextEvent()) |key| {
                switch (key.key) {
                    .enter => {
                        switch (menu.selected_item) {
                            0 => break,
                            1 => return,
                            else => {},
                        }
                    },
                    .escape => return,
                    .down => menu.next(),
                    .up => menu.previous(),
                    else => {},
                }
            }
        }
    }

    // text area
    {
        var text_entered = false;
        var color = IndexedColor.magenta;
        var text_area = try TextArea.init(gpa.allocator(), &.{
            .width = 20,
            .text_style = .{ .fg = color, .attr = .bold },
            .cursor_style = IndexedColor.green,
            .border = .plain,
            .border_style = .{ .fg = color, .attr = .bold },
            .filling = false,
            .placeholder = .{
                .content = "Type your nickname here...",
                .style = .{
                    .fg = IndexedColor.bright_black,
                },
            },
        });
        defer text_area.deinit();

        while (!text_entered) {
            try text_area.draw(&painter, &vec2(-10, 0));
            try term.draw();
            if (input.nextEvent()) |key| {
                switch (key.key) {
                    .enter => {
                        const buffer = text_area.buffer();
                        name_len = buffer.len;
                        if (name_len < name.len) {
                            @memcpy(name[0..name_len], buffer);
                            text_entered = true;
                        }
                    },
                    .escape => return,
                    else => try text_area.input(&key),
                }
            }

            if (text_area.buffer().len >= name.len) {
                color = IndexedColor.red;
            } else {
                color = IndexedColor.magenta;
            }
            text_area.config.text_style.fg = color;
            text_area.config.border_style.fg = color;
        }
    }

    // main loop
    while (true) {
        // input handling
        {
            if (input.contains(.left)) {
                player_velocity.v[0] = -20;
            } else if (input.contains(.right)) {
                player_velocity.v[0] = 20;
            } else {
                player_velocity.v[0] = 0;
            }
            if (input.contains(.x)) {
                bubbles.config.emission_rate = 50 / 2;
            } else {
                bubbles.config.emission_rate = 0;
            }
            if (input.contains(.escape)) {
                break;
            }
        }

        // update game state
        {
            for (&colliders) |collider| {
                switch (collider.*) {
                    .line => |*lin| {
                        if (player_collider.rectangle.collidesWith(collider)) {
                            player_pos.v[1] = lin.p1.y() - 3 - std.math.floatEps(f32);
                        }
                    },
                    .rectangle => |*rec| {
                        if (player_collider.rectangle.collidesWith(collider)) {
                            if (player_velocity.x() > 0) {
                                player_pos.v[0] = rec.pos.x() - player_collider.rectangle.width;
                            } else {
                                player_pos.v[0] = rec.pos.x() + rec.width;
                            }
                        }
                    },
                    else => {},
                }
            }

            term.setViewPos(&player_pos.add(&vec2(0, (-35 / 2) + 4)));
            player_collider.rectangle.pos = player_pos;
            floor_collider.line.p1 = vec2(player_pos.x(), floor_collider.line.p1.y()).add(&vec2(-105 / 2, 0));
            floor_collider.line.p2 = vec2(player_pos.x(), floor_collider.line.p2.y()).add(&vec2(105 / 2, 0));
            player_velocity.v[1] += gravity.y() * term.delta_time;
            player_pos = player_pos.add(&player_velocity.mul(&vec2(term.delta_time, term.delta_time)));
            bubbles.config.pos = player_pos.add(&vec2(2, 0));
        }

        // drawing
        {

            // pyramide
            painter.setCell(&.{ .char = '┘', .bg = IndexedColor.yellow, .fg = IndexedColor.bright_black });
            painter.drawTriangle(&vec2(-105 / 2, (35 / 2) - 1), &vec2(105 / 2, (35 / 2) - 1), &vec2(0, -4), true);

            // moon
            painter.setCell(&.{ .char = ' ', .bg = IndexedColor.bright_black });
            painter.drawEllipse(&vec2(-30, -10), 7, &vec2(0, 0.5), true);

            // logo
            try logo.draw(&painter, &vec2(-6, 5), term.delta_time);

            // bonfire
            fire.draw(&painter, term.delta_time);
            painter.setCell(&.{ .bg = IndexedColor.bright_black });
            painter.drawLine(&fire.config.pos.add(&vec2(-3, 0)), &fire.config.pos.add(&vec2(3, 0)));

            // npc
            const npc_pos = fire.config.pos.add(&vec2(10, -2));
            idle_sprite.style = .{ .fg = IndexedColor.red };
            try idle_sprite.draw(&painter, &npc_pos);
            if (player_pos.x() <= npc_pos.add(&vec2(10, 0)).x() and player_pos.x() >= npc_pos.sub(&vec2(10, 0)).x()) {
                try npc_cloud.draw(&painter, &npc_pos.add(&vec2(-4, -7)), term.delta_time);
            } else {
                npc_cloud.reset();
            }

            // floor
            painter.setCell(&.{ .bg = IndexedColor.bright_black });
            painter.drawLineShape(&floor_collider.line);

            // box
            painter.setCell(&.{ .bg = IndexedColor.bright_red });
            painter.drawRectangleShape(&box_collider.rectangle, true);

            // player
            idle_sprite.style = player_style;
            if (player_velocity.x() > 0) {
                try anim_right.draw(&painter, &player_pos, term.delta_time);
            } else if (player_velocity.x() < 0) {
                try anim_left.draw(&painter, &player_pos, term.delta_time);
            } else {
                try idle_sprite.draw(&painter, &player_pos);
            }
            painter.setCell(&.{ .fg = IndexedColor.red, .bg = IndexedColor.white });
            try painter.drawText(name[0..name_len], &player_pos.add(&vec2(-@as(f32, @floatFromInt(name_len / 2)), -2)));
            bubbles.draw(&painter, term.delta_time);

            // fps overlay
            painter.setDrawingSpace(.screen);
            painter.setCell(&.{ .fg = IndexedColor.magenta });
            var buf: [5]u8 = undefined;
            const fps = try std.fmt.bufPrint(&buf, "{d:.0}", .{1.0 / term.delta_time});
            try painter.drawText(fps, &(vec2((105 / 2) - 4, -35 / 2 - 0.5)));
            painter.setDrawingSpace(.world);
        }

        try term.draw();
    }
}
