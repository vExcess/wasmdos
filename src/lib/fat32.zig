// My FAT implementation only supports FAT32 and not FAT16 or FAT12
// Specifically I only support FAT32 (LBA) (0x0e) and not FAT32 (0x0b) or FAT 32 (LBA) (0x0e)
// Note that other operating systems may not use FAT32 if the disk size is under 1GB

const std = @import("std");

// implementation based off https://www.cs.fsu.edu/~cop4610t/assignments/project3/spec/fatspec.pdf
pub const Fat32Drive = struct {
    buff: []u8,
    capacity: usize,

    pub fn new(allocator: std.mem.Allocator, capacity: usize) Fat32Drive {
        const slc8 = allocator.alloc(u8, capacity) catch unreachable;
        return Fat32Drive {
            .buff = slc8,
            .capacity = capacity,
        };
    }

    pub fn free(self: *Fat32Drive, allocator: std.mem.Allocator) void {
        allocator.free(self.buff);
    }

    // utility methods
    pub fn write8(self: *Fat32Drive, addr: usize, val: u8) void {
        // use little endian
        self.buff[addr] = val;
    }
    pub fn read8(self: *Fat32Drive, addr: usize,) u8 {
        // use little endian
        return self.buff[addr];
    }
    pub fn write16(self: *Fat32Drive, addr: usize, val: u16) void {
        // use little endian
        self.buff[addr] = @as(u8, @intCast(val & 255));
        self.buff[addr+1] = @as(u8, @intCast(val >> 8));
    }
    pub fn read16(self: *Fat32Drive, addr: usize,) u16 {
        // use little endian
        const a = @as(u16, @intCast(self.buff[addr]));
        const b = @as(u16, @intCast(self.buff[addr + 1]));
        return b << 8 | a;
    }
    pub fn write32(self: *Fat32Drive, addr: usize, val: u32) void {
        // use little endian
        self.buff[addr] = @as(u8, @intCast(val & 255));
        self.buff[addr+1] = @as(u8, @intCast((val >> 8) & 255));
        self.buff[addr+2] = @as(u8, @intCast((val >> 16) & 255));
        self.buff[addr+3] = @as(u8, @intCast(val >> 24));
    }
    pub fn read32(self: *Fat32Drive, addr: usize) u32 {
        // use little endian
        const a = @as(u32, @intCast(self.buff[addr]));
        const b = @as(u32, @intCast(self.buff[addr + 1]));
        const c = @as(u32, @intCast(self.buff[addr + 2]));
        const d = @as(u32, @intCast(self.buff[addr + 3]));
        return d << 24 | c << 16 | b << 8 | a;
    }

    pub fn write64(self: *Fat32Drive, addr: usize, val: u64) void {
        // use little endian
        self.buff[addr  ] = @as(u8, @intCast( val        & 255));
        self.buff[addr+1] = @as(u8, @intCast((val >>  8) & 255));
        self.buff[addr+2] = @as(u8, @intCast((val >> 16) & 255));
        self.buff[addr+3] = @as(u8, @intCast((val >> 24) & 255));
        self.buff[addr+4] = @as(u8, @intCast((val >> 32) & 255));
        self.buff[addr+5] = @as(u8, @intCast((val >> 40) & 255));
        self.buff[addr+6] = @as(u8, @intCast((val >> 48) & 255));
        self.buff[addr+7] = @as(u8, @intCast((val >> 56) & 255));
    }
    pub fn read64(self: *Fat32Drive, addr: usize) u64 {
        // use little endian
        const a = @as(u64, @intCast(self.buff[addr]));
        const b = @as(u64, @intCast(self.buff[addr + 1]));
        const c = @as(u64, @intCast(self.buff[addr + 2]));
        const d = @as(u64, @intCast(self.buff[addr + 3]));
        const e = @as(u64, @intCast(self.buff[addr + 4]));
        const f = @as(u64, @intCast(self.buff[addr + 5]));
        const g = @as(u64, @intCast(self.buff[addr + 6]));
        const h = @as(u64, @intCast(self.buff[addr + 7]));
        return h << 56 | g << 48 | f << 40 | e << 32 | d << 24 | c << 16 | b << 8 | a;
    }

    // Jump instruction to boot code
    pub fn setBS_jmpBoot(self: *Fat32Drive, addr: u8) void {
        self.buff[0] = 0xEB;
        self.buff[1] = addr;
        self.buff[2] = 0x90;
    }
    pub fn getBS_jmpBoot(self: *Fat32Drive) u8 {
        return self.buff[1];
    }

    // This should be "MSWIN4.1" for best compatability with other drivers
    pub fn setBS_OEMName(self: *Fat32Drive, name: *const [8:0]u8) void {
        {var i: usize = 0; while (i < 8) : (i += 1) {
            self.buff[3 + i] = name[i];
        }}
    }
    pub fn getBS_OEMName(self: *Fat32Drive) *[8]u8 {
        return self.buff[3..(3 + 8)];
    }

    // Number of bytes per sector
    pub fn setBPB_BytesPerSec(self: *Fat32Drive, sz: u16) void {
        if (sz == 512 or sz == 1024 or sz == 2048 or sz == 4096) {
            self.write16(11, sz);
        } else {
            unreachable;
        }
    }
    pub fn getBPB_BytesPerSec(self: *Fat32Drive) u16 {
        return self.read16(11);
    }

    // Number of sectors per allocation unit
    pub fn setBPB_SecPerClus(self: *Fat32Drive, sz: u8) void {
        if (sz == 1 or sz == 2 or sz == 4 or sz == 8 or sz == 16 or sz == 32 or sz == 64 or sz == 128) {
            self.buff[13] = sz;
        } else {
            unreachable;
        }
    }
    pub fn getBPB_SecPerClus(self: *Fat32Drive) u8 {
        return self.buff[13];
    }

    // Number of reserved sectors in the reserved region of the 
    // volume starting at the first sector of the volume
    // This should typically 32
    pub fn setBPB_RsvdSecCnt(self: *Fat32Drive, sz: u16) void {
        self.write16(14, sz);
    }
    pub fn getBPB_RsvdSecCnt(self: *Fat32Drive) u16 {
        return self.read16(14);
    }

    // The number of FAT data structures on the volume
    // Should be 2 for best compatability
    // Can be 1 to save space at the cost of redundancy
    pub fn setBPB_NumFATs(self: *Fat32Drive, sz: u8) void {
        self.buff[16] = sz;
    }
    pub fn getBPB_NumFATs(self: *Fat32Drive) u8 {
        return self.buff[16];
    }

    // For Fat32 this does nothing, but must be set to 0
    pub fn setBPB_RootEntCnt(self: *Fat32Drive, sz: u16) void {
        if (sz == 0) {
            self.write16(17, 0);
        } else {
            unreachable;
        }
    }
    pub fn getBPB_RootEntCnt(self: *Fat32Drive) u16 {
        return self.read16(17);
    }

    // For Fat32 this does nothing, but must be set to 0
    pub fn setBPB_ToSec16(self: *Fat32Drive, sz: u16) void {
        if (sz == 0) {
            self.write16(19, 0);
        } else {
            unreachable;
        }
    }
    pub fn getBPB_ToSec16(self: *Fat32Drive) u16 {
        return self.read16(19);
    }

    // this value is no longer used but whatever value is put
    // here must also be put in the low byte of the FAT[0] entry
    pub fn setBPB_Media(self: *Fat32Drive, sz: u8) void {
        if (sz == 0xF0 or sz == 0xF8 or sz == 0xF9 or sz == 0xFA or sz == 0xFB or sz == 0xFC or sz == 0xFD or sz == 0xFE or sz == 0xFF) {
            self.buff[21] = sz;
        } else {
            unreachable;
        }
    }
    pub fn getBPB_Media(self: *Fat32Drive) u8 {
        return self.buff[21];
    }

    // For Fat32 this does nothing, but must be set to 0
    pub fn setBPB_FATSz16(self: *Fat32Drive, sz: u16) void {
        if (sz == 0) {
            self.write16(22, 0);
        } else {
            unreachable;
        }
    }
    pub fn getBPB_FATSz16(self: *Fat32Drive) u16 {
        return self.read16(22);
    }

    // idk what this does, probably not important
    pub fn setBPB_SecPerTrk(self: *Fat32Drive, sz: u16) void {
        self.write16(24, sz);
    }
    pub fn getBPB_SecPerTrk(self: *Fat32Drive) u16 {
        return self.read16(24);
    }

    // probably only relevant for floppy disks
    pub fn setBPB_NumHeads(self: *Fat32Drive, sz: u16) void {
        self.write16(26, sz);
    }
    pub fn getBPB_NumHeads(self: *Fat32Drive) u16 {
        return self.read16(26);
    }

    // the number of hidden sectors preceding the FAT volume
    // set to 0 for non-partititoned drives
    // otherwise value is operating system specific
    pub fn setBPB_HiddSec(self: *Fat32Drive, num: u32) void {
        self.write32(28, num);
    }
    pub fn getBPB_HiddSec(self: *Fat32Drive) u32 {
        return self.read32(28);
    }

    // the number of sectors on the volume
    // can't be zero
    pub fn setBPB_TotSec32(self: *Fat32Drive, num: u32) void {
        self.write32(28, num);
    }
    pub fn getBPB_TotSec32(self: *Fat32Drive) u32 {
        return self.read32(28);
    }

    // number of sectors occupied by ONE FAT
    pub fn setBPB_FATSz32(self: *Fat32Drive, num: u32) void {
        self.write32(36, num);
    }
    pub fn getBPB_FATSz32(self: *Fat32Drive) u32 {
        return self.read32(36);
    }

    // Bits 0-3 -- Zero-based number of active FAT. Only valid if mirroring is disabled.
    // Bits 4-6 -- Reserved.
    // Bit 7 -- 0 means the FAT is mirrored at runtime into all FATs.
    // -- 1 means only one FAT is active; it is the one referenced in bits 0-3.
    // Bits 8-15 -- Reserved
    pub fn setBPB_ExtFlags(self: *Fat32Drive, num: u16) void {
        self.write16(40, num);
    }
    pub fn getBPB_ExtFlags(self: *Fat32Drive) u16 {
        return self.read16(40);
    }

    // format version, set to 0
    pub fn setBPB_FSVer(self: *Fat32Drive, num: u16) void {
        self.write16(42, num);
    }
    pub fn getBPB_FSVer(self: *Fat32Drive) u16 {
        return self.read16(42);
    }

    // set to first non-bad cluster, should be 2
    pub fn setBPB_RootClus(self: *Fat32Drive, num: u32) void {
        self.write32(44, num);
    }
    pub fn getBPB_RootClus(self: *Fat32Drive) u32 {
        return self.read32(44);
    }

    // number of FSINFO structure in reserved area of volume, usually is 1
    pub fn setBPB_FSInfo(self: *Fat32Drive, num: u16) void {
        self.write16(48, num);
    }
    pub fn getBPB_FSInfo(self: *Fat32Drive) u16 {
        return self.read16(48);
    }

    // sector number in reserved area of volume of a copy of the boot record
    // should be 6
    pub fn setBPB_BkBootSec(self: *Fat32Drive, num: u16) void {
        self.write16(50, num);
    }
    pub fn getBPB_BkBootSec(self: *Fat32Drive) u16 {
        return self.read16(50);
    }

    // reserved, should be zeroed out
    pub fn setBPB_Reserved(self: *Fat32Drive, num: u16) void {
        _=num;
        var i: usize = 52;
        while (i < 52 + 12) : (i += 1) {
            self.buff[i] = 0;
        }
    }
    pub fn getBPB_Reserved(self: *Fat32Drive) u16 {
        _=self;
        return 0;
    }

    // drive number, set to 0x00 for floppy disks and 0x80 for HDDs
    pub fn setBPB_DrvNum(self: *Fat32Drive, num: u8) void {
        self.write8(64, num);
    }
    pub fn getBPB_DrvNum(self: *Fat32Drive) u8 {
        return self.read8(64);
    }

    // reserved, set to 0
    pub fn setBPB_Reserved1(self: *Fat32Drive, num: u8) void {
        self.write8(65, num);
    }
    pub fn getBPB_Reserved1(self: *Fat32Drive) u8 {
        return self.read8(65);
    }

    // extended boot signature
    // indicates that the following 3 fields in boot sector are present
    pub fn setBPB_BootSig(self: *Fat32Drive, num: u8) void {
        self.write8(66, num);
    }
    pub fn getBPB_BootSig(self: *Fat32Drive) u8 {
        return self.read8(66);
    }

    // volume serial number
    // generated by combining date and time into 32 bit val
    pub fn setBPB_VolID(self: *Fat32Drive, num: u32) void {
        self.write32(67, num);
    }
    pub fn getBPB_VolID(self: *Fat32Drive) u32 {
        return self.read32(67);
    }

    // volume label
    pub fn setBS_VolLab(self: *Fat32Drive, name: *const [11:0]u8) void {
        {var i: usize = 0; while (i < 11) : (i += 1) {
            self.buff[71 + i] = name[i];
        }}
    }
    pub fn getBS_VolLab(self: *Fat32Drive) *[11]u8 {
        return self.buff[71..(71 + 11)];
    }
    
    // should always be set to "FAT F32 "
    pub fn setBS_FilSysType(self: *Fat32Drive, name: *const [8:0]u8) void {
        {var i: usize = 0; while (i < 8) : (i += 1) {
            self.buff[82 + i] = name[i];
        }}
    }
    pub fn getBS_FilSysType(self: *Fat32Drive) *[8]u8 {
        return self.buff[82..(82 + 8)];
    }
};

// test

// var myDrive = Fat32Drive.new(allocator, 1000 * 1000);
// defer myDrive.free(allocator);

// myDrive.setBS_jmpBoot(150);
// print("BS_jmpBoot: ");
// println(myDrive.getBS_jmpBoot());

// myDrive.setBS_OEMName("MSWIN4.1");
// print("BS_OEMName: ");
// println(myDrive.getBS_OEMName());

// myDrive.setBPB_BytesPerSec(512);
// print("BPB_BytesPerSec: ");
// println(myDrive.getBPB_BytesPerSec());

// myDrive.setBPB_SecPerClus(64);
// print("BPB_SecPerClus: ");
// println(myDrive.getBPB_SecPerClus());

// myDrive.setBPB_RsvdSecCnt(32);
// print("BPB_RsvdSecCnt: ");
// println(myDrive.getBPB_RsvdSecCnt());

// myDrive.setBPB_NumFATs(2);
// print("BPB_NumFATs: ");
// println(myDrive.getBPB_NumFATs());

// myDrive.setBPB_RootEntCnt(0);
// print("BPB_RootEntCnt: ");
// println(myDrive.getBPB_RootEntCnt());

// myDrive.setBPB_ToSec16(0);
// print("BPB_ToSec16: ");
// println(myDrive.getBPB_ToSec16());

// myDrive.setBPB_Media(0xF8);
// print("BPB_Media: ");
// println(myDrive.getBPB_Media());

// myDrive.setBPB_FATSz16(0);
// print("BPB_FATSz16: ");
// println(myDrive.getBPB_FATSz16());

// myDrive.setBPB_HiddSec(0);
// print("BPB_HiddSec: ");
// println(myDrive.getBPB_HiddSec());

// myDrive.setBPB_TotSec32(32);
// print("BPB_TotSec32: ");
// println(myDrive.getBPB_TotSec32());

// myDrive.setBPB_FATSz32(0);
// print("BPB_FATSz32: ");
// println(myDrive.getBPB_FATSz32());

// // 0b0000000100000000
// myDrive.setBPB_ExtFlags(256);
// print("BPB_ExtFlags: ");
// println(myDrive.getBPB_ExtFlags());

// myDrive.setBPB_FSVer(0);
// print("BPB_FSVer: ");
// println(myDrive.getBPB_FSVer());

// myDrive.setBPB_RootClus(2);
// print("BPB_RootClus: ");
// println(myDrive.getBPB_RootClus());

// myDrive.setBPB_FSInfo(1);
// print("BPB_FSInfo: ");
// println(myDrive.getBPB_FSInfo());

// myDrive.setBPB_BkBootSec(6);
// print("BPB_BkBootSec: ");
// println(myDrive.getBPB_BkBootSec());

// myDrive.setBPB_Reserved(1);
// print("BPB_Reserved: ");
// println(myDrive.getBPB_Reserved());

// myDrive.setBPB_DrvNum(0);
// print("BPB_DrvNum: ");
// println(myDrive.getBPB_DrvNum());

// myDrive.setBPB_Reserved1(0);
// print("BPB_Reserved1: ");
// println(myDrive.getBPB_Reserved1());

// myDrive.setBPB_BootSig(0x29);
// print("BPB_BootSig: ");
// println(myDrive.getBPB_BootSig());

// myDrive.setBPB_VolID(@as(u32, @intCast(vexlib.millis() >> 32)));
// print("BPB_VolID: ");
// println(myDrive.getBPB_VolID());

// myDrive.setBS_VolLab("NO NAME    ");
// print("BS_VolLab: ");
// println(myDrive.getBS_VolLab());

// myDrive.setBS_FilSysType("FAT32   ");
// print("BS_FilSysType: ");
// println(myDrive.getBS_FilSysType());

// // should always be 0
// const rootDirSectors = ((myDrive.getBPB_RootEntCnt() * 32) + (myDrive.getBPB_BytesPerSec() - 1)) / myDrive.getBPB_BytesPerSec();
// print("rootDirSectors: ");
// println(rootDirSectors);

// const fatSz = myDrive.getBPB_FATSz32();
// const firstDataSector = myDrive.getBPB_RsvdSecCnt() + (myDrive.getBPB_NumFATs() * fatSz) + rootDirSectors;
// const N = 0; // cluster number
// const firstSectorOfCluster = ((N - 2) * @as(i32, @intCast(myDrive.getBPB_SecPerClus()))) + @as(i32, @intCast(firstDataSector));
// const totSec = myDrive.getBPB_TotSec32();
// print("totSec: ");
// println(totSec);

// const dataSec = totSec - (myDrive.getBPB_RsvdSecCnt() + (myDrive.getBPB_NumFATs() * fatSz) + rootDirSectors);
// const countOfClusters = dataSec / myDrive.getBPB_SecPerClus();
// const fatOffset = N * 4;
// const thisFATSecNum = myDrive.getBPB_RsvdSecCnt() + (fatOffset / myDrive.getBPB_BytesPerSec());
// const thisFATEntOffset = fatOffset % myDrive.getBPB_BytesPerSec();

// _=firstSectorOfCluster;
// _=countOfClusters;
// _=thisFATSecNum;
// _=thisFATEntOffset;