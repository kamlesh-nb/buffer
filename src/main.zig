const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

const Buffer = @This();

pub const Error = error{
    OutOfMemory,
    InvalidRange,
};

data: ?[]u8,
allocator: Allocator,
size: usize = 0,

pub fn init(allocator: Allocator) !Buffer {
    return Buffer{
        .data = null,
        .allocator = allocator,
    };
}

fn allocate(self: *Buffer, bytes: usize) Error!void {
    if (self.data) |buffer| {
        if (bytes < self.size) self.size = bytes;
        self.data = self.allocator.realloc(buffer, bytes) catch {
            return Error.OutOfMemory;
        };
    } else {
        self.data = self.allocator.alloc(u8, bytes) catch {
            return Error.OutOfMemory;
        };
    }
}

pub fn write(this: *Buffer, comptime fmt: []const u8, args: anytype) !usize {
    var buf: [1024]u8 = undefined;
    const bytes = try std.fmt.bufPrint(&buf, fmt, args);

    if (this.data) |buffer| {
        if (this.size + bytes.len > buffer.len) {
            try this.allocate((this.size + bytes.len) * 2);
        }
    } else {
        try this.allocate((bytes.len) * 2);
    }

    const buffer = this.data.?;
    var i: usize = 0;
    while (i < bytes.len) : (i += 1) {
        buffer[this.size + i] = bytes[i];
    }

    this.size += bytes.len;
    return bytes.len;
}

pub fn getWritten(this: *Buffer) ![]u8 {
    return this.data.?[0..this.size];
}

pub fn deinit(this: *Buffer) void {
    if (this.data) |data| {
        this.allocator.free(data);
    }
}

test "buffer" {
    var buffer = try Buffer.init(std.testing.allocator);
    defer buffer.deinit();

    _ = try buffer.write("\nhello {s}!\n", .{"world"});
    _ = try buffer.write("namaste {s}!\n", .{"india"});
    _ = try buffer.write("namaskar {s}!\n", .{"pune"});

    std.debug.print("buffer: {s}\n", .{try buffer.getWritten()});
}
