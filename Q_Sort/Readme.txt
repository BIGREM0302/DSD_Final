請使用 ../Src/ 中的 Final_tb.v、slow_memory.v、CHIP.v 進行模擬
若要跑 compressed 之後的指令，請於模擬時加上 +define+QSort
若要跑 compressed 之前的指令，請於模擬時加上 +define+QSort_uncompressed

若要debug，請在 ./data_gen 中執行 python data_generate.py
可以修改 data_generate.py 中的 base & n

