const std = @import("std");
const console = @import("console.zig");

pub fn main() !void {
    try console.init();
    defer console.deinit();

    var out = std.io.getStdOut().writer();

    try console.outStyle(console.Style{
        .fg = .red,
    });

    try out.writeAll("Hellorld");

}