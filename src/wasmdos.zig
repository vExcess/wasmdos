// zig build-exe -fno-entry -rdynamic -O ReleaseSmall -target wasm32-freestanding src/wasmdos.zig

const std = @import("std");
const vexlib = @import("./lib/vexlib.zig");
const String = vexlib.String;

const WasmAllocator = @import("./WasmAllocator.zig").WasmAllocator;

const VGA = @import("./lib/vga.zig");

var allocator = WasmAllocator{};

extern fn console_log(a: u32) void;

export fn add(a: u32, b: u32) u32 {
    return a + b;
}

// export fn add(a: i32, b: i32) i32 {
//     var result: i32 = undefined;
//     asm volatile (
//         \\ local.get 0
//         \\ local.get 1
//         \\ i32.add
//         : [result] "=r" (result)
//         : [a] "r" (a), [b] "r" (b)
//     );
//     return result;
// }



pub fn bsod(err: anytype) void {
    switch (err) {
        else => {

        }
    }
    // println("    WASM DOS    ");
    // println("An unrecoverable error has occured.");
    @panic("Kernel Exit" );
}

var lines: [25][85]u8 = undefined;
var colors: [25][85]u8 = undefined;
var lineIdx: usize = 10;

fn shiftUp() void {
    var y: usize = 0; while (y < lines.len-1) : (y += 1) {
        var x: usize = 0; while (x < lines[y].len) : (x += 1) {
            lines[y][x] = lines[y+1][x];
            colors[y][x] = colors[y+1][x];
        }
    }
}

fn startsWith(a: []u8, b: []u8) bool {
    var x: usize = 0; while (x < a.len) : (x += 1) {
        if (x == b.len) {
            return true;
        }
        if (b[x] != a[x]) {
            return false;
        }
    }
    return true;
}

export fn keydown(keyCode: u32) void {
    if (keyCode == 13) {
        shiftUp();

        if (startsWith(lines[24][10..], String.usingRawString("HELP").raw())) {
            shiftUp();
            lines[23][0..16].* = "No help for you!".*;
            var x: usize = 0; while (x < lines[23].len) : (x += 1) {
                colors[23][x] = VGA.COLOR.cyan;
            }
            colors[23][0..20].* = "\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04".*;
        } else if (startsWith(lines[24][10..], String.usingRawString("LS").raw())) {
            shiftUp();
            lines[23][0..17].* = "No files for you!".*;
            var x: usize = 0; while (x < lines[23].len) : (x += 1) {
                colors[23][x] = VGA.COLOR.cyan;
            }
            colors[23][0..20].* = "\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04\x04".*;
        }
        
        var x: usize = 10; while (x < lines[24].len) : (x += 1) {
            lines[24][x] = 0;
        }
        lines[24][0..10].* = "vexcess:~$".*;
        colors[24][0..10].* = "\x0f\x0f\x0f\x0f\x0f\x0f\x0f\x01\x0f\x02".*;

        lineIdx = 10;
    } else if (keyCode == 8) {
        if (lineIdx > 10) {
            lineIdx -= 1;
            lines[24][lineIdx] = 0;
        }
    } else if (keyCode != 16) {
        lines[24][lineIdx] = @truncate(keyCode);
        lineIdx += 1;
    }
}

var display0: VGA.DisplayDriver = undefined;

export fn start() void {
    // vexlib.init(&allocator);

    display0 = VGA.DisplayDriver.allocTUI(&allocator, 0) catch |err| {
        bsod(err);
        unreachable;
    };

    var y: usize = 0; while (y < lines.len) : (y += 1) {
        var x: usize = 0; while (x < lines[y].len) : (x += 1) {
            lines[y][x] = 0;
            colors[y][x] = VGA.COLOR.green;
        }
    }

    var i: u8 = 0; while (i < 80) : (i += 1) {
        lines[21][i] = i;
        lines[22][i] = i+80;
    }

    lines[23][0..19].* = "Welcome to WASM DOS".*;
    var x: usize = 0; while (x < lines[23].len) : (x += 1) {
        colors[23][x] = VGA.COLOR.cyan;
    }

    lines[24][0..10].* = "vexcess:~$".*;
    colors[24][0..10].* = "\x0f\x0f\x0f\x0f\x0f\x0f\x0f\x01\x0f\x02".*;
    
    // allocator.free(display0.TUIBuffer);
}

export fn loop() void {
    var y: usize = 0; while (y < lines.len) : (y += 1) {
        var x: usize = 0; while (x < lines[y].len) : (x += 1) {
            display0.writeChar(lines[y][x], x, y, colors[y][x], VGA.COLOR.black);
        }
    }
}

