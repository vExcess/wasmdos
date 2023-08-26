# WASM-DOS
Web Assembly Disk Operating System  

I know, single handedly writing an operating system from scratch in WASM is doomed to fail. Others have tried and failed before me, but at least it'll be a good learning experience.  

## Why
Mainly I want to learn how operating systems work by creating one myself. But also I think it'd be cool if people were able to have a remote desktop such that they could access their computer from anywhere in the world as long as they have a web browser and internet connection. There already exists software that lets you access your desktop from a remote computer but all existing softwares have the following issues:
- cost lots of money  
- require installing special software on both the desktop and remote computer  
- require a high speed internet connection

WASM-DOS would be  
- free  
- the only software required is a plain old web browser  
- because the OS is running in the browser itself instead of being livestreamed a network connection is not needed after the initial page load. In addition the OS will have lower latency and be more responsive

Because it needs to run in a browser WASM-OS will be specifically designed to be ultra light weight and have an incredibly fast boot time. In addition because it is written in Web Assembly, WASM-OS is a cross-platform software and can run anywhere on any hardware so long as you have a WASM runtime. This combination of being lightweight and fast plus its ability to run everywhere would make it an excellent candidate for replacing Linux containers in the field of cloud computing. Despite virtual machines running on modern hardware being pretty fast, if you want the fastest creamy smooth experience you will be better off running WASM-OS instead of emulating Linux inside of VMware or VirtualBox
