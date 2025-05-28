    .text
    .globl main

main:
    nop                             # 0x00
    jal  x0, Main                   # 0x04

OutputTestPort:                    # 0x08
    sw   x8, 64(x0)                # store x8 to memory[64]
    jalr x0, x1, 0                 # 0x0C

FibonacciSeries:                   # 0x10
    addi x11, x0, 16               # number = 16
    addi x9,  x0, 0                # f(0) = 0
    addi x10, x0, 1                # f(1) = 1
    addi x15, x0, 0                # base address = 0
    sw   x9, 0(x15)                # store f(0)
    addi x15, x15, 4              # next address
    sw   x10, 0(x15)              # store f(1)
    addi x8, x9, 0
    jal  x1, OutputTestPort
    addi x8, x10, 0
    jal  x1, OutputTestPort
    addi x12, x0, 2               # i = 2

FibonacciLoop:                     # 0x40
    add  x10, x10, x9             # f(i) = f(i-1) + f(i-2)
    sub  x9, x10, x9              # f(i-1) = f(i) - f(i-2)
    addi x15, x15, 4              # next address
    sw   x10, 0(x15)
    addi x8, x10, 0
    jal  x1, OutputTestPort
    addi x12, x12, 1              # i++
    bne  x12, x11, FibonacciLoop
    jalr x0, x2, 0                # return

BubbleSort:                        # 0x64
    addi x9, x0, 60               # 4*(number-1)
    addi x10, x0, 0               # 4*i = 0

BubbleOutLoop:                     # 0x6C
    sub  x12, x9, x10            # 4*(number-1-i)
    addi x11, x0, 0               # 4*j = 0

BubbleInLoop:                      # 0x74
    lw   x13, 0(x11)              # arr[j]
    lw   x14, 4(x11)              # arr[j+1]
    slt  x15, x13, x14
    beq  x15, x0, SwapExit
    sw   x14, 0(x11)
    sw   x13, 4(x11)

SwapExit:                          # 0x8C
    addi x11, x11, 4
    bne  x11, x12, BubbleInLoop
    addi x10, x10, 4
    bne  x10, x9, BubbleOutLoop
    addi x9, x0, 64               # 4*number
    addi x10, x0, 0               # 4*k = 0

BubbleOutput:                      # 0xA4
    lw   x8, 0(x10)
    jal  x1, OutputTestPort
    addi x10, x10, 4
    bne  x10, x9, BubbleOutput
    jalr x0, x2, 0

Main:                              # 0xB8
    addi x8, x0, 360              # 0x168
    jal  x1, OutputTestPort
    addi x16, x0, Main
    addi x17, x0, Main
    jalr x2, x16, FibonacciSeries
    jalr x2, x17, BubbleSort
    addi x8, x0, 3421             # 0xD5D
    jal  x1, OutputTestPort
    nop
    nop
    li a7, 10
    ecall
