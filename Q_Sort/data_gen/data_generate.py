from tempfile import tempdir
import numpy as np

### modify (base, n) by yourself
base = 32 # 0     # base >=0
n = 224 # 256      # 0< base+n <=256

print("base ", base, ", n ", n, sep = "")

def getbin(x, n_bit):
    if(x>=0):
        return format(x,'b').zfill(n_bit)
    else:
        return format(2**n_bit-abs(x), 'b').zfill(n_bit)
def gethex(x):
    if(x>=0):
        return '{:<2x}'.format(x).zfill(8)
    else:
        return '{:<2x}'.format(2**32-abs(x))
    
    
## golden petern generator
data = np.load('data.npy')
data_sorted = data.copy()
data_sorted[base:base+n] = np.sort(data[base:base+n])
counter = 0
f_gold_path = 'D_gold'
f_out = open(f_gold_path, 'w')
for i in range(len(data)):
    data_in = data_sorted[i]
    code = gethex(data_in)
    out_string = '{}_{}_{}_{}   // 0x{:<3x}   {:>7d}   {}\n'.format(code[6:8],code[4:6],code[2:4],code[0:2], counter, data_in, code)
    f_out.writelines(out_string)
    counter = counter+4
f_out.close()



## RISC-v code generator
m_b = {'line':    4,
       'ps_code': 119,
       'code':    '00000000101100010011'}
m_n = {'line':    5,
       'ps_code': 120,
       'code':    '00000000101110010011'}

with open('I_mem') as f:
    lines = f.readlines()
f_out = open('I_mem', 'w')
for i in range(len(lines)):
    if(i==m_b['line']):
        temp_out = '{:02X}'.format( int( getbin(base,12)+m_b['code'], 2 ) ).zfill(8)
        outline = '{}_{}_{}_{}   // 0x10 \n'.format(temp_out[6:8],temp_out[4:6],temp_out[2:4],temp_out[0:2])
    elif(i==m_b['ps_code']):
        temp_out = '{:02X}'.format( int( getbin(base,12)+m_b['code'], 2 ) ).zfill(8)
        outline = '//  {}   # 0x10    addi s6, x0, {:<3d}    # location of array\n'.format(temp_out, base)
    elif(i==m_n['line']):
        temp_out = '{:02X}'.format( int( getbin(n,12)+m_n['code'], 2 ) ).zfill(8)
        outline = '{}_{}_{}_{}   // 0x14 \n'.format(temp_out[6:8],temp_out[4:6],temp_out[2:4],temp_out[0:2])
    elif(i==m_n['ps_code']):
        temp_out = '{:02X}'.format( int( getbin(n,12)+m_n['code'], 2 ) ).zfill(8)
        outline = '//  {}   # 0x14    addi s7, x0, {:<3d}    # n: total number to be sorted\n'.format(temp_out, n)
    else:
        outline = lines[i]
    f_out.writelines(outline)
f_out.close()




m_b = {'line':    3,
       'ps_code': 95,
       'code':    '00000000101100010011'}
m_n = {'line':    4,
       'ps_code': 96,
       'code':    '00000000101110010011'}

with open('I_mem_compression') as f:
    lines = f.readlines()
f_out = open('I_mem_compression', 'w')
for i in range(len(lines)):
    if(i==m_b['line']):
        temp_out = '{:02X}'.format( int( getbin(base,12)+m_b['code'], 2 ) ).zfill(8)
        outline = '{}_{}_{}_{}   // 0x10 \n'.format(temp_out[6:8],temp_out[4:6],temp_out[2:4],temp_out[0:2])
    elif(i==m_b['ps_code']):
        temp_out = '{:02X}'.format( int( getbin(base,12)+m_b['code'], 2 ) ).zfill(8)
        outline = '// {}   # 0x10    addi s6, x0, {:<3d}      # location of array\n'.format(temp_out, base)
    elif(i==m_n['line']):
        temp_out = '{:02X}'.format( int( getbin(n,12)+m_n['code'], 2 ) ).zfill(8)
        outline = '{}_{}_{}_{}   // 0x14 \n'.format(temp_out[6:8],temp_out[4:6],temp_out[2:4],temp_out[0:2])
    elif(i==m_n['ps_code']):
        temp_out = '{:02X}'.format( int( getbin(n,12)+m_n['code'], 2 ) ).zfill(8)
        outline = '// {}   # 0x14    addi s7, x0, {:<3d}      # n: total number to be sorted\n'.format(temp_out, n)
    else:
        outline = lines[i]
    f_out.writelines(outline)
f_out.close()