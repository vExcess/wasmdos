const disksLabel = document.getElementById("disks-label");
const disksEl = document.getElementById("disks");

let hardware = {
    displays: [
        new DisplayAdapter(canvas0)
    ],
    disks: [],
};

async function updateDisks() {
    if (opfsRoot === null) {
        opfsRoot = await navigator.storage.getDirectory();
    }
    
    disksEl.innerHTML = "";
    hardware.disks = [];
    for await (let [name, fileHandle] of opfsRoot.entries()) {
        if (fileHandle.kind === "file") {
            const file = await fileHandle.getFile();
            if (!file.name.endsWith(".crswap")) {
                let el = document.createElement("div");
                el.innerText = `${name} - ${file.size} bytes`;
                hardware.disks.push(new DiskAdapter(file.name, fileHandle, file.size));

                let delEL = document.createElement("button");
                delEL.style.marginLeft = "4px";
                delEL.style.backgroundColor = "rgb(230, 0, 0)";
                delEL.innerHTML = "Delete";
                delEL.addEventListener("click", () => {
                    const confirmation = window.confirm(`Are you sure you want to delete ${file.name}?`);
                    if (confirmation) {
                        opfsRoot.removeEntry(file.name);
                        updateDisks();
                    }
                });
                el.append(delEL);

                let downloadEl = document.createElement("button");
                downloadEl.style.marginLeft = "4px";
                downloadEl.innerHTML = "Download";
                downloadEl.addEventListener("click", () => {
                    const url = URL.createObjectURL(file);
                    const a = document.createElement('a');
                    a.style.display = 'none';
                    a.href = url;
                    a.download = file.name;
                    document.body.appendChild(a);
                    a.click();
                    window.URL.revokeObjectURL(url);

                });
                el.append(downloadEl);

                disksEl.append(el);
            }
        }
    }
}

async function start(compiledSource) {
    await updateDisks();

    // virtual RAM
    const MEGABYTE = 1024 * 1024;
    const PAGE_SIZE = 1024 * 64;
    // const RAM = new WebAssembly.Memory({
    //     initial: MEGABYTE / PAGE_SIZE,
    //     maximum: 128 * MEGABYTE / PAGE_SIZE
    // });
    let RAM;

    // virtual drivers
    const importObject = {
        env: {
            console_log(addr) {
                console.log(addr)
                let bytes = new Uint8Array(RAM.buffer, addr, 5);
                console.log(new TextDecoder("utf8").decode(bytes));
            },
            vga_setAddress(display, addr) {
                hardware.displays[display].videoBuffAddr = addr;
            }
        },
    };

    // run binary
    const wasm = new WebAssembly.Module(compiledSource);
    const wasmInstance = new WebAssembly.Instance(wasm, importObject);
    const exports = wasmInstance.exports;
    window.exports = exports;

    RAM = exports.memory;

    exports.start();

    // virtual monitor
    hardware.displays[0].setMode(3);
    setInterval(() => {
        exports.loop();
        let display0 = hardware.displays[0];
        let VGATUIBuff = new Uint8Array(RAM.buffer, display0.videoBuffAddr, 80*25*2);
        display0.update(VGATUIBuff);
    }, 1000 / 60);

    canvas0.addEventListener("keydown", (e) => {
        exports.keydown(e.keyCode);
    });
}

// attach disk
document.getElementById("diskImage").addEventListener('change', async (changeEvent) => {
    let files = changeEvent.target.files;
    let uploadFile = changeEvent.target.files[0];
    
    if (uploadFile) {
        disksLabel.innerText = "Disks: Uploading...";
        let adapter = await DiskAdapter.createFromFile(files[0], (bytes, fileSize) => {
            disksLabel.innerText = `Disks: Uploading... (${Math.round(bytes / fileSize * 100)}%) (${bytes}/${fileSize})`;
        });
        await updateDisks();
        disksLabel.innerText = `Disks:`;
    }
});

fetch("/wasmdos.wasm")
    .then(res => res.arrayBuffer())
    .then(binary => {
        start(binary);
    })

// compile and init source code
// WabtModule().then(wabt => {
//     let module;
//     let binaryBuffer = null;
//     try {
//         const watSrc = document.getElementById("wat").textContent;
//         const features = {
//             'exceptions': false,
//             'mutable_globals': false,
//             'sat_float_to_int': false,
//             'sign_extension': false,
//             'simd': false,
//             'threads': false,
//             'multi_value': false,
//             'tail_call': false,
//             'bulk_memory': false,
//             'reference_types': false,
//         };

//         // Assemble source code
//         module = wabt.parseWat("waos.wat", watSrc, features);
//         module.resolveNames();
//         module.validate(features);
//         binaryBuffer = module.toBinary({
//             log: false,
//             write_debug_names:false
//         }).buffer;
//     } catch (e) {
//         console.error(e);
//     }

//     // free memory
//     if (module) module.destroy();
    
//     if (binaryBuffer instanceof Uint8Array) {
//         // init
//         main(binaryBuffer);
//     }
// });
