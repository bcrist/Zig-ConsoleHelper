const std = @import("std");
const console = @import("console.zig");

pub fn main() !void {
    try console.init();
    defer console.deinit();

    var out = std.io.getStdOut().writer();

    try console.printContext(
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
        \\    var out = std.io.getStdOut().writer();
        \\
        \\    try console.outStyle(console.Style{  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        \\        .fg = .red,
        \\    });
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
                .style = (console.Style{ .fg = .green }).withFlag(.underline),
                .note_style = .{ .fg = .green },
            },
            .{ .offset = 52, .len = 13 },
            .{ .offset = 200, .len = 170, .note = "Spans can cross lines", .context_lines_above = 1, .context_lines_below = 1 },
        }, out, 150, .{ .filename = "tests.zig" }
    );

}