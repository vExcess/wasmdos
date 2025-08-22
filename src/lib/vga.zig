const std = @import("std");
const WasmAllocator = @import("../WasmAllocator.zig").WasmAllocator;

extern fn vga_setAddress(display: u32, addr: u32) void;

pub const COLOR = struct {
    pub const black = 0;
    pub const blue = 1;
    pub const green = 2;
    pub const cyan = 3;
    pub const red = 4;
    pub const magenta = 5;
    pub const brown = 6;
    pub const lightGray = 7;
    pub const darkGray = 8;
    pub const lightBlue = 9;
    pub const lightGreen= 10;
    pub const lightCyan= 11;
    pub const lightRed= 12;
    pub const lightMagenta= 13;
    pub const yellow= 14;
    pub const white= 15;
};

pub const DisplayDriver = struct {
    TUIBuffer: [*]u8 = undefined,

    pub fn allocTUI(allocator: *WasmAllocator, display: u32) !DisplayDriver {
        const width = 80;
        const height = 25;
        const bytesPerChar = 2;
        const addr = (try allocator.alloc(u8, width * height * bytesPerChar)).ptr;

        vga_setAddress(display, @intFromPtr(addr));
        
        return DisplayDriver{
            .TUIBuffer = addr
        };
    }

    pub fn writeChar(self: *DisplayDriver, c: u8, x: usize, y: usize, forecolour: usize, backcolour: usize) void {
        const attrib = (backcolour << 4) | (forecolour & 0x0F);
        const idx = (x + y*80) << 1;
        self.TUIBuffer[idx] = @as(u8, @truncate(attrib));
        self.TUIBuffer[idx + 1] = c;
    }

    pub fn writeLine(self: *DisplayDriver, txt: []u8, x: usize, y: usize, forecolour: usize, backcolour: usize) void {
        var i: usize = 0; while (i < txt.len) : (i += 1) {
            self.writeChar(txt[i], x+i, y, forecolour, backcolour);
        }
    }
};
