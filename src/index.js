class VGA_Emulator {
    /*
        Bit(s)	Value
        0-7	    ASCII code point
        8-11	Foreground color
        12-14	Background color
        15	    Blink

        Number  Color	    Number + Bright Bit	Bright  Color
        0x0	    Black	    0x8	                        Dark Gray
        0x1	    Blue	    0x9	                        Light Blue
        0x2 	Green	    0xa	                        Light Green
        0x3	    Cyan	    0xb	                        Light Cyan
        0x4 	Red	        0xc 	                    Light Red
        0x5	    Magenta 	0xd	                        Pink
        0x6	    Brown	    0xe	                        Yellow
        0x7	    Light Gray	0xf	                        White
    */

    static CHARS = "\x00☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~⌂";
    static COLORS = [
        "black",    "blue",      "green",      "cyan",      "red",      "magenta", "brown",  "lightgray",
        "darkgray", "lightblue", "lightgreen", "lightcyan", "lightred", "pink",    "yellow", "white"
    ];

    canvas;
    ctx;
    width;
    height;
    mode = -1;
    displayWidth;
    displayHeight;

    constructor(canvas) {
        this.canvas = canvas;
        this.ctx = canvas.getContext("2d");
    }

    setSize(width, height) {
        this.width = width;
        this.height = height;
        this.canvas.width = width;
        this.canvas.height = height;
        this.canvas.style.transform = `scale(${this.displayWidth / width})`;
    }

    setDisplaySize(width, height) {
        this.displayWidth = width;
        this.displayHeight = height;
        this.canvas.style.transform = `scale(${this.displayWidth / width})`;
    }

    setMode(mode) {
        this.mode = mode;
        switch (mode) {
            case 3: {
                // text mode 80x25 characters, 16 color VGA
                this.setSize(720, 400);
            }
        }
    }

    update(videoBuffer) {
        const ctx = this.ctx;
        switch (this.mode) {
            case 3: {
                ctx.fillStyle = "black";
                ctx.fillRect(0, 0, this.width, this.height);
                // console.log(videoBuffer)
                ctx.font = "bold 16px monospace";
                for (let i = 0; i < videoBuffer.length; i += 2) {
                    let foregroundClr = videoBuffer[i] & 0b1111;
                    let backgroundClr = (videoBuffer[i] >> 4) & 0b111;
                    let blink = (videoBuffer[i] >> 7) & 0b1;
                    let codePt = videoBuffer[i + 1];
                    let ch = VGA_Emulator.CHARS[codePt];
                    let x = (i >> 1) % 80;
                    let y = ((i >> 1) / 80) | 0;

                    // if (i === 0) {
                    //     console.log(VGA_Emulator.COLORS[backgroundClr])
                    // }
                    
                    ctx.fillStyle = VGA_Emulator.COLORS[backgroundClr];
                    ctx.fillRect(x * 9, y * 16, 9, 16);
                    
                    ctx.fillStyle = VGA_Emulator.COLORS[foregroundClr];
                    ctx.fillText(ch, 0 + x * 9, 13 + y * 16);
                }
            }
        }
    }
}
function main(compiledSource) {
    // virtual RAM
    const MEGABYTE = 1048576;
    const PAGE_SIZE = 65536;
    const vRAM = new WebAssembly.Memory({
        initial: MEGABYTE / PAGE_SIZE,
        maximum: 128 * MEGABYTE / PAGE_SIZE
    });

    // virtual monitor
    let monitor = new VGA_Emulator(document.getElementById("monitor"));
    monitor.setDisplaySize(window.innerWidth, window.innerHeight);

    setInterval(() => {
        monitor.update(new Uint8Array(vRAM.buffer, 72, 4000));
    }, 1000 / 6);

    // virtual drivers
    const importObject = {
        imports: {
            mem: vRAM,
            vgaInterrupt() {
                const graphicsMode = new Uint8Array(vRAM.buffer, 0, 4000)[0];
                monitor.setMode(graphicsMode);
            },
            debugString(offset, len) {
                let bytes = new Uint8Array(vRAM.buffer, offset, len);
                console.log(new TextDecoder("utf8").decode(bytes));
            },
            debugInt(n) {
                console.log(n);
            },
        },
    };

    // run binary
    const wasm = new WebAssembly.Module(compiledSource);
    const wasmInstance = new WebAssembly.Instance(wasm, importObject);
}

// compile and init source code
WabtModule().then(wabt => {
    let module;
    let binaryBuffer = null;
    try {
        const watSrc = document.getElementById("wat").textContent;
        const features = {
            'exceptions': false,
            'mutable_globals': false,
            'sat_float_to_int': false,
            'sign_extension': false,
            'simd': false,
            'threads': false,
            'multi_value': false,
            'tail_call': false,
            'bulk_memory': false,
            'reference_types': false,
        };

        // Assemble source code
        module = wabt.parseWat("waos.wat", watSrc, features);
        module.resolveNames();
        module.validate(features);
        binaryBuffer = module.toBinary({
            log: false,
            write_debug_names:false
        }).buffer;
    } catch (e) {
        console.error(e);
    }

    // free memory
    if (module) module.destroy();
    
    if (binaryBuffer instanceof Uint8Array) {
        // init
        main(binaryBuffer);
    }
});
