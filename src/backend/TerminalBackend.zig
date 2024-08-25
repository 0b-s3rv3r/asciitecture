const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;
const stdout = std.io.getStdOut();
const os = std.os;
const backendMain = @import("main.zig");
const ScreenSize = backendMain.ScreenSize;
const Color = backendMain.Color;
const Attribute = backendMain.Attribute;
const Input = @import("input.zig").Input;

const TerminalBackend = @This();

handle: posix.fd_t,
orig_termios: posix.termios,
tty: std.fs.File,

pub fn init() !TerminalBackend {
    switch (builtin.os.tag) {
        .linux => {
            const handle = stdout.handle;
            return TerminalBackend{
                .orig_termios = try posix.tcgetattr(handle),
                .handle = handle,
                .tty = try std.fs.openFileAbsolute("/dev/tty", .{ .mode = .read_write }),
            };
        },
        else => @compileError("not implemented yet"),
    }
}

pub fn newScreen(_: *const TerminalBackend) !void {
    switch (builtin.os.tag) {
        .linux => {
            try stdout.writer().print("\x1b[?1049h", .{});
        },
        else => @compileError("not implemented yet"),
    }
}

pub fn endScreen(_: *const TerminalBackend) !void {
    switch (builtin.os.tag) {
        .linux => {
            try stdout.writer().print("\x1b[?1049l", .{});
        },
        else => @compileError("not implemented yet"),
    }
}

pub fn clearScreen(_: *const TerminalBackend) !void {
    switch (builtin.os.tag) {
        .linux => {
            try stdout.writer().print("\x1b[2J", .{});
        },
        else => @compileError("not implemented yet"),
    }
}

pub fn screenSize(self: *const TerminalBackend) !ScreenSize {
    switch (builtin.os.tag) {
        .linux => {
            var ws: posix.winsize = undefined;

            const err = std.os.linux.ioctl(self.handle, posix.T.IOCGWINSZ, @intFromPtr(&ws));
            if (posix.errno(err) != .SUCCESS) {
                return error.IoctlError;
            }

            return ScreenSize{ .x = ws.ws_col, .y = ws.ws_row };
        },
        else => @compileError("not implemented yet"),
    }
}

pub fn rawMode(self: *TerminalBackend) !void {
    switch (builtin.os.tag) {
        .linux => {
            var termios = try posix.tcgetattr(self.handle);

            termios.iflag.BRKINT = false;
            termios.iflag.ICRNL = false;
            termios.iflag.INPCK = false;
            termios.iflag.ISTRIP = false;
            termios.iflag.IXON = false;
            termios.oflag.OPOST = false;
            termios.cflag.CSIZE = .CS8;
            termios.lflag.ECHO = false;
            termios.lflag.ICANON = false;
            termios.lflag.IEXTEN = false;
            termios.lflag.ISIG = false;
            termios.cc[@intFromEnum(posix.V.MIN)] = 0;
            termios.cc[@intFromEnum(posix.V.TIME)] = 1;

            try posix.tcsetattr(self.handle, .FLUSH, termios);

            self.orig_termios = termios;
        },
        else => @compileError("not implemented yet"),
    }
}

pub fn normalMode(self: *const TerminalBackend) !void {
    switch (builtin.os.tag) {
        .linux => {
            try posix.tcsetattr(self.handle, .FLUSH, self.orig_termios);
        },
        else => @compileError("not implemented yet"),
    }
}

pub fn setCursor(_: *const TerminalBackend, x: u16, y: u16) !void {
    switch (builtin.os.tag) {
        .linux => {
            try stdout.writer().print("\x1b[{d};{d}H", .{ y, x });
        },
        else => @compileError("not implemented yet"),
    }
}

pub fn hideCursor(_: *const TerminalBackend) !void {
    switch (builtin.os.tag) {
        .linux => {
            try stdout.writer().print("\x1b[?25l", .{});
        },
        else => @compileError("not implemented yet"),
    }
}

pub fn showCursor(_: *const TerminalBackend) !void {
    switch (builtin.os.tag) {
        .linux => {
            try stdout.writer().print("\x1b[?25h", .{});
        },
        else => @compileError("not implemented yet"),
    }
}

pub fn putChar(_: *const TerminalBackend, char: u21) !void {
    switch (builtin.os.tag) {
        .linux => {
            var encodedChar: [4]u8 = undefined;
            const len = try std.unicode.utf8Encode(char, &encodedChar);
            try stdout.writer().print("{s}", .{encodedChar[0..len]});
        },
        else => @compileError("not implemented yet"),
    }
}

pub fn setFg(_: *const TerminalBackend, color: Color) !void {
    switch (builtin.os.tag) {
        .linux => {
            try stdout.writer().print("\x1b[38;5;{d}m", .{@intFromEnum(color)});
        },
        else => @compileError("not implemented yet"),
    }
}

pub fn setBg(_: *const TerminalBackend, color: Color) !void {
    switch (builtin.os.tag) {
        .linux => {
            try stdout.writer().print("\x1b[48;5;{d}m", .{@intFromEnum(color)});
        },
        else => @compileError("not implemented yet"),
    }
}

pub fn setFgRgb(_: *const TerminalBackend, r: u8, g: u8, b: u8) !void {
    switch (builtin.os.tag) {
        .linux => {
            try stdout.writer().print("\x1b[38;2;{d};{d};{d}m", .{ r, g, b });
        },
        else => @compileError("not implemented yet"),
    }
}

pub fn setBgRgb(_: *const TerminalBackend, r: u8, g: u8, b: u8) !void {
    switch (builtin.os.tag) {
        .linux => {
            try stdout.writer().print("\x1b[48;2;{d};{d};{d}m", .{ r, g, b });
        },
        else => @compileError("not implemented yet"),
    }
}

pub fn setAttr(_: *const TerminalBackend, attr: []const u8) !void {
    switch (builtin.os.tag) {
        .linux => {
            try stdout.writer().print("\x1b[{s}", .{attr});
        },
        else => @compileError("not implemented yet"),
    }
}

pub fn keyPoll(self: *const TerminalBackend) !Input {
    var buf: [16]u8 = undefined;
    _ = try self.tty.read(&buf);
    return try parseKeyCode(&buf);
}

fn parseKeyCode(buf: []const u8) !Input {
    var input = Input{
        .key = 0,
        .ctrl = false,
        .shift = false,
        .alt = false,
    };
    var cpIter = (try std.unicode.Utf8View.init(buf)).iterator();
    while (cpIter.nextCodepoint()) |cp| {
        switch (cp) {
            0x41...0x5A => {
                input.key = cp;
                input.shift = true;
            },
            0x10 => {
                input.shift = true;
            },
            0x11 => {
                input.ctrl = true;
            },
            0x12 => {
                input.alt = true;
            },
            else => {
                input.key = cp;
            },
        }
    }
    return input;
}