const std = @import("std");
const at = @import("asciitecture");
const graphics = at.graphics;
const LinuxTty = at.LinuxTty;
const Input = at.input.Input;
const Key = at.input.Key;
const vec2 = at.math.vec2;
const extra = at.extra;
const widgets = at.widgets;

pub fn main() !void {
    // init
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("memory leak occured");

    var term = try at.Terminal(LinuxTty).init(gpa.allocator(), 75, 1);
    defer term.deinit() catch |err| @panic(@errorName(err));
    errdefer term.deinit() catch |err| @panic(@errorName(err));

    var input = try Input.init(gpa.allocator());
    defer input.deinit() catch |err| @panic(@errorName(err));
    errdefer input.deinit() catch |err| @panic(@errorName(err));

    // game state
    var rect_posx: f32 = 0;
    var rect_speed: f32 = 1;
    var text_pos = vec2(0, 0);
    var text_speed = vec2(1, 1);
    var view_pos = vec2(0, 0);
    var view_direction: f32 = 1;
    const max_jump: f32 = 0;
    var is_falling = false;
    var start_jump = false;
    var name: [30]u8 = undefined;
    var name_len: usize = 0;
    const image =
        \\  @X@  
        \\  XXX  
        \\   X   
        \\#XXXXX#
        \\   X   
        \\  X X  
        \\ X   X 
        \\#     #
    ;

    // text area segment
    {
        var text_entered = false;
        var text_area = try widgets.TextArea.init(gpa.allocator(), .{
            .pos = vec2(0, 0),
            .width = 10,
            .text_style = .{ .fg = .{ .indexed = .red }, .bg = .{ .indexed = .black }, .attr = .bold },
            .cursor_style = .{ .indexed = .green },
            .border = .plain,
            .border_style = .{ .fg = .{ .indexed = .magenta }, .bg = .{ .indexed = .black }, .attr = .bold },
        });
        defer text_area.deinit();

        while (!text_entered) {
            text_area.draw(&term.screen);
            try term.draw();
            if (input.nextEvent()) |key| {
                switch (key.key) {
                    .enter => {
                        const buffer = text_area.buffer();
                        name_len = buffer.len;
                        @memcpy(name[0..name_len], buffer);
                        text_entered = true;
                    },
                    .escape => return,
                    else => try text_area.input(&key),
                }
            }
        }
    }

    // main loop
    while (true) {
        extra.waveAnim(&term.screen, &vec2(0, 0), .{ .r = 0, .g = 0, .b = 255 });

        graphics.drawParticles(&term.screen, &vec2(-62, 17), 10, 5, 3, &.{ .char = '●', .style = .{ .fg = .{ .indexed = .cyan }, .bg = .{ .indexed = .black }, .attr = .none } });
        graphics.drawParticles(&term.screen, &vec2(-70, 15), 15, 10, 5, &.{ .char = '●', .style = .{ .fg = .{ .indexed = .blue }, .bg = .{ .indexed = .black }, .attr = .none } });
        graphics.drawParticles(&term.screen, &vec2(-75, 10), 30, 20, 2, &.{ .char = '●', .style = .{ .fg = .{ .indexed = .red }, .bg = .{ .indexed = .black }, .attr = .none } });

        graphics.spriteFromStr(image).draw(&term.screen, &vec2(0, 27), 0, .none, &.{ .fg = .{ .rgb = .{ .r = 127, .g = 176, .b = 5 } }, .bg = .{ .indexed = .black }, .attr = .none });

        graphics.drawLine(&term.screen, &vec2(50.0, 20.0), &vec2(-50.0, 20.0), &.{ .char = ' ', .style = .{ .fg = .{ .indexed = .black }, .bg = .{ .indexed = .red }, .attr = .none } });

        graphics.drawCubicSpline(&term.screen, &vec2(0, 0), &vec2(10, 50), &vec2(50, -30), &vec2(100, 25), &.{ .char = '—', .style = .{ .fg = .{ .rgb = .{ .r = 250, .g = 157, .b = 0 } }, .bg = .{ .indexed = .black }, .attr = .none } });

        graphics.drawRectangle(&term.screen, 10, 10, &vec2(rect_posx, 0.0), 45, &.{ .char = ' ', .style = .{ .fg = .{ .indexed = .black }, .bg = .{ .indexed = .cyan }, .attr = .none } }, false);

        graphics.drawPrettyRectangle(&term.screen, 10, 10, &vec2(-30.0, -5.0), .plain, &.{ .fg = .{ .indexed = .white }, .bg = .{ .indexed = .black }, .attr = .none }, null);
        graphics.drawPrettyRectangle(&term.screen, 10, 10, &vec2(-20.0, -5.0), .thick, &.{ .fg = .{ .indexed = .white }, .bg = .{ .indexed = .black }, .attr = .none }, null);
        graphics.drawPrettyRectangle(&term.screen, 10, 10, &vec2(-10.0, -5.0), .rounded, &.{ .fg = .{ .indexed = .white }, .bg = .{ .indexed = .black }, .attr = .none }, null);
        graphics.drawPrettyRectangle(&term.screen, 10, 10, &vec2(0.0, -5.0), .double_line, &.{ .fg = .{ .indexed = .white }, .bg = .{ .indexed = .black }, .attr = .none }, null);

        graphics.drawTriangle(&term.screen, .{ &vec2(100.0, 15.0), &vec2(80.0, 40.0), &vec2(120.0, 40.0) }, 0, &.{ .char = '●', .style = .{ .fg = .{ .indexed = .yellow }, .bg = .{ .indexed = .black }, .attr = .none } }, false);

        graphics.drawCircle(&term.screen, &vec2(-35.0, 2.0), 15, &.{ .char = '●', .style = .{ .fg = .{ .indexed = .magenta }, .bg = .{ .indexed = .black }, .attr = .none } }, false);

        graphics.drawText(&term.screen, "Goodbye, World!", &text_pos, &.{ .fg = .{ .indexed = .green }, .bg = .{ .indexed = .black }, .attr = .none });

        term.screen.writeCell(3, 4, &.{ .char = ' ', .style = .{ .bg = .{ .indexed = .white }, .fg = .{ .indexed = .black }, .attr = .none } });
        term.screen.writeCell(4, 4, &.{ .char = ' ', .style = .{ .bg = .{ .indexed = .white }, .fg = .{ .indexed = .black }, .attr = .none } });
        term.screen.writeCell(5, 5, &.{ .char = ' ', .style = .{ .bg = .{ .indexed = .white }, .fg = .{ .indexed = .black }, .attr = .none } });
        term.screen.writeCell(6, 5, &.{ .char = ' ', .style = .{ .bg = .{ .indexed = .white }, .fg = .{ .indexed = .black }, .attr = .none } });
        term.screen.writeCell(5, 3, &.{ .char = ' ', .style = .{ .bg = .{ .indexed = .white }, .fg = .{ .indexed = .black }, .attr = .none } });
        term.screen.writeCell(6, 3, &.{ .char = ' ', .style = .{ .bg = .{ .indexed = .white }, .fg = .{ .indexed = .black }, .attr = .none } });
        term.screen.writeCell(7, 4, &.{ .char = ' ', .style = .{ .bg = .{ .indexed = .white }, .fg = .{ .indexed = .black }, .attr = .none } });
        term.screen.writeCell(8, 4, &.{ .char = ' ', .style = .{ .bg = .{ .indexed = .white }, .fg = .{ .indexed = .black }, .attr = .none } });

        graphics.drawLine(&term.screen, &view_pos, &vec2(view_pos.x(), view_pos.y() + 2), &.{ .char = ' ', .style = .{ .fg = .{ .indexed = .bright_white }, .bg = .{ .indexed = .bright_white }, .attr = .none } });
        term.screen.writeCellF(view_pos.x(), view_pos.y() - 1, &.{ .char = '@', .style = .{ .fg = .{ .indexed = .magenta }, .bg = .{ .indexed = .black }, .attr = .none } });
        graphics.drawText(&term.screen, name[0..name_len], &view_pos.add(&vec2(-5, -5)), &.{ .fg = .{ .indexed = .bright_magenta }, .bg = .{ .indexed = .white }, .attr = .dim });

        var buf1: [100]u8 = undefined;
        const delta_time = try std.fmt.bufPrint(&buf1, "delta_time:{d:.20}", .{term.delta_time});
        graphics.drawText(&term.screen, delta_time, &(vec2(-100.0, 25.0).add(&view_pos)), &.{ .fg = .{ .indexed = .black }, .bg = .{ .indexed = .white }, .attr = .bold });

        var buf2: [100]u8 = undefined;
        const fps = try std.fmt.bufPrint(&buf2, "fps:{d:.2}", .{term.fps});
        graphics.drawText(&term.screen, fps, &(vec2(-100.0, 26.0).add(&view_pos)), &.{ .fg = .{ .indexed = .black }, .bg = .{ .indexed = .white }, .attr = .bold });

        // const rot1 = vec2(50.0, 20.0).rotate(90, &vec2(0, 0));
        // const rot2 = vec2(-50.0, -20.0).rotate(90, &vec2(0, 0));

        // var buf3: [100]u8 = undefined;
        // const rot = try std.fmt.bufPrint(&buf3, "rot:{} {}", .{ rot1, rot2 });
        // graphics.drawText(&term.screen, rot, &vec2(-20.0, -16.0), .{ .indexed = .black }, .{ .indexed = .black }, null);

        // graphics.drawLine(&term.screen, &rot1, &rot2, &.{ .char = ' ', .fg = .{ .indexed = .black }, .bg = .{ .indexed = .green }, .attr = null });
        // graphics.drawLine(&term.screen, &vec2(-20.0, 50.0), &vec2(20.0, -50.0), &.{ .char = ' ', .fg = .{ .indexed = .black }, .bg = .{ .indexed = .green }, .attr = null });

        term.screen.setView(&view_pos);
        rect_posx += rect_speed;
        text_pos = text_pos.add(&text_speed);
        if (view_pos.y() <= max_jump) {
            is_falling = true;
            start_jump = false;
        }
        if (view_pos.y() == 17) {
            is_falling = false;
        }
        if (is_falling) {
            view_pos = view_pos.add(&vec2(0, 0.5));
            start_jump = false;
        }
        if (start_jump) {
            view_pos = view_pos.add(&vec2(0, -0.5));
        }

        const width: f32 = @floatFromInt(term.screen.ref_size.cols);
        const height: f32 = @floatFromInt(term.screen.ref_size.rows);
        if (text_pos.x() >= (width / 2) - 14.0 or text_pos.x() <= (-width / 2) + 1.0) text_speed = text_speed.mul(&vec2(-1.0, 1.0));
        if (text_pos.y() >= height / 2 or text_pos.y() <= (-height / 2) + 1.0) text_speed = text_speed.mul(&vec2(1.0, -1.0));
        if (rect_posx == 60) rect_speed *= -1.0;
        if (rect_posx == 0) rect_speed *= -1.0;

        try term.draw();

        if (input.contains(&.{ .key = .d })) {
            view_direction = 1;
            view_pos = view_pos.add(&vec2(1 * view_direction, 0));
        }
        if (input.contains(&.{ .key = .a })) {
            view_direction = -1;
            view_pos = view_pos.add(&vec2(1 * view_direction, 0));
        }
        if (input.contains(&.{ .key = .space })) {
            start_jump = true;
        }
        if (input.contains(&.{ .key = .escape })) {
            break;
        }
    }
}
