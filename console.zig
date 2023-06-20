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
    const out = std.io.getStdOut();
    if (std.os.isatty(out.handle)) {
        (Style{}).apply(out) catch {};
    }
    const err = std.io.getStdOut();
    if (std.os.isatty(err.handle)) {
        (Style{}).apply(err) catch {};
    }
    if (builtin.os.tag == .windows) {
        _ = SetConsoleOutputCP(original_output_codepage);
        _ = SetConsoleMode(out.handle, original_stdout_mode);
        _ = SetConsoleMode(err.handle, original_stderr_mode);
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
        bold, italic, underline, reverse, hidden, strikethrough,
        // Support for these attributes is less common:
        dimmed, blinking, overline,
    };

    pub fn withFlag(self: Style, flag: Flag) Style {
        var s = self;
        s.flags.insert(flag);
        return s;
    }

    pub fn withFlags(self: Style, flags: []const Flag) Style {
        var s = self;
        for (flags) |flag| {
            s.flags.insert(flag);
        }
        return s;
    }

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
        if (self.flags.contains(.strikethrough)) try sw.writeAll(";9");
        if (self.flags.contains(.overline)) try sw.writeAll(";53");
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

// Note when using this function, the style must *only* be changed using this function.
pub fn errStyle(style: Style) !void {
    if (std.meta.eql(style, current_stderr_style)) return;
    try style.apply(std.io.getStdErr());
    current_stderr_style = style;
}

// Note when using this function, the style must *only* be changed using this function.
pub fn outStyle(style: Style) !void {
    if (std.meta.eql(style, current_stdout_style)) return;
    try style.apply(std.io.getStdOut());
    current_stdout_style = style;
}


pub const SourceSpan = struct {
    offset: usize,
    len: usize,
    style: Style = .{ .fg = .red },
    context_lines_above: u8 = 3,
    context_lines_below: u8 = 2,
    note: ?[]const u8 = null,
    note_style: Style = .{ .fg = .red },
};

pub const PrintContextOptions = struct {
    filename: ?[]const u8 = null,
    starting_line_number: usize = 1,
    min_omitted_lines: u8 = 3,
    enable_styling: bool = true,
    source_style: Style = .{},
    line_number_style: ?Style = .{ .fg = .bright_black },
};

 pub fn printContext(source: []const u8, spans: []const SourceSpan, print_writer: anytype, comptime max_source_line_width: usize, options: PrintContextOptions) !void {

    var min_offset: usize = source.len;
    var max_offset: usize = 0;

    for (spans) |span| {
        const first = span.offset;
        const last = first + span.len - 1;
        if (first < min_offset) min_offset = first;
        if (last > max_offset) max_offset = last;
    }

    var first_line = options.starting_line_number;
    var first_line_offset: usize = 0;
    while (true) {
        var maybe_range: ?LineRange = null;

        var line_iter = LineIterator{
            .source = source,
            .offset = first_line_offset,
            .line_number = first_line,
        };
        while (line_iter.next()) |line| {
            if (line.end < min_offset) continue;
            if (line.begin > max_offset) break;

            for (spans) |span| {
                if (!line.contains(span)) continue;

                maybe_range = LineRange.init(span, line.num, maybe_range, options);
            }
        }

        if (maybe_range) |range| {
            if (first_line_offset != 0) {
                try print_writer.writeByte('\n');
            }

            const line_number_width = std.math.log10_int(range.last) + 1;

            var next_line: ?Line = null;

            line_iter = LineIterator{
                .source = source,
                .offset = first_line_offset,
                .line_number = first_line,
            };
            while (line_iter.next()) |line| {
                if (line.num < range.first) continue;
                if (line.num > range.last) {
                    next_line = line;
                    break;
                }

                var line_style_buf: [max_source_line_width]Style = .{ options.source_style } ** max_source_line_width;

                for (spans) |span| {
                    if (!line.contains(span)) continue;

                    const span_end = span.offset + span.len;
                    const span_line_begin = if (span.offset <= line.begin) 0 else span.offset - line.begin;
                    var span_line_end = if (span_end >= line.end) line.end - line.begin else span_end - line.begin;

                    if (span_line_end > line_style_buf.len) {
                        span_line_end = line_style_buf.len;
                    }

                    @memset(line_style_buf[span_line_begin..span_line_end], span.style);
                }

                try printSourceLine(source, line, line_number_width, &line_style_buf, print_writer, options);
            }

            span_loop: for (spans) |span| {
                if (span.offset < first_line_offset) continue :span_loop;
                if (span.note) |_| {
                    var line_number = first_line;
                    var start_of_line = first_line_offset;
                    for (source[first_line_offset..span.offset], first_line_offset..) |ch, offset| {
                        if (ch == '\n') {
                            line_number += 1;
                            start_of_line = offset + 1;
                            if (line_number > range.last) continue :span_loop;
                        }
                    }

                    try printNote(line_number, line_number_width, start_of_line, span, print_writer, options);
                }
            }

            if (next_line) |line| {
                first_line = line.num;
                first_line_offset = line.begin;
            } else {
                return;
            }
        } else return;
    }
}

pub fn printNote(line_number: usize, line_number_width: u8, start_of_line: usize, span: SourceSpan, writer: anytype, options: PrintContextOptions) !void {
    if (options.enable_styling) {
        try span.note_style.apply(writer);
    }
    var line_number_buf: [16]u8 = undefined;
    const line_number_text = std.fmt.bufPrintIntToSlice(&line_number_buf, line_number, 10, .upper, .{});

    const column_number = 1 + span.offset - start_of_line;

    const note = span.note.?;
    var iter = LineIterator{
        .source = note,
        .offset = 0,
        .line_number = 1,
    };
    while (iter.next()) |line| {
        if (line.num == 1) {
            if (line_number_text.len < line_number_width) {
                try writer.writeByteNTimes(' ', line_number_width - line_number_text.len);
            }

            if (options.filename) |filename| {
                try writer.writeAll(filename);
                try writer.writeByte(':');
            }
            try writer.print("{s}:{:<3}  {s}\n", .{ line_number_text, column_number, note[line.begin..line.end] });
        } else {
            if (options.filename) |filename| {
                try writer.writeByteNTimes(' ', filename.len + 1);
            }
            try writer.writeByteNTimes(' ', line_number_width + 6);
            try writer.writeAll(note[line.begin..line.end]);
            try writer.writeByte('\n');
        }
    }
}

pub fn printSourceLine(source: []const u8, line: Line, line_number_width: u8, line_style_buf: []const Style, writer: anytype, options: PrintContextOptions) !void {
    if (options.line_number_style) |style| {
        var line_number_buf: [16]u8 = undefined;
        const line_number = std.fmt.bufPrintIntToSlice(&line_number_buf, line.num, 10, .upper, .{ .width = line_number_width });
        if (options.enable_styling) {
            try style.apply(writer);
        }
        try writer.writeAll(line_number);
        try writer.writeAll(" |");
    }

    const text = source[line.begin..line.end];
    const styles = if (line_style_buf.len > text.len) line_style_buf[0..text.len] else line_style_buf;

    if (options.enable_styling) {
        var begin: usize = 0;
        style_span: while (begin < styles.len) {
            const style = styles[begin];
            try style.apply(writer);

            var i: usize = begin + 1;
            while (i < styles.len) : (i += 1) {
                if (!std.meta.eql(styles[i], style)) {
                    try writer.writeAll(text[begin..i]);
                    begin = i;
                    continue :style_span;
                }
            } else {
                try writer.writeAll(text[begin..styles.len]);
                begin = styles.len;
            }
        }
    } else {
        try writer.writeAll(text[0..styles.len]);
    }

    if (text.len > line_style_buf.len) {
        if (options.enable_styling) {
            if (options.line_number_style) |style| {
                try style.apply(writer);
            } else {
                try options.source_style.apply(writer);
            }
        }
        try writer.writeAll("...");
    }

    try writer.writeByte('\n');
}

const LineRange = struct {
    first: usize,
    last: usize,

    pub fn init(span: SourceSpan, line_number: usize, maybe_merge_range: ?LineRange, options: PrintContextOptions) LineRange {
        var range = LineRange{
            .first = options.starting_line_number,
            .last = line_number + span.context_lines_below,
        };

        if (options.starting_line_number + span.context_lines_above < line_number) {
            range.first = line_number - span.context_lines_above;
        }

        if (maybe_merge_range) |other| {
            const merge_limit = other.last + options.min_omitted_lines;
            if (range.first < merge_limit) {
                range.first = other.first;
            } else {
                return other;
            }
        }

        return range;
    }
};

const Line = struct {
    begin: usize,
    end: usize,
    num: usize,

    pub fn contains(self: Line, span: SourceSpan) bool {
        if (span.offset >= self.end) return false;
        const span_end = span.offset + span.len;
        if (span_end <= self.begin) return false;
        return true;
    }
};

const LineIterator = struct {
    source: []const u8,
    offset: ?usize,
    line_number: usize,

    pub fn next(self: *LineIterator) ?Line {
        var line = Line{
            .begin = self.offset orelse return null,
            .end = undefined,
            .num = self.line_number,
        };

        self.line_number = line.num + 1;

        if (std.mem.indexOfScalarPos(u8, self.source, line.begin, '\n')) |lf_offset| {
            line.end = lf_offset;
            self.offset = lf_offset + 1;
            if (lf_offset > line.begin and self.source[lf_offset - 1] == '\r') {
                line.end -= 1;
            }
        } else {
            self.offset = null;
            line.end = self.source.len;
        }

        return line;
    }
};
