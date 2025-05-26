請使用 ../Src/ 中的 Final_tb.v、slow_memory.v、CHIP.v 進行模擬
若要跑 compressed 之後的指令，請於模擬時加上 +define+Conv
若要跑 compressed 之前的指令，請於模擬時加上 +define+Conv_uncompressed

# Note: This script needs torch
    # You can install torch with pip or conda

# Usage: python conv_generate.py -n conv1 -s DSD
    # -n: name of the output file
    # -s: seed for random pattern generation

# This script only generates D_mem & D_gold because I_mem(_compression) remains identical

