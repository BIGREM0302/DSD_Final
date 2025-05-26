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

# a5 replace sp
# a5: loop variable
# a5+4 : x addr
# a5+8 : w addr
# a5+12 : z addr

# t0: ow
# t1: k
# t2: n_cin
# t3: iw
# a4: 0 (=x0)
# sp: iw*iw*4
# a6: k*k*4
# a7: ow*ow*4

# a0~a3: temporaries

arr: .word 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
activation: .word 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47
weight: .word 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100 101 102 103 104 105 106 107


.text
main:
    c.jal conv # jal ra conv
    c.jal exit # jal ra exit

conv:
    ## new
    addi a4 x0 0 #INFO: set a4 always = x0
    ## /new

    c.mv a0 a4 # addi a0 x0 0 # res = 0
    
    lw t0 ow # load ow
        # for verilog simulation, modify to: addi t0 x0 2 
    lw t1 k # load k
        # for verilog simulation, modify to: addi t1 x0 3 
    lw t2 n_cin # load n_cin
        # for verilog simulation, modify to: addi t2 x0 3 
    lw t3 iw # load iw
        # for verilog simulation, modify to: addi t3 x0 4 
    
    mul a7 t0 t0 # a7 = ow*ow
    mul s3 t1 t1 # s3 = k*k
    slli a6 s3 2 # a6 = k*k*4
    mul s3 t2 s3 # s3 = k*k*n_cin
    mul sp t3 t3 # sp = iw*iw
    
    # load array address
    la s0 arr # output base address
        # for verilog simulation, modify to: addi s0 x0 0 
    la s1 weight # activation base address
        # for verilog simulation, modify to: addi s2 x0 64
    la s2 activation  # weight base address
        # for verilog simulation, modify to: addi s1 x0 256
    
    c.slli s3 2 # slli s3 s3 2 # s3 = k*k*n_cin*4
    c.slli sp 2 # slli sp sp 2 # sp = iw*iw*4
    c.slli a7 2 # slli a7 a7 2

    # set sp (a5)
    addi a5 x0 1024
init:
    ## sw x0 0(a5) # ix = 0
    ## sw x0 4(a5) # x addr = 0
    ## sw x0 8(a5) # w addr = 0
    ## sw x0 12(a5) # z addr = 0
    c.sw a4 a5 0 # ix = 0
    c.sw a4 a5 4 # x addr = 0
    c.sw a4 a5 8 # w addr = 0
    c.sw a4 a5 12 # z addr = 0

    
loop1: # in for ix in range(ow)
    ## c.addi a5 16 # addi a5 a5 16
    ## lw a0 -12(a5) # x_addr
    ## lw a1 -8(a5)
    ## lw a2 -4(a5)
    ## sw x0 0(a5) # iy = 0 
    ## sw a0 4(a5)
    ## sw a1 8(a5)
    ## sw a2 12(a5)
    c.lw a0 a5 4 # x_addr
    c.lw a1 a5 8 
    c.lw a2 a5 12
    c.sw a4 a5 16 # iy = 0 
    c.sw a0 a5 20
    c.sw a1 a5 24
    c.sw a2 a5 28
    c.addi a5 16 # addi a5 a5 16
loop2: # in for iy in range(ow)
    ## c.addi a5 16 # addi a5 a5 16
    ## lw a0 -12(a5)
    ## lw a1 -8(a5)
    ## lw a2 -4(a5)
    ## sw x0 0(a5) # kx = 0 
    ## sw a0 4(a5)
    ## sw a1 8(a5)
    ## sw a2 12(a5)
    c.lw a0 a5 4 
    c.lw a1 a5 8 
    c.lw a2 a5 12
    c.sw a4 a5 16 # kx = 0 
    c.sw a0 a5 20
    c.sw a1 a5 24
    c.sw a2 a5 28
    c.addi a5 16 # addi a5 a5 16
    c.mv s4 a4 # addi s4 x0 0
    c.mv s5 a4 # addi s5 x0 0
    c.mv s6 a4 # addi s6 x0 0
    c.mv s7 a4 # addi s7 x0 0 # reset 4 results
loop3: # in for kx in range(k)
    ## c.addi a5 16 # addi a5 a5 16
    ## lw a0 -12(a5)
    ## lw a1 -8(a5)
    ## lw a2 -4(a5)
    ## sw x0 0(a5) # ky = 0 
    ## sw a0 4(a5)
    ## sw a1 8(a5)
    ## sw a2 12(a5)
    c.lw a0 a5 4 
    c.lw a1 a5 8 
    c.lw a2 a5 12
    c.sw a4 a5 16 # ky = 0 
    c.sw a0 a5 20
    c.sw a1 a5 24
    c.sw a2 a5 28
    c.addi a5 16 # addi a5 a5 16
loop4: # in for ky in range(k)
    ## c.addi a5 16 # addi a5 a5 16
    ## lw a0 -12(a5)
    ## lw a1 -8(a5)
    ## lw a2 -4(a5)
    ## sw x0 0(a5) # cin = 0 
    ## sw a0 4(a5)
    ## sw a1 8(a5)
    ## sw a2 12(a5)
    c.lw a0 a5 4
    c.lw a1 a5 8
    c.lw a2 a5 12
    c.sw a4 a5 16 # cin = 0 
    c.sw a0 a5 20
    c.sw a1 a5 24
    c.sw a2 a5 28
    c.addi a5 16 # addi a5 a5 16
loop5: # in for cin in range(n_cin)
    
image:
    # load x[x_addr]
    c.lw a0 a5 4 # lw a0 4(a5) # a0 = x_addr
    c.lw a1 a5 8 # lw a1 8(a5) # a1 = w_addr
    c.add a0 s2 # add a0 s2 a0 # x_addr = base + bias
    c.add a1 s1 # add a1 s1 a1 # w_addr = base + bias
    c.lw a2 a0 0 # lw a2 0(a0) # a2 = x data
    c.lw a3 a1 0 # lw a3 0(a1) # a3 = w data
    mul s8 a2 a3
    c.add a1 s3 # add a1 a1 s3
    c.lw a3 a1 0 # lw a3 0(a1)
    mul s9 a2 a3
    c.add a1 s3 # add a1 a1 s3
    c.lw a3 a1 0 # lw a3 0(a1)
    mul s10 a2 a3
    c.add a1 s3 # add a1 a1 s3
    c.lw a3 a1 0 # lw a3 0(a1)
    mul s11 a2 a3
    c.add s4 s8  # add s4 s8 s4
    c.add s5 s9  # add s5 s9 s5
    c.add s6 s10 # add s6 s10 s6
    c.add s7 s11 # add s7 s11 s7

update:
    # update loop variable
    c.lw a0 a5 0 # lw a0 0(a5) # a0 = cin
    c.lw a2 a5 4 # lw a2 4(a5) # x_addr
    c.lw a3 a5 8 # lw a3 8(a5) # w_addr
    addi a1 a0 1
    c.add a2 sp # add a2 a2 sp # x_addr += iw*iw*4
    c.add a3 a6 # add a3 a3 a6 # w_addr += k*k*4
    sw a1 0(a5)
    sw a2 4(a5)
    sw a3 8(a5)
    # bne a1 t2 loop5
    beq a1 t2 skip_loop5
    jal x0 loop5
skip_loop5:
    c.addi a5 -16 # addi a5 a5 -16
    c.lw a0 a5 0 # lw a0 0(a5) # ky
    c.lw a2 a5 4 # lw a2 4(a5) # x_addr
    c.lw a3 a5 8 # lw a3 8(a5) # w_addr
    addi a1 a0 1
    c.addi a2 4 # addi a2 a2 4
    c.addi a3 4 # addi a3 a3 4
    sw a1 0(a5)
    sw a2 4(a5)
    sw a3 8(a5)
    # bne a1 t1 loop4
    beq a1 t1 skip_loop4
    jal x0 loop4
skip_loop4:
    c.addi a5 -16 # addi a5 a5 -16
    c.lw a0 a5 0 # lw a0 0(a5) # kx
    c.lw a2 a5 4 # lw a2 4(a5) # x_addr
    c.lw a3 a5 8 # lw a3 8(a5) # w_addr
    slli t4 t3 2
    slli t5 t1 2
    addi a1 a0 1
    c.add a2 t4 # add a2 a2 t4 # x_addr += iw*4
    c.add a3 t5 # add a3 a3 t5 # w_addr += k*4
    sw a1 0(a5)
    sw a2 4(a5)
    sw a3 8(a5)
    bne a1 t1 loop3

    c.addi a5 -16 # addi a5 a5 -16
    c.lw a0 a5 0 # lw a0 0(a5) # iy
    c.lw a2 a5 4 # lw a2 4(a5) # x_addr
    lw t4 12(a5) # z_addr
    add t5 t4 s0 # z_addr = base + bias
    sw s4 0(t5)
    c.add t5 a7 # add t5 a7 t5 # z_addr += ow*ow*4
    sw s5 0(t5)
    c.add t5 a7
    sw s6 0(t5)
    c.add t5 a7
    sw s7 0(t5)
    addi a1 a0 1
    c.addi a2 4 # addi a2 a2 4 # x_addr += 4
    c.addi t4 4 # addi t4 t4 4 # z_addr += 4
    sw a1 0(a5)
    sw a2 4(a5)
    sw t4 12(a5)
    bne a1 t0 loop2

    c.addi a5 -16 # addi a5 a5 -16
    c.lw a0 a5 0 # lw a0 0(a5) # ix
    c.lw a2 a5 4 # lw a2 4(a5) # x_addr
    lw t4 12(a5) # z_addr
    addi a1 a0 1
    slli a3 t3 2
    slli t5 t0 2
    c.add a2 a3 # add a2 a2 a3 # x_addr += iw*4
    c.add t4 t5 # add t4 t4 t5 # z_addr += ow*4
    sw a1 0(a5)
    sw a2 4(a5)
    sw t4 12(a5)
    beq t0 a1 skip_loop1
    jal x0 loop1
skip_loop1:
    c.jr ra # jalr x0 ra 0

exit:
    c.nop # addi x0 x0 0
    c.nop # addi x0 x0 0
    c.nop # addi x0 x0 0
    c.nop # addi x0 x0 0
    c.nop # addi x0 x0 0
    c.nop # addi x0 x0 0
    c.nop # addi x0 x0 0
    c.nop # addi x0 x0 0
    c.nop # addi x0 x0 0
    c.nop # addi x0 x0 0
    c.nop # addi x0 x0 0

    
    
    
    
 
    
    
    