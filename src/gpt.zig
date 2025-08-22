// 

const std = @import("std");

const vexlib = @import("lib/vexlib.zig");
const print = vexlib.print;
const println = vexlib.println;
const Math = vexlib.Math;
const Array = vexlib.Array;
const String = vexlib.String;
const Uint8Array = vexlib.Uint8Array;
const Int = vexlib.Int;

pub const Disk = struct {
    accessPoint: std.fs.File,
    size: usize,

    pub fn seekTo(self: *Disk, loc: usize) !void {
        try self.accessPoint.seekTo(loc);
    }

    pub fn read(self: *Disk, buffer: []u8) !void {
        _ = try self.accessPoint.read(buffer);
    }

    pub fn write(self: *Disk, buffer: []u8) !void {
        _ = try self.accessPoint.write(buffer);
    }

    pub fn getInfo(self: *Disk) String {
        var info = String.newFrom("Disk Info:\n");
        info.concat("    Size: ");
        var szStr = Int.toString(self.size, 10);
        defer szStr.free();
        info.concat(szStr);
        info.concat(" bytes\n");
        return info;
    }
};

// ----------------------------- crc32b --------------------------------
// This is the basic CRC-32 calculation with some optimization but no
// table lookup. The the byte reversal is avoided by shifting the crc reg
// right instead of left and by using a reversed 32-bit word to represent
// the polynomial.
//    When compiled to Cyclops with GCC, this function executes in 8 + 72n
// instructions, where n is the number of bytes in the input message. It
// should be doable in 4 + 61n instructions.
//    If the inner loop is strung out (approx. 5*8 = 40 instructions),
// it would take about 6 + 46n instructions. */
fn crc32b(message: []u8) u32 {
    var i: usize = 0;
    var j: i32 = undefined;
    var byte: u32 = undefined;
    var crc: u32 = 0xFFFFFFFF;
    var mask: u32 = undefined;

    while (i < message.len) {
        byte = message[i];            // Get next byte.
        crc = crc ^ byte;
        j = 7; while (j >= 0) : (j -= 1) { // Do eight times.
            mask = @as(u32, @bitCast(-@as(i32, @bitCast((crc & 1)))));
            crc = (crc >> 1) ^ (0xEDB88320 & mask);
        }
        i += 1;
    }
    return ~crc;
}

// Protective Master Boot Record
// https://uefi.org/specs/UEFI/2.10/05_GUID_Partition_Table_Format.html
pub const ProtectiveMBR = struct {
    disk: Disk,
    logicalBlockSize: u32,
    GPTStartCHS: u32,
    GPTEndCHS: u32,

    pub fn newPartitionRecord(options: struct{
        bootIndicator: u8,
        startingCHS: u32,
        osType: u8,
        endingCHS: u32,
        startingLBA: u32,
        sizeInLBA: u32
    }) Uint8Array {
        var partition = Uint8Array.new(16);

        // BootIndicator - Set to 0x00 to indicate a non-bootable partition.
        partition.write8(0, options.bootIndicator);

        // StartingCHS - Set to 0x000200 (512), corresponding to the Starting LBA field.
        partition.write24(1, options.startingCHS);
        
        // OSType - Set to 0xEE (i.e., GPT Protective)
        partition.write8(4, options.osType);

        // EndingCHS - Set to the CHS address of the last logical block on the disk. Set to 0xFFFFFF if it is not possible to represent the value in this field.
        partition.write24(5, options.endingCHS);

        // StartingLBA - Set to 0x00000001 (i.e., the LBA of the GPT Partition Header).
        partition.write32(8, options.startingLBA);

        // SizeInLBA - Set to the size of the disk minus one. Set to 0xFFFFFFFF if the size of the disk is too large to be represented in this field.
        partition.write32(12, options.sizeInLBA);

        return partition;
    }

    pub fn writeHeader(self: *ProtectiveMBR, options: struct{
        bootCode: []u8,
        uniqueMBRDiskSignature: []u8,
        unknown: []u8,
        partitions: [4][]u8,
        signature: u16,
        reserved: []u8
    }) void {
        self.disk.seekTo(0) catch |err| {
            bluescreen(err);
            unreachable;
        };

        self.disk.write(options.bootCode) catch |err| {
            bluescreen(err);
            unreachable;
        };

        self.disk.write(options.uniqueMBRDiskSignature) catch |err| {
            bluescreen(err);
            unreachable;
        };

        self.disk.write(options.unknown) catch |err| {
            bluescreen(err);
            unreachable;
        };

        const partitions = options.partitions;
        var p: usize = 0; while (p < partitions.len) : (p += 1) {
            self.disk.write(partitions[p]) catch |err| {
                bluescreen(err);
                unreachable;
            };
        }

        var view = Uint8Array.using(partitions[0]);
        self.GPTStartCHS = view.read24(1);
        self.GPTEndCHS = view.read24(7);

        var temp = Uint8Array.new(2);
        defer temp.free();
        temp.set(0, @as(u8, @intCast(options.signature & 255)));
        temp.set(1, @as(u8, @intCast((options.signature >> 8) & 255)));
        self.disk.write(temp.buffer[0..2]) catch |err| {
            bluescreen(err);
            unreachable;
        };

        self.disk.write(options.reserved) catch |err| {
            bluescreen(err);
            unreachable;
        };
    }

    pub fn getInfo(self: *ProtectiveMBR) String {
        var data = Uint8Array.new(self.logicalBlockSize);
        defer data.free();

        // read MBR data
        self.disk.seekTo(0) catch |err| {
            bluescreen(err);
            unreachable;
        };
        self.disk.write(data.buffer) catch |err| {
            bluescreen(err);
            unreachable;
        };

        var info = String.newFrom("Master Boot Record Info:\n");
        
        var tempStr = data.join(",");
        info.concat("    Boot Code: ");
        info.concat(tempStr);
        info.concat("\n");
        tempStr.free();

        tempStr = Int.toString(data.read32(440), 10);
        info.concat("    Unique MBR Disk Signature: ");
        info.concat(tempStr);
        info.concat("\n");
        tempStr.free();

        tempStr = Int.toString(data.read16(444), 10);
        info.concat("    Unknown: ");
        info.concat(tempStr);
        info.concat("\n");
        tempStr.free();

        info.concat("    Partition Record:\n");
        var p: u32 = 0; while (p < 4) : (p += 1) {
            const startOffset = @as(usize, @intCast(446 + p * 16));
            var partition = Uint8Array.using(data.buffer[startOffset..startOffset+16]);

            info.concat("        Partition ");
            info.concat(@as(u8, @intCast(48 + p)));
            info.concat(":\n");

            tempStr = Int.toString(partition.read8(0), 10);
            info.concat("            BootIndicator: ");
            info.concat(tempStr);
            info.concat("\n");
            tempStr.free();

            tempStr = Int.toString(partition.read24(1), 10);
            info.concat("            StartingCHS: ");
            info.concat(tempStr);
            info.concat("\n");
            tempStr.free();

            tempStr = Int.toString(partition.read8(4), 10);
            info.concat("            OSType: ");
            info.concat(tempStr);
            info.concat("\n");
            tempStr.free();

            tempStr = Int.toString(partition.read24(5), 10);
            info.concat("            EndingCHS: ");
            info.concat(tempStr);
            info.concat("\n");
            tempStr.free();

            tempStr = Int.toString(partition.read32(8), 10);
            info.concat("            StartingLBA: ");
            info.concat(tempStr);
            info.concat("\n");
            tempStr.free();
        
            tempStr = Int.toString(partition.read32(12), 10);
            info.concat("            SizeInLBA: ");
            info.concat(tempStr);
            info.concat("\n");
            tempStr.free();
        }

        tempStr = Int.toString(data.read16(510), 10);
        info.concat("    Signature: ");
        info.concat(tempStr);
        info.concat("\n");
        tempStr.free();

        if (data.len >= 512) {
            var view = Uint8Array.using(data.buffer[512..data.len]);
            tempStr = view.join(",");
            info.concat("    Reserved: ");
            info.concat(tempStr);
            info.concat("\n");
            tempStr.free();
        } else {
            info.concat("    Reserved: \n");
        }

        return info;
    }
};

// GUID Partition Table
// https://en.wikipedia.org/wiki/GUID_Partition_Table#/media/File:GUID_Partition_Table_Scheme.svg
// https://uefi.org/specs/UEFI/2.10/05_GUID_Partition_Table_Format.html
pub const GPT = struct {
    disk: Disk,

    pub fn write(self: *GPT, buffer: []u8) void {
        self.disk.write(buffer) catch |err| {
            bluescreen(err);
            unreachable;
        };
    }

    pub fn read(self: *GPT, buffer: []u8) void {
        self.disk.read(buffer) catch |err| {
            bluescreen(err);
            unreachable;
        };
    }

    pub fn updateSecondaryHeader(self: *GPT) void {
        var primaryHeader = Uint8Array.new(512);
        defer primaryHeader.free();
        self.disk.read(primaryHeader.buffer) catch |err| {
            bluescreen(err);
            unreachable;
        };

        var primaryPartitions = Uint8Array.new(512 * 32);
        defer primaryPartitions.free();
        self.disk.read(primaryPartitions.buffer) catch |err| {
            bluescreen(err);
            unreachable;
        };

        // seek to secondary 
        self.disk.seekTo(self.disk.size - 512 * 33) catch |err| {
            bluescreen(err);
            unreachable;
        };
        
        self.disk.write(primaryPartitions.buffer) catch |err| {
            bluescreen(err);
            unreachable;
        };

        self.disk.write(primaryHeader.buffer) catch |err| {
            bluescreen(err);
            unreachable;
        };
    }

};

fn bluescreen(err: anytype) void {
    println("    WASM DOS    ");
    println("An unrecoverable error has occured.");
    err catch unreachable;
}

pub fn main() void {
    var generalPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = generalPurposeAllocator.deinit();
    const allocator = generalPurposeAllocator.allocator();
    vexlib.init(&allocator);

    // try to read existing disk
    var createNewDisk = false;
    const diskFile: std.fs.File = std.fs.cwd().openFile(
        "./wasmdosdisk.img",
        .{ .mode = .read_write },
    ) catch blk: {
        // create new disk if can't find existing disk
        createNewDisk = true;
        break :blk std.fs.cwd().createFile(
            "./wasmdosdisk.img",
            .{ .read = true },
        ) catch |err| {
            bluescreen(err);
            unreachable;
        };
    };

    println("[ OK ] Disk access established");

    var myDisk = Disk{
        .accessPoint = diskFile,
        .size = 1024 * 1024
    };
    defer myDisk.accessPoint.close();

    var myMBR = ProtectiveMBR{
        .disk = myDisk,
        .logicalBlockSize = 512,
        .GPTStartCHS = undefined,
        .GPTEndCHS = undefined
    };

    // temporary buffer
    var empty = Uint8Array.new(myMBR.logicalBlockSize);
    empty.fill(0, -1);

    // initialize MBR
    if (createNewDisk) {
        println("Input new disk size in MB: ");
        // const sz = vexlib.readln(8) catch |err| {
        //     bluescreen(err);
        //     unreachable;
        // };
        // defer sz.free();
        myDisk.size = 1024 * 1024 * 4;
        const u32DiskSz = @as(u32, @intCast(myDisk.size));
        
        // Protective MBR
        myMBR.disk.seekTo(0) catch |err| {
            bluescreen(err);
            unreachable;
        };

        var initialMBRPartition = ProtectiveMBR.newPartitionRecord(.{
            // Set to 0x00 to indicate a non-bootable partition.
            .bootIndicator = 0x00,
            // Set to 0x000200, corresponding to the Starting LBA field.
            .startingCHS = 0x000200, // 512
            // Set to 0xEE (i.e., GPT Protective)
            .osType = 0xEE,
            // Set to the CHS address of the last logical block on the disk.
            .endingCHS = u32DiskSz - myMBR.logicalBlockSize,
            // Set to 0x00000001 (i.e., the LBA of the GPT Partition Header).
            .startingLBA = 0x00000001, // 1
            // Set to the size of the disk minus one.
            .sizeInLBA = u32DiskSz - 1
        });
        defer initialMBRPartition.free();

        myMBR.writeHeader(.{
            // Boot Code - Unused by UEFI systems.
            .bootCode = empty.buffer[0..440],
            // Unique MBR Disk Signature - Unused. Set to zero.
            .uniqueMBRDiskSignature = empty.buffer[0..4],
            // Unknown - Unused. Set to zero.
            .unknown = empty.buffer[0..2],
            // Partition Record - Array of four MBR partition records.
            .partitions = [_][]u8{
                initialMBRPartition.buffer,
                empty.buffer[0..16],
                empty.buffer[0..16],
                empty.buffer[0..16],
            },
            // Signature - Set to 0xAA55 (i.e., byte 510 contains 0x55 and byte 511 contains 0xAA).
            .signature = 0xAA55,
            // The rest of the logical block, if any, is reserved. Set to zero.
            .reserved = empty.buffer[0..myMBR.logicalBlockSize-512],
        });

        
    }

    var diskInfo = myDisk.getInfo();
    defer diskInfo.free();
    println(diskInfo);

    var mbrInfo = myMBR.getInfo();
    defer mbrInfo.free();
    println(mbrInfo);

    println(myMBR.GPTStartCHS);
    println(myMBR.GPTEndCHS);

    var myGPT = GPT{
        .disk = myDisk
    };

    if (createNewDisk) {
        const u32DiskSz = @as(u32, @intCast(myDisk.size));

        // GPT Header
        myGPT.disk.seekTo(512) catch |err| {
            bluescreen(err);
            unreachable;
        };

        // Signature
        var sig = String.newFrom("EFI PART");
        myGPT.write(sig.bytes.buffer);
        sig.free();

        // Revision
        const version: u32 = 0x00010000;
        empty.write32(0, version);
        myGPT.write(empty.buffer[0..4]);

        // HeaderSize
        empty.write32(0, 92);
        myGPT.write(empty.buffer[0..4]);

        // HeaderCRC32
        empty.write32(0, crc32b(empty.buffer[0..4]));
        myGPT.write(empty.buffer[0..4]);

        // Reserved
        empty.write32(0, 0);
        myGPT.write(empty.buffer[0..4]);

        // MyLBA
        empty.write64(0, 512);
        myGPT.write(empty.buffer[0..8]);

        // AlternateLBA
        empty.write64(0, u32DiskSz - 512);
        myGPT.write(empty.buffer[0..8]);

        // FirstUsableLBA
        empty.write64(0, 512 * 34);
        myGPT.write(empty.buffer[0..8]);

        // LastUsableLBA
        empty.write64(0, (u32DiskSz / 512 - 34) * 512);
        myGPT.write(empty.buffer[0..8]);

        // DiskGUID
        empty.write64(0, Math.randomInt(u64));
        empty.write64(8, Math.randomInt(u64));
        myGPT.write(empty.buffer[0..16]);

        // PartitionEntryLBA
        const partitionEntryLBA = 512 * 2;
        empty.write64(0, partitionEntryLBA);
        myGPT.write(empty.buffer[0..8]);

        // NumberOfPartitionEntries
        const numPartitions = 1;
        empty.write32(0, numPartitions);
        myGPT.write(empty.buffer[0..4]);

        // SizeOfPartitionEntry
        const partitionEntrySz = 128;
        empty.write32(0, partitionEntrySz);
        myGPT.write(empty.buffer[0..4]);

        // PartitionEntryArrayCRC32
        var partitionEntries = Uint8Array.new(numPartitions * partitionEntrySz);
        defer partitionEntries.free();
        myGPT.disk.seekTo(partitionEntryLBA) catch |err| {
            bluescreen(err);
            unreachable;
        };
        myGPT.read(partitionEntries.buffer);
        empty.write32(0, crc32b(partitionEntries.buffer));
        myGPT.write(empty.buffer[0..4]);

        // Reserved
        myGPT.write(empty.buffer[16..16+92]);

        // create backup header and partitions array
        myGPT.updateSecondaryHeader();
    }

    empty.free();

    println("[ OK ] Shut down successful");
}
