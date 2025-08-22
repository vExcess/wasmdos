// https://www.youtube.com/watch?v=qLrTcmyj7Ic
// https://en.wikipedia.org/wiki/Master_boot_record

const std = @import("std");

const Disk = @import("./disk.zig").Disk;

const partitionsOffset = 446;

pub const MBRPartition = struct {
    bootable: bool,
    fileSystemId: u8,
    startSector: u32,
    sectorCount: u32,
};

pub const MBR = struct {
    disk: Disk,
    partitions: [4]?MBRPartition,
    diskSignature: u32,
    bootSignature: u16,

    pub fn init(_disk: Disk) MBR {
        var mbr = MBR{
            .disk = _disk
        };
        mbr.diskSignature = mbr.disk.read32(440);
        mbr.bootSignature = mbr.disk.read16(510);

        var p: usize = 0;
        while (p < 4) : (p += 1) {
            const fileSystemId = mbr.disk.read8(partitionsOffset + p*16 + 4);
            if (fileSystemId == 0) {
                mbr.partitions[p] = null;
            } else {
                const bootable = mbr.disk.read8(partitionsOffset + p*16) >= 128;
                const startSector = mbr.disk.read32(partitionsOffset + p*16 + 8);
                const sectorCount = mbr.disk.read32(partitionsOffset + p*16 + 12);
                mbr.partitions[p] = MBRPartition{
                    .bootable = bootable,
                    .fileSystemId = fileSystemId,
                    .startSector = startSector,
                    .sectorCount = sectorCount
                };
            }
        }

        return mbr;
    }

    pub fn setBootCode(self: *MBR, code: []u8) void {
        self.disk.write(0, @min(446, code.len), code);
    }

    pub fn bootCode(self: *MBR, allocator: std.mem.Allocator) [446]u8 {
        const buffer = allocator.alloc(u8, 446) catch @panic("");
        self.disk.read(0, 446, buffer);
        return buffer;
    }

    pub fn setPartition(self: *MBR, idx: usize, partition: MBRPartition) void {
        self.partitions[idx] = partition;
        self.disk.write8(partitionsOffset + idx*16, if (partition.bootable) 128 else 0);
        self.disk.write8(partitionsOffset + idx*16 + 4, partition.fileSystemId);
        self.disk.write32(partitionsOffset + idx*16 + 8, partition.startSector);
        self.disk.write32(partitionsOffset + idx*16 + 12, partition.sectorCount);
    }

    pub fn setDiskSignature(self: *MBR, val: u32) u16 {
        self.diskSignature = val;
        self.disk.write32(440, val);
    }

    pub fn setBootSignature(self: *MBR, val: u16) u16 {
        self.bootSignature = val;
        self.disk.read16(510, val);
    }
};
