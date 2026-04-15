const std = @import("std");
const console = @import("console.zig");

pub fn main(init: std.process.Init) !void {
    try console.init(init.io);
    defer console.deinit(init.io);

    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(init.io, &buf);

    try console.print_context(
        \\const std = @import("std");
        \\const console = @import("console.zig");
        \\
        \\pub fn main() !void {
        \\    try console.init();
        \\    defer console.deinit();
        \\  asdf
        \\  slkgaslgj
        \\
        \\
        \\
        \\
        \\
        \\    var out = std.Io.getStdOut().writer();
        \\
        \\    try console.outStyle(console.Style{  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        \\        .fg = .red,
        \\    });
        \\    var whatever = "∫";
        \\}
        \\
        \\asdf
        \\asdf
        \\asdf
        \\asdf
        \\
        , &.{
            .{ .offset = 6, .len = 3, .note = "Notes can have \nmultiple lines" },
            .{ .offset = 13, .len = 6, .note = "I am another note",
                .style = (console.Style{ .fg = .green }).with_flag(.underline),
                .note_style = .{ .fg = .green },
            },
            .{ .offset = 52, .len = 13 },
            .{
                .offset = 200,
                .len = 170,
                .note = "Spans can cross lines",
                .context_lines_above = 1,
                .context_lines_below = 3,
                .style = (console.Style{ .bg = .red }).with_flag(.dimmed),
            },
        }, &w.interface, 150, .{ .filename = "tests.zig" }
    );
    try w.interface.flush();
}