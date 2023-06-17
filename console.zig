const std = @import("std");
const builtin = @import("builtin");

const win = std.os.windows;
extern "kernel32" fn SetConsoleMode(in_hConsoleHandle: win.HANDLE, in_dwMode: win.DWORD) callconv(win.WINAPI) win.BOOL;
const ENABLE_VIRTUAL_TERMINAL_PROCESSING : win.DWORD = 0x0004;
extern "kernel32" fn SetConsoleOutputCP(in_wCodePageID: win.UINT) callconv(win.WINAPI) win.BOOL;
const CP_UTF8: win.UINT = 65001;

var original_output_codepage: win.UINT = 0;
var original_stdout_mode: win.DWORD = 0;
var original_stderr_mode: win.DWORD = 0;

fn initWindowsOutputCodepage() !void {
    original_output_codepage = win.kernel32.GetConsoleOutputCP();
    if (SetConsoleOutputCP(CP_UTF8) == 0) {
        switch (win.kernel32.GetLastError()) {
            else => |err| return win.unexpectedError(err),
        }
    }
}

fn initWindowsConsole(handle: win.HANDLE, backup: *win.DWORD) !void {
    var mode: win.DWORD = undefined;
    if (win.kernel32.GetConsoleMode(handle, &mode) == 0) {
        switch (win.kernel32.GetLastError()) {
            else => |err| return win.unexpectedError(err),
        }
    }
    backup.* = mode;
    mode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    if (SetConsoleMode(handle, mode) == 0) {
        switch (win.kernel32.GetLastError()) {
            else => |err| return win.unexpectedError(err),
        }
    }
}

pub fn init() !void {
    if (builtin.os.tag == .windows) {
        try initWindowsOutputCodepage();
        try initWindowsConsole(std.io.getStdOut().handle, &original_stdout_mode);
        try initWindowsConsole(std.io.getStdErr().handle, &original_stderr_mode);
    }
}

pub fn deinit() void {
    if (builtin.os.tag == .windows) {
        outStyle(.{}) catch {};
        errStyle(.{}) catch {};
        _ = SetConsoleOutputCP(original_output_codepage);
        _ = SetConsoleMode(std.io.getStdOut().handle, original_stdout_mode);
        _ = SetConsoleMode(std.io.getStdErr().handle, original_stderr_mode);
    }
}

pub const Style = struct {
    fg: Color = .default,
    bg: Color = .default,
    flags: FlagSet = .{},

    pub const Color = enum(u8) {
        black = 0,
        red = 1,
        green = 2,
        yellow = 3,
        blue = 4,
        magenta = 5,
        cyan = 6,
        white = 7,
        bright_black = 8,
        bright_red = 9,
        bright_green = 10,
        bright_yellow = 11,
        bright_blue = 12,
        bright_magenta = 13,
        bright_cyan = 14,
        bright_white = 15,
        default,
    };

    pub const FlagSet = std.EnumSet(Flag);
    pub const Flag = enum {
        bold, dimmed, italic, underline, blinking, reverse, hidden, overline, strikethrough
    };

    pub fn apply(self: Style, writer: anytype) !void {
        var buf: [32]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buf);
        var sw = stream.writer();
        try sw.writeAll("\x1B[0");
        if (self.flags.contains(.bold)) try sw.writeAll(";1");
        if (self.flags.contains(.dimmed)) try sw.writeAll(";2");
        if (self.flags.contains(.italic)) try sw.writeAll(";3");
        if (self.flags.contains(.underline)) try sw.writeAll(";4");
        if (self.flags.contains(.blinking)) try sw.writeAll(";5");
        if (self.flags.contains(.reverse)) try sw.writeAll(";7");
        if (self.flags.contains(.hidden)) try sw.writeAll(";8");
        if (self.flags.contains(.overline)) try sw.writeAll(";53");
        if (self.flags.contains(.strikethrough)) try sw.writeAll(";9");
        switch (self.fg) {
            .black => try sw.writeAll(";30"),
            .red => try sw.writeAll(";31"),
            .green => try sw.writeAll(";32"),
            .yellow => try sw.writeAll(";33"),
            .blue => try sw.writeAll(";34"),
            .magenta => try sw.writeAll(";35"),
            .cyan => try sw.writeAll(";36"),
            .white => try sw.writeAll(";37"),
            .bright_black => try sw.writeAll(";90"),
            .bright_red => try sw.writeAll(";91"),
            .bright_green => try sw.writeAll(";92"),
            .bright_yellow => try sw.writeAll(";93"),
            .bright_blue => try sw.writeAll(";94"),
            .bright_magenta => try sw.writeAll(";95"),
            .bright_cyan => try sw.writeAll(";96"),
            .bright_white => try sw.writeAll(";97"),
            .default => {},
        }
        switch (self.bg) {
            .black => try sw.writeAll(";40"),
            .red => try sw.writeAll(";41"),
            .green => try sw.writeAll(";42"),
            .yellow => try sw.writeAll(";43"),
            .blue => try sw.writeAll(";44"),
            .magenta => try sw.writeAll(";45"),
            .cyan => try sw.writeAll(";46"),
            .white => try sw.writeAll(";47"),
            .bright_black => try sw.writeAll(";100"),
            .bright_red => try sw.writeAll(";101"),
            .bright_green => try sw.writeAll(";102"),
            .bright_yellow => try sw.writeAll(";103"),
            .bright_blue => try sw.writeAll(";104"),
            .bright_magenta => try sw.writeAll(";105"),
            .bright_cyan => try sw.writeAll(";106"),
            .bright_white => try sw.writeAll(";107"),
            .default => {},
        }
        try sw.writeAll("m");

        try writer.writeAll(stream.getWritten());
    }
};

var current_stderr_style : Style = .{};
var current_stdout_style : Style = .{};

pub fn errStyle(style: Style) !void {
    if (std.meta.eql(style, current_stderr_style)) return;
    try style.apply(std.io.getStdErr());
    current_stderr_style = style;
}

pub fn outStyle(style: Style) !void {
    if (std.meta.eql(style, current_stdout_style)) return;
    try style.apply(std.io.getStdOut());
    current_stdout_style = style;
}
