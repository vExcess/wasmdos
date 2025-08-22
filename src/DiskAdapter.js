let opfsRoot = null;

async function readFile(file, address, len) {
    return new Promise((resolve) => {
        let reader = new FileReader();
        reader.onload = function() {
            resolve(reader.result);
        };
        let blob = file.slice(address, address + len);
        reader.readAsArrayBuffer(blob);
    });
}

class DiskAdapter {
    name;
    fileHandle;
    size;

    constructor(name, fileHandle, size) {
        this.name = name;
        this.fileHandle = fileHandle;
        this.size = size;
    }

    static async createFromFile(file, uploadUpdateCallback) {
        if (opfsRoot === null) {
            opfsRoot = await navigator.storage.getDirectory();
        }

        let fileHandle;
        try {
            // get file handle
            fileHandle = await opfsRoot.getFileHandle(file.name);
        } catch (e) {
            // create file if we failed to access it
            fileHandle = await opfsRoot.getFileHandle(file.name, {create: true});
        }

        const fileSize = file.size;
        const chunkSize = 1024 * 1000 * 100; // 100 MB
        let adapter = new DiskAdapter(file.name, fileHandle, fileSize);
        await adapter.resize(fileSize);

        let i = 0;
        while (i < fileSize) {
            let stopPoint = i + chunkSize;
            if (stopPoint > fileSize) {
                stopPoint = fileSize;
            }
            let buffer = await readFile(file, i, stopPoint - i);
            await adapter.write(i, buffer);
            i += chunkSize;
            if (uploadUpdateCallback) {
                uploadUpdateCallback(i, fileSize);
            }
        }

        return adapter;
    }

    async read(address, len) {
        let diskFile = this.fileHandle.getFile();
        return new Promise((resolve) => {
            let reader = new FileReader();
            reader.onload = function() {
                resolve(reader.result);
            };
            let blob = diskFile.slice(address, address + len);
            reader.readAsArrayBuffer(blob);
        });
    }

    async resize(size) {
        const writable = await this.fileHandle.createWritable();
        await writable.truncate(size);
        await writable.close();
        this.size = size;
    }

    async write(address, data) {
        const writable = await this.fileHandle.createWritable();
        await writable.write({
            type: "write",
            position: address,
            data: data
        });
        await writable.close();
    }
}