const std = @import("std");
const x11 = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/keysymdef.h");
    @cInclude("X11/extensions/Xrandr.h");
});

pub const Input = struct {
    _backend: InputBackend,

    pub fn init(allocator: std.mem.Allocator) !Input {
        if (std.posix.getenv("DISPLAY") != null)
            return .{ ._backend = .{ .x11 = try X11Input.init(allocator) } }
        else
            return .{ ._backend = .{ .std = StdInput.init(allocator) } };
    }

    pub fn deinit(self: *Input) !void {
        switch (self._backend) {
            .x11 => |*be| try be.deinit(),
            .std => |*be| be.deinit(),
        }
    }

    pub fn contains(self: *Input, key: *const KeyInput) bool {
        switch (self._backend) {
            .x11 => |*be| {
                return be.contains(key) catch |err|
                    @panic(@errorName(err));
            },
            .std => |*be| {
                return be.contains(key) catch |err|
                    @panic(@errorName(err));
            },
        }
    }

    pub fn nextEvent(self: *Input) ?KeyInput {
        switch (self._backend) {
            .x11 => |*be| {
                return be.nextEvent() catch |err|
                    @panic(@errorName(err));
            },
            .std => |*be| {
                return be.nextEvent() catch |err|
                    @panic(@errorName(err));
            },
        }
    }
};

const InputBackend = union(enum) {
    x11: X11Input,
    std: StdInput,
};

pub const KeyInput = struct {
    key: Key,
    mod: KeyMod = .{},

    pub fn eql(a: *const KeyInput, b: *const KeyInput) bool {
        return @intFromEnum(a.key) == @intFromEnum(b.key) and a.mod.ctrl == b.mod.ctrl and a.mod.alt == b.mod.alt and a.mod.shift == b.mod.shift;
    }
};

pub const KeyMod = packed struct(u8) {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    _padding: u5 = undefined,
};

pub const Key = enum {
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,
    zero,
    one,
    two,
    three,
    four,
    five,
    six,
    seven,
    eight,
    nine,
    tab,
    enter,
    escape,
    space,
    backspace,
    insert,
    delete,
    left,
    right,
    up,
    down,
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    shift,
    control,
    alt,
    unknown,
};

const X11Input = struct {
    _display: *x11.Display,
    _key_state: std.AutoHashMap(KeyInput, bool),

    pub fn init(allocator: std.mem.Allocator) !X11Input {
        const dpy = x11.XOpenDisplay(null) orelse return error.X11Error;
        var focused: x11.Window = undefined;
        var revert: i32 = undefined;
        _ = x11.XGetInputFocus(dpy, &focused, &revert);
        _ = x11.XSelectInput(dpy, focused, x11.KeyPressMask | x11.KeyReleaseMask | x11.FocusChangeMask);
        _ = x11.XAutoRepeatOff(dpy);
        _ = x11.XSynchronize(dpy, 1);
        return .{ ._display = dpy, ._key_state = std.AutoHashMap(KeyInput, bool).init(allocator) };
    }

    pub fn contains(self: *X11Input, key: *const KeyInput) !bool {
        _ = try self.nextEvent();
        if (self._key_state.get(key.*)) |k| {
            return k;
        }
        return false;
    }

    pub fn nextEvent(self: *X11Input) !?KeyInput {
        if (x11.XPending(self._display) > 0) {
            var event: x11.XEvent = undefined;
            _ = x11.XNextEvent(self._display, &event);
            switch (event.type) {
                x11.KeyPress => {
                    var keysym: x11.KeySym = undefined;
                    _ = x11.XLookupString(&event.xkey, null, 0, &keysym, null);
                    const key = KeyInput{ .key = toKey(keysym), .mod = toMod(event.xkey.state) };
                    try self._key_state.put(key, true);
                    return key;
                },
                x11.KeyRelease => {
                    var keysym: x11.KeySym = undefined;
                    _ = x11.XLookupString(&event.xkey, null, 0, &keysym, null);
                    const key = KeyInput{ .key = toKey(keysym), .mod = toMod(event.xkey.state) };
                    try self._key_state.put(key, false);
                },
                x11.FocusOut => {
                    _ = x11.XAutoRepeatOn(self._display);
                },
                x11.FocusIn => {
                    _ = x11.XAutoRepeatOff(self._display);
                },
                else => {},
            }
        }
        return null;
    }

    fn toMod(mods: x11.KeySym) KeyMod {
        return .{
            .shift = mods & x11.ShiftMask != 0,
            .ctrl = mods & x11.ControlMask != 0,
            .alt = mods & x11.Mod1Mask != 0,
        };
    }

    fn toKey(key: x11.KeySym) Key {
        return switch (key) {
            x11.XK_a, x11.XK_A => .a,
            x11.XK_b, x11.XK_B => .b,
            x11.XK_c, x11.XK_C => .c,
            x11.XK_d, x11.XK_D => .d,
            x11.XK_e, x11.XK_E => .e,
            x11.XK_f, x11.XK_F => .f,
            x11.XK_g, x11.XK_G => .g,
            x11.XK_h, x11.XK_H => .h,
            x11.XK_i, x11.XK_I => .i,
            x11.XK_j, x11.XK_J => .j,
            x11.XK_k, x11.XK_K => .k,
            x11.XK_l, x11.XK_L => .l,
            x11.XK_m, x11.XK_M => .m,
            x11.XK_n, x11.XK_N => .n,
            x11.XK_o, x11.XK_O => .o,
            x11.XK_p, x11.XK_P => .p,
            x11.XK_q, x11.XK_Q => .q,
            x11.XK_r, x11.XK_R => .r,
            x11.XK_s, x11.XK_S => .s,
            x11.XK_t, x11.XK_T => .t,
            x11.XK_u, x11.XK_U => .u,
            x11.XK_v, x11.XK_V => .v,
            x11.XK_w, x11.XK_W => .w,
            x11.XK_x, x11.XK_X => .x,
            x11.XK_y, x11.XK_Y => .y,
            x11.XK_z, x11.XK_Z => .z,
            x11.XK_0 => .zero,
            x11.XK_1 => .one,
            x11.XK_2 => .two,
            x11.XK_3 => .three,
            x11.XK_4 => .four,
            x11.XK_5 => .five,
            x11.XK_6 => .six,
            x11.XK_7 => .seven,
            x11.XK_8 => .eight,
            x11.XK_9 => .nine,
            x11.XK_F1 => .f1,
            x11.XK_F2 => .f2,
            x11.XK_F3 => .f3,
            x11.XK_F4 => .f4,
            x11.XK_F5 => .f5,
            x11.XK_F6 => .f6,
            x11.XK_F7 => .f7,
            x11.XK_F8 => .f8,
            x11.XK_F9 => .f9,
            x11.XK_F10 => .f10,
            x11.XK_F11 => .f11,
            x11.XK_F12 => .f12,
            x11.XK_Return => .enter,
            x11.XK_Escape => .escape,
            x11.XK_Tab => .tab,
            x11.XK_Shift_L, x11.XK_Shift_R => .shift,
            x11.XK_Control_L, x11.XK_Control_R => .control,
            x11.XK_Alt_L, x11.XK_Alt_R => .alt,
            x11.XK_Left => .left,
            x11.XK_Right => .right,
            x11.XK_Up => .up,
            x11.XK_Down => .down,
            x11.XK_space => .space,
            x11.XK_BackSpace => .backspace,
            else => .unknown,
        };
    }

    pub fn deinit(self: *X11Input) !void {
        self._key_state.deinit();
        _ = x11.XAutoRepeatOn(self._display);
        _ = x11.XCloseDisplay(self._display);
    }
};

const StdInput = struct {
    stdin: std.fs.File.Reader,
    _key_state: std.AutoHashMap(KeyInput, i128),

    pub fn init(allocator: std.mem.Allocator) StdInput {
        return .{
            .stdin = std.io.getStdIn().reader(),
            ._key_state = std.AutoHashMap(KeyInput, i128).init(allocator),
        };
    }

    pub fn deinit(self: *StdInput) void {
        self._key_state.deinit();
    }

    pub fn contains(self: *StdInput, key: *const KeyInput) !bool {
        _ = try self.nextEvent();
        if (self._key_state.get(key.*)) |k| {
            if ((std.time.nanoTimestamp() - k) <= 500000000) {
                return true;
            }
        }
        return false;
    }

    pub fn nextEvent(self: *StdInput) !?KeyInput {
        var buf: [3]u8 = undefined;
        const c = try self.stdin.read(&buf);
        const key = try toKeyInput(buf[0..c]) orelse null;
        if (key) |ev| {
            try self._key_state.put(ev, std.time.nanoTimestamp());
        }
        return key;
    }

    fn toKeyInput(buf: []const u8) !?KeyInput {
        const view = try std.unicode.Utf8View.init(buf);
        var iter = view.iterator();
        if (iter.bytes.len == 0) return null;

        var input = KeyInput{ .key = .unknown, .mod = .{ .alt = false, .shift = false, .ctrl = false } };
        if (iter.nextCodepoint()) |c0| switch (c0) {
            '\x1b' => {
                input.key = .escape;
                if (iter.nextCodepoint()) |c1| switch (c1) {
                    '[' => {
                        switch (buf[2]) {
                            'A' => input.key = .up,
                            'B' => input.key = .down,
                            'C' => input.key = .right,
                            'D' => input.key = .left,
                            '1' => {
                                if (iter.nextCodepoint()) |c2| switch (c2) {
                                    '5' => input.key = .f5,
                                    '7' => input.key = .f6,
                                    '8' => input.key = .f7,
                                    '9' => input.key = .f8,
                                    '1' => {
                                        if (iter.nextCodepoint()) |c3| switch (c3) {
                                            '0' => input.key = .f9,
                                            '1' => input.key = .f10,
                                            '3' => input.key = .f11,
                                            '4' => input.key = .f12,
                                            else => {},
                                        };
                                    },
                                    else => {},
                                };
                            },
                            else => {},
                        }
                    },
                    'O' => {
                        switch (buf[2]) {
                            'P' => input.key = .f1,
                            'Q' => input.key = .f2,
                            'R' => input.key = .f3,
                            'S' => input.key = .f4,
                            else => {},
                        }
                    },
                    else => {},
                };
            },
            '\x09' => input.key = Key.tab,
            '\x0D' => input.key = Key.enter,
            '\x08' => input.key = Key.backspace,
            '\x20' => input.key = Key.space,
            'a' => input.key = .a,
            'b' => input.key = .b,
            'c' => input.key = .c,
            'd' => input.key = .d,
            'e' => input.key = .e,
            'f' => input.key = .f,
            'g' => input.key = .g,
            'h' => input.key = .h,
            'i' => input.key = .i,
            'j' => input.key = .j,
            'k' => input.key = .k,
            'l' => input.key = .l,
            'm' => input.key = .m,
            'n' => input.key = .n,
            'o' => input.key = .o,
            'p' => input.key = .p,
            'q' => input.key = .q,
            'r' => input.key = .r,
            's' => input.key = .s,
            't' => input.key = .t,
            'u' => input.key = .u,
            'v' => input.key = .v,
            'w' => input.key = .w,
            'x' => input.key = .x,
            'y' => input.key = .y,
            'z' => input.key = .z,
            '1' => input.key = .one,
            '2' => input.key = .two,
            '3' => input.key = .three,
            '4' => input.key = .four,
            '5' => input.key = .five,
            '6' => input.key = .six,
            '7' => input.key = .seven,
            '8' => input.key = .eight,
            '9' => input.key = .nine,
            '0' => input.key = .zero,
            else => {},
        };
        input.mod.shift = (buf[0] >= 'A' and buf[0] <= 'Z');
        return input;
    }
};

// deprecated and overkilled previous idea
// const libudev = @cImport(@cInclude("libudev.h"));
// fn findKeyboard() ?[]const u8 {
//     var devnode: [*c]const u8 = undefined;
//     var udev: *libudev.udev = undefined;
//     var enumerate: *libudev.udev_enumerate = undefined;
//     var devices: *libudev.udev_list_entry = undefined;
//     var dev: *libudev.udev_device = undefined;
//
//     if (libudev.udev_new()) |ud| udev = ud;
//     if (libudev.udev_enumerate_new(udev)) |en| enumerate = en;
//     _ = libudev.udev_enumerate_add_match_property(enumerate, "ID_INPUT_KEYBOARD", "1");
//     _ = libudev.udev_enumerate_scan_devices(enumerate);
//     if (libudev.udev_enumerate_get_list_entry(enumerate)) |devi| devices = devi;
//
//     var entry: ?*libudev.udev_list_entry = devices;
//     while (entry != null) {
//         var path: [*c]const u8 = undefined;
//         path = libudev.udev_list_entry_get_name(entry);
//         if (libudev.udev_device_new_from_syspath(udev, path)) |de| dev = de;
//         devnode = libudev.udev_device_get_devnode(dev);
//         if (devnode != null) {
//             break;
//         }
//         _ = libudev.udev_device_unref(dev);
//         entry = libudev.udev_list_entry_get_next(entry);
//     }
//
//     _ = libudev.udev_enumerate_unref(enumerate);
//     _ = libudev.udev_unref(udev);
//
//     if (devnode == null) return null;
//     return std.mem.span(devnode);
// }
