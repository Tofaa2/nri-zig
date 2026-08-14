const std = @import("std");
const nri = @import("nri");

pub fn main() !void {
    var adapters: [16]nri.c.NriAdapterDesc = undefined;
    const count = nri.enumerateAdapters(&adapters);
    if (count == 0) {
        std.log.err("no NRI adapters found", .{});
        std.process.exit(1);
    }

    std.debug.print("NRI adapters ({d}):\n", .{count});
    for (adapters[0..count]) |adapter| {
        const name = std.mem.span(@as([*:0]const u8, @ptrCast(&adapter.name)));
        std.debug.print("  {s}\n", .{name});
    }
}