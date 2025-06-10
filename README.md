# Simulation for DSD final

## RTL - Baseline

vcs Final_tb.v rtl_files.v slow_memory.v -full64 -R -debug_access+all +v2k +define+noHazard
vcs Final_tb.v rtl_files.v slow_memory.v -full64 -R -debug_access+all +v2k +define+hasHazard

## Gate level - Baseline

vcs Final_tb.v CHIP_syn.v slow_memory.v -v tsmc13.v -full64 -R -debug_access+all +v2k +define+noHazard +define+SDF
vcs Final_tb.v CHIP_syn.v slow_memory.v -v tsmc13.v -full64 -R -debug_access+all +v2k +define+hasHazard +define+SDF

## RTL - Extension

vcs Final_tb.v rtl_files.v slow_memory.v -full64 -R -debug_access+all +v2k +define+BrPred
vcs Final_tb.v rtl_files.v slow_memory.v -full64 -R -debug_access+all +v2k +define+compression
vcs Final_tb.v rtl_files.v slow_memory.v -full64 -R -debug_access+all +v2k +define+compression_uncompressed
vcs Final_tb.v rtl_files.v slow_memory.v -full64 -R -debug_access+all +v2k +define+Mul
vcs Final_tb.v rtl_files.v slow_memory.v -full64 -R -debug_access+all +v2k +define+QSort_uncompressed
vcs Final_tb.v rtl_files.v slow_memory.v -full64 -R -debug_access+all +v2k +define+Conv_uncompressed
vcs Final_tb.v rtl_files.v slow_memory.v -full64 -R -debug_access+all +v2k +define+QSort
vcs Final_tb.v rtl_files.v slow_memory.v -full64 -R -debug_access+all +v2k +define+Conv

## Gate level - Extension

vcs Final_tb.v CHIP_syn.v slow_memory.v -v tsmc13.v -full64 -R -debug_access+all +v2k +define+BrPred +define+SDF
vcs Final_tb.v CHIP_syn.v slow_memory.v -v tsmc13.v -full64 -R -debug_access+all +v2k +define+compression +define+SDF
vcs Final_tb.v CHIP_syn.v slow_memory.v -v tsmc13.v -full64 -R -debug_access+all +v2k +define+compression_uncompressed +define+SDF
vcs Final_tb.v CHIP_syn.v slow_memory.v -v tsmc13.v -full64 -R -debug_access+all +v2k +define+Mul +define+SDF
vcs Final_tb.v CHIP_syn.v slow_memory.v -v tsmc13.v -full64 -R -debug_access+all +v2k +define+QSort_uncompressed +define+SDF
vcs Final_tb.v CHIP_syn.v slow_memory.v -v tsmc13.v -full64 -R -debug_access+all +v2k +define+Conv_uncompressed +define+SDF
vcs Final_tb.v CHIP_syn.v slow_memory.v -v tsmc13.v -full64 -R -debug_access+all +v2k +define+QSort +define+SDF
vcs Final_tb.v CHIP_syn.v slow_memory.v -v tsmc13.v -full64 -R -debug_access+all +v2k +define+Conv +define+SDF
