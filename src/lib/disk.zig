const std = @import("std");

const Disk = struct {
    inMemBuff: []u8 = {},

    pub fn createRAMDisk(allocator: std.mem.Allocator, size: usize) Disk {
        const buffer = allocator.alloc(u8, size) catch @panic("");
        return Disk{
            .inMemBuff = buffer,
        };
    }

    pub fn write8(self: *Disk, addr: usize, val: u8) void {
        // use little endian
        self.inMemBuff[addr] = val;
    }
    pub fn read8(self: *Disk, addr: usize) u8 {
        // use little endian
        return self.inMemBuff[addr];
    }

    pub fn write16(self: *Disk, addr: usize, val: u16) void {
        // use little endian
        self.inMemBuff[addr] = @as(u8, @intCast(val & 255));
        self.inMemBuff[addr+1] = @as(u8, @intCast(val >> 8));
    }
    pub fn read16(self: *Disk, addr: usize) u16 {
        // use little endian
        const a = @as(u16, @intCast(self.inMemBuff[addr]));
        const b = @as(u16, @intCast(self.inMemBuff[addr + 1]));
        return b << 8 | a;
    }

    pub fn write32(self: *Disk, addr: usize, val: u32) void {
        // use little endian
        self.inMemBuff[addr] = @as(u8, @intCast(val & 255));
        self.inMemBuff[addr+1] = @as(u8, @intCast((val >> 8) & 255));
        self.inMemBuff[addr+2] = @as(u8, @intCast((val >> 16) & 255));
        self.inMemBuff[addr+3] = @as(u8, @intCast(val >> 24));
    }
    pub fn read32(self: *Disk, addr: usize) u32 {
        // use little endian
        const a = @as(u32, @intCast(self.inMemBuff[addr]));
        const b = @as(u32, @intCast(self.inMemBuff[addr + 1]));
        const c = @as(u32, @intCast(self.inMemBuff[addr + 2]));
        const d = @as(u32, @intCast(self.inMemBuff[addr + 3]));
        return d << 24 | c << 16 | b << 8 | a;
    }

    pub fn write64(self: *Disk, addr: usize, val: u64) void {
        // use little endian
        self.inMemBuff[addr  ] = @as(u8, @intCast( val        & 255));
        self.inMemBuff[addr+1] = @as(u8, @intCast((val >>  8) & 255));
        self.inMemBuff[addr+2] = @as(u8, @intCast((val >> 16) & 255));
        self.inMemBuff[addr+3] = @as(u8, @intCast((val >> 24) & 255));
        self.inMemBuff[addr+4] = @as(u8, @intCast((val >> 32) & 255));
        self.inMemBuff[addr+5] = @as(u8, @intCast((val >> 40) & 255));
        self.inMemBuff[addr+6] = @as(u8, @intCast((val >> 48) & 255));
        self.inMemBuff[addr+7] = @as(u8, @intCast((val >> 56) & 255));
    }
    pub fn read64(self: *Disk, addr: usize) u64 {
        // use little endian
        const a = @as(u64, @intCast(self.inMemBuff[addr]));
        const b = @as(u64, @intCast(self.inMemBuff[addr + 1]));
        const c = @as(u64, @intCast(self.inMemBuff[addr + 2]));
        const d = @as(u64, @intCast(self.inMemBuff[addr + 3]));
        const e = @as(u64, @intCast(self.inMemBuff[addr + 4]));
        const f = @as(u64, @intCast(self.inMemBuff[addr + 5]));
        const g = @as(u64, @intCast(self.inMemBuff[addr + 6]));
        const h = @as(u64, @intCast(self.inMemBuff[addr + 7]));
        return h << 56 | g << 48 | f << 40 | e << 32 | d << 24 | c << 16 | b << 8 | a;
    }

    pub fn read(self: *Disk, addr: usize, len: usize, dest: []u8) void {
        var i: usize = 0;
        while (i < len) : (i += 1) {
            dest[i] = self.inMemBuff[addr + i];
        }
    }

    pub fn write(self: *Disk, addr: usize, len: usize, src: []u8) void {
        var i: usize = 0;
        while (i < len) : (i += 1) {
            self.inMemBuff[addr + i] = src[i];
        }
    }
};
