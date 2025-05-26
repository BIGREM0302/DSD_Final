# Note: This script needs torch
    # You can install torch with pip or conda

# Usage: python conv_generate.py -n conv1 -s DSD
    # -n: name of the output file
    # -s: seed for random pattern generation

# This script only generates D_mem & D_gold due to that I_mem(_compression) remains identical

# ==========================================================
import argparse
import torch
import random

n_cout = 4
iw = 4
k = 3
n_cin = 3
ow = (iw-2)
output_size = n_cout * (iw - 2) * (iw-2)
activation_size = n_cin * iw * iw
weight_size = n_cout * n_cin * k * k

s = 1 # stride
p = 0 # padding

def write_D_mem(args):
    random.seed(args.seed)
    arr = [0 for i in range(output_size)]
    x_data = [random.randint(0, (2**13 -1)) for _ in range(activation_size)]
    w_data = [random.randint(0, (2**13 -1)) for _ in range(weight_size)]


    x = torch.tensor([x_data[i] for i in range(activation_size)]).view(n_cin, iw, iw)
    w = torch.tensor([w_data[i] for i in range(weight_size)]).view(n_cout, n_cin, k, k)

    z = torch.zeros(n_cout, ow, ow).long()

    for ix in range(0, ow):
        for iy in range(0, ow):
            for kx in range(k):
                for ky in range(k):
                    for cin in range(n_cin):
                        for cout in range(n_cout):
                            cur_x = ix*s+kx-p
                            cur_y = iy*s+ky-p
                            # print(cur_x, cur_y, ix, iy, kx, ky)
                            if cur_x < 0 or cur_x >= iw or cur_y < 0 or cur_y >= iw:
                                z[cout, ix, iy] += 0
                            else:
                                # print(f"x[{cin}, {ix+kx}, {iy+ky}] * w[{cout}, {cin}, {kx}, {ky}]")
                                z[cout, ix, iy] += x[cin, cur_x, cur_y] * w[cout, cin, kx, ky]


    with open(f"{args.name}_D_mem", "w") as fout:
        fout.write("//               location   data        hex\n")
        addr = 0

        for my_list in [arr, x_data, w_data] :
            for value in my_list:
                hex_data = f"{value:0>8x}"
                formatted_hex_data = "_".join([hex_data[i:i+2] for i in range(0, len(hex_data), 2)][::-1])
                fout.write(f"{formatted_hex_data:>11s}   // {addr:<#5x}{value:10d}   {hex_data}\n")

                addr += 4

        for i in range(addr, 1024, 4):
            fout.write(f"00_00_00_00   // {addr:<#5x}\n")

    with open(f"{args.name}_D_gold", 'w') as fout:
        fout.write("//               location   data        hex\n")
        addr = 0

        z = z.flatten().tolist()

        for my_list in [z, x_data, w_data] :
            for value in my_list:
                if my_list == z:
                    value = int(value)
                    assert value <= 2**32-1
                
                hex_data = f"{value:0>8x}"
                formatted_hex_data = "_".join([hex_data[i:i+2] for i in range(0, len(hex_data), 2)][::-1])
                fout.write(f"{formatted_hex_data:>11s}   // {addr:<#5x}{value:10d}   {hex_data}\n")
                
                addr += 4

        for i in range(addr, 1024, 4):
            fout.write(f"00_00_00_00   // {addr:<#5x}\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-n', '--name', type=str, required=True)
    parser.add_argument('-s', '--seed', type=str, default='112-2 DSD')
    args = parser.parse_args()
    write_D_mem(args)