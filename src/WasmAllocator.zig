const std = @import("std");

const HeapEntry = struct {
    size: u32,
    isFree: bool
};

pub const WasmAllocator = struct {
    const HEAP_SIZE = 1024*64*1000;
    heap: [HEAP_SIZE]u8 = undefined,
    heapTable: [1024]HeapEntry = undefined,
    heapTableInitialized: bool = false,

    pub fn alloc(self: *WasmAllocator, comptime T: type, n: usize) ![]T {
        if (!self.heapTableInitialized) {
            var i: usize = 1;
            while (i < self.heapTable.len) : (i += 1) {
                self.heapTable[i] = HeapEntry{
                    .size = 0,
                    .isFree = false
                };
            }
            self.heapTable[0] = HeapEntry{
                .size = HEAP_SIZE,
                .isFree = true
            };
            self.heapTableInitialized = true;
        }

        const typeSize = @sizeOf(T);
        const bytesNeeded = typeSize * n;

        var addr: usize = 0;
        var i: usize = 0; while (i < self.heapTable.len) : (i += 1) {
            var c = self.heapTable[i];
            const cSize = c.size;
            if (c.isFree and cSize >= bytesNeeded) {
                c.size = bytesNeeded;
                c.isFree = false;
                
                self.heapTable[i+1].size = cSize - bytesNeeded;
                self.heapTable[i+1].isFree = true;
                
                const ptr: [*]T = @ptrFromInt(addr);
                return ptr[0..n];
            }
            addr += cSize;
        }

        return std.mem.Allocator.Error.OutOfMemory;
    }

    pub fn free(self: *WasmAllocator, memory: anytype) void {
        const freeAddr = @intFromPtr(memory[0..1]);
        var addr: usize = 0;
        var i: usize = 0; while (i < self.heapTable.len) : (i += 1) {
            var c = self.heapTable[i];
            if (addr == freeAddr) {
                c[1] = true;
                
                if (i+1 < self.heapTable.len and self.heapTable[i+1][1]) {
                    c.size += self.heapTable[i+1].size;
                    self.heapTable[i+1].size = 0;
                    self.heapTable[i+1].isFree = false;
                }
                if (i-1 >= 0 and self.heapTable[i-1][1]) {
                    c.size += self.heapTable[i-1].size;
                    self.heapTable[i-1].size = 0;
                    self.heapTable[i-1].isFree = false;
                }
                
                return;
            }
            addr += c[0];
        }
    }
};
