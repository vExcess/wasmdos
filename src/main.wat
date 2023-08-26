(module
    ;; imports
    (func $debugString (import "imports" "debugString") (param i32) (param i32))
    (func $debugi32 (import "imports" "debugInt") (param i32))
    (func $vgaInterrupt (import "imports" "vgaInterrupt"))

    ;; import RAM [0-512) are psuedo-registers
    (memory (import "imports" "mem") 1)
    
    ;; implement software interrupts
    (table 32 funcref)
    (elem (i32.const 16) 
        $vgaInterrupt
    )
    (func $interrupt (param i32)
        local.get 0
        call_indirect
    )

    ;; simulate registers on a stack machine
    (global $AX i32 (i32.const 0))
    (global $CX i32 (i32.const 4))
    (global $DX i32 (i32.const 8))
    (global $BX i32 (i32.const 12))
    (global $SP i32 (i32.const 16))
    (global $BP i32 (i32.const 20))
    (global $SI i32 (i32.const 24))
    (global $DI i32 (i32.const 28))

    (func $gameLoop
        (local $i i32) (local $videoLen i32)

        i32.const 0
        local.set $i
        
        i32.const 68
        i32.load
        local.set $videoLen

        (loop $loop
            ;; i += 2
            local.get $i
            i32.const 2
            i32.add
            local.set $i

            ;; RAM[i] = 0
            local.get $i
            i32.const 15
            i32.store

            ;; RAM[i+1] = 0
            local.get $i
            i32.const 1
            i32.add
            i32.const 65
            i32.store

            ;; if $i is less than $videoLen branch to loop
            local.get $i
            local.get $videoLen
            i32.lt_s
            br_if $loop
        )
    )

    ;; entrypoint
    (func $main
        ;; set video mode to text mode 80x25 characters, 16 color VGA
        global.get $AX
        i32.const 3
        i32.store
        i32.const 16
        call $interrupt

        ;; store video mode and video buffer length
        i32.const 64
        i32.const 3
        i32.store
        i32.const 68
        i32.const 4000
        i32.store

        call $gameLoop
    )
    (start $main)
)
