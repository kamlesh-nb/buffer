const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

const Buffer = @This();

pub const BufferError = error{
    OutOfMemory,
    InvalidRange,
};

pub const Reader = std.io.Reader(*@This(), BufferError, read);
pub const Writer = std.io.Writer(*@This(), BufferError, write);

data: ?[]u8,
allocator: Allocator,
size: usize = 0,

pub fn init(allocator: Allocator) Buffer {
    return .{
        .data = null,
        .allocator = allocator,
    };
}

pub fn reader(self: *Buffer) Reader {
    return .{ .context = self };
}

pub fn writer(self: *Buffer) Writer {
    return .{ .context = self };
}

fn allocate(self: *Buffer, bytes: usize) BufferError!void {
    if (self.data) |buffer| {
        if (bytes < self.size) self.size = bytes;
        self.data = self.allocator.realloc(buffer, bytes) catch {
            return BufferError.OutOfMemory;
        };
    } else {
        self.data = self.allocator.alloc(u8, bytes) catch {
            return BufferError.OutOfMemory;
        };
    }
}

pub fn write(this: *Buffer, bytes: []const u8) !usize {
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

pub fn read(self: *Buffer, buf: []u8) !usize {
    if (self.data) |buffer| {
        @memcpy(buf[0..self.size], buffer[0..self.size]);
    }
    return self.size;
}

pub fn str(self: *Buffer) []u8 {
    if (self.data) |buffer| {
        return buffer[0..self.size];
    }
    return "";
}

pub fn deinit(this: *Buffer) void {
    if (this.data) |data| {
        this.allocator.free(data);
    }
}

test "json" {
    var buffer =  Buffer.init(std.testing.allocator);
    defer buffer.deinit();

    const p = .{ .name = "hello", .age = 10 };

    try std.json.stringify(p, .{}, buffer.writer());
    std.debug.print("buffer: \n{s}\n", .{buffer.str()});
}

test "buffer" {
    var buffer =  Buffer.init(std.testing.allocator);
    defer buffer.deinit();

    _ = try buffer.writer().print("\nhello {s}!\n", .{"world"});
    _ = try buffer.writer().print("namaste {s},\n{s}!\n", .{ "india", "pune" });
    _ = try buffer.writer().print("namaskar {s}!\n", .{"pune"});

    _ = try buffer.writer().print("hello {s} once {s}", .{ "world", "again" });
    var buff: [32756]u8 = undefined;

    const l = try buffer.reader().readAtLeast(&buff, buffer.size);
    _ = l;
    std.debug.print("buffer: {s}\n", .{buffer.str()});
}
