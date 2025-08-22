# WASM DOS
Web Assembly Disk Operating System  

## Uses
- Create a non-persistant desktop environment anywhere
- Containerize apps

## Pros
- Runs anywhere WASM can run
- Lightweight
- Fast

The combination of being lightweight and fast with its ability to run everywhere would make it an excellent candidate for replacing Linux containers in the field of cloud computing.

## Build 
Run
```
zig build-exe -fno-entry -rdynamic -O ReleaseSmall -target wasm32-freestanding src/wasmdos.zig
```
Then
```
http-server .
```
Navigate to [http://127.0.0.1:8080/src/](http://127.0.0.1:8080/src/) in your browser.

## Status
You can type stuff and do nothing. Issue is that I have to allocate the entire heap at compile time due to the Zig compiler polluting the linear memory and not providing a way for me to attach a second linear memory to the WASM instance. So I'm waiting until I have a programming language that better supports WASM before I continue with this project.


