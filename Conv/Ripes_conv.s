.data

k: .word 3
iw: .word 4
ow: .word 2
n_cin: .word 3

# Register 
# a0~a4: loop end condition
# s3~s11: temporary variables

# s0: output(z) array address
# s1: weight(w) array address
# s2: activation(x) array address
# s3: k*k*n_cin*4

# s4~s7: 4 cout results
# s8~s11: 4 mul results

# sp: loop variable
# sp+4 : x addr
# sp+8 : w addr
# sp+12 : z addr

# a0: ow
# a1: k
# a2: n_cin
# a4: iw
# a5: iw*iw*4
# a6: k*k*4
# a7: ow*ow*4
# len(arr) = 16
# len(activation) = 48
# len(weight) = 108


arr: .word 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 # size = 16
activation: .word 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47
weight: .word 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100 101 102 103 104 105 106 107


.text
main:
    jal ra conv
    jal ra exit

conv:
    addi t0 x0 0 # res = 0
    
    lw a0 ow # load ow
        # for verilog simulation, modify to: addi a0 x0 2 
    lw a1 k # load k
        # for verilog simulation, modify to: addi a1 x0 3
    lw a2 n_cin # load n_cin
        # for verilog simulation, modify to: addi a2 x0 3
    lw a4 iw # load iw
        # for verilog simulation, modify to: addi a4 x0 4
    
    mul a7 a0 a0 # a7 = ow*ow
    mul s3 a1 a1 # s3 = k*k
    slli a6 s3 2 # a6 = k*k*4
    mul s3 a2 s3 # s3 = k*k*n_cin
    mul a5 a4 a4 # a5 = iw*iw
    
    # load array address
    la s0 arr # output base address
        # for verilog simulation, modify to: addi s0 x0 0 
    la s1 weight # activation base address
        # for verilog simulation, modify to: addi s2 x0 64
    la s2 activation  # weight base address
        # for verilog simulation, modify to: addi s1 x0 256
    
    slli s3 s3 2 # s3 = k*k*n_cin*4
    slli a5 a5 2 # a5 = iw*iw*4
    slli a7 a7 2

    # set sp
    addi sp x0 1024
init:
    sw x0 0(sp) # ix = 0
    sw x0 4(sp) # x addr = 0
    sw x0 8(sp) # w addr = 0
    sw x0 12(sp) # z addr = 0

    
loop1: # in for ix in range(ow)
    addi sp sp 16
    lw t0 -12(sp) # x_addr
    lw t1 -8(sp)
    lw t2 -4(sp)
    sw x0 0(sp) # iy = 0 
    sw t0 4(sp)
    sw t1 8(sp)
    sw t2 12(sp)
loop2: # in for iy in range(ow)
    addi sp sp 16
    lw t0 -12(sp)
    lw t1 -8(sp)
    lw t2 -4(sp)
    sw x0 0(sp) # kx = 0 
    sw t0 4(sp)
    sw t1 8(sp)
    sw t2 12(sp)
    addi s4 x0 0
    addi s5 x0 0
    addi s6 x0 0
    addi s7 x0 0 # reset 4 results
loop3: # in for kx in range(k)
    addi sp sp 16
    lw t0 -12(sp)
    lw t1 -8(sp)
    lw t2 -4(sp)
    sw x0 0(sp) # ky = 0 
    sw t0 4(sp)
    sw t1 8(sp)
    sw t2 12(sp)
loop4: # in for ky in range(k)
    addi sp sp 16
    lw t0 -12(sp)
    lw t1 -8(sp)
    lw t2 -4(sp)
    sw x0 0(sp) # cin = 0 
    sw t0 4(sp)
    sw t1 8(sp)
    sw t2 12(sp)
loop5: # in for cin in range(n_cin)
    
image:
    # load x[x_addr]
    lw t0 4(sp) # t0 = x_addr
    lw t1 8(sp) # t1 = w_addr
    add t0 s2 t0 # x_addr = base + bias
    add t1 s1 t1 # w_addr = base + bias
    lw t2 0(t0) # t2 = x data
    lw t3 0(t1) # t3 = w data
       
    add t1 t1 s3
    lw t4 0(t1)
    add t1 t1 s3
    lw t5 0(t1)
    add t1 t1 s3
    lw t6 0(t1)

    mul s8 t2 t3
    mul s9 t2 t4
    mul s10 t2 t5
    mul s11 t2 t6
    
    add s4 s8 s4
    add s5 s9 s5
    add s6 s10 s6
    add s7 s11 s7

update:
    # update loop variable
    lw t0 0(sp) # t0 = cin
    lw t2 4(sp) # x_addr
    lw t3 8(sp) # w_addr
    addi t1 t0 1
    add t2 t2 a5 # x_addr += iw*iw*4
    add t3 t3 a6 # w_addr += k*k*4
    sw t1 0(sp)
    sw t2 4(sp)
    sw t3 8(sp)
    # bne t1 a2 skip_loop5
    beq t1 a2 skip_loop5
    jal x0 loop5
skip_loop5:
    addi sp sp -16
    lw t0 0(sp) # ky
    lw t2 4(sp) # x_addr
    lw t3 8(sp) # w_addr
    addi t1 t0 1
    addi t2 t2 4
    addi t3 t3 4
    sw t1 0(sp)
    sw t2 4(sp)
    sw t3 8(sp)
    # bne t1 a1 loop4
    beq t1 a1 skip_loop4
    jal x0 loop4
skip_loop4:
    addi sp sp -16
    lw t0 0(sp) # kx
    lw t2 4(sp) # x_addr
    lw t3 8(sp) # w_addr
    slli t4 a4 2
    slli t5 a1 2
    addi t1 t0 1
    add t2 t2 t4 # x_addr += iw*4
    add t3 t3 t5 # w_addr += k*4
    sw t1 0(sp)
    sw t2 4(sp)
    sw t3 8(sp)
    bne t1 a1 loop3

    addi sp sp -16
    lw t0 0(sp) # iy
    lw t2 4(sp) # x_addr
    lw t4 12(sp) # z_addr
    add t5 t4 s0 # z_addr = base + bias
    sw s4 0(t5)
    add t5 a7 t5 # z_addr += ow*ow*4
    sw s5 0(t5)
    add t5 a7 t5
    sw s6 0(t5)
    add t5 a7 t5
    sw s7 0(t5)
    addi t1 t0 1
    addi t2 t2 4 # x_addr += 4
    addi t4 t4 4 # z_addr += 4
    sw t1 0(sp)
    sw t2 4(sp)
    sw t4 12(sp)
    bne t1 a0 loop2

    addi sp sp -16
    lw t0 0(sp) # ix
    lw t2 4(sp) # x_addr
    lw t4 12(sp) # z_addr
    addi t1 t0 1
    slli t3 a4 2
    slli t5 a0 2
    add t2 t2 t3 # x_addr += iw*4
    add t4 t4 t5 # z_addr += ow*4
    sw t1 0(sp)
    sw t2 4(sp)
    sw t4 12(sp)
    # bne t1 a0 loop1
    beq t1 a0 skip_loop1
    jal x0 loop1
skip_loop1:
    jalr x0 ra 0

exit:
    addi x0 x0 0
    addi x0 x0 0
    addi x0 x0 0
    addi x0 x0 0
    addi x0 x0 0
    addi x0 x0 0
    addi x0 x0 0
    addi x0 x0 0
    addi x0 x0 0
    addi x0 x0 0
    addi x0 x0 0

    
    
    
    
 
    
    
    