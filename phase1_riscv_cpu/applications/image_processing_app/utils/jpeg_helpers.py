import re
import numpy as np

def binaryCode(x):
    if x == 0:
        return 0, ""
    vli = binaryCodeLength(abs(x))
    if x > 0:
        return vli, np.binary_repr(x, vli)
    else:  # x < 0
        complement = 2**vli - 1 + x
        return vli, np.binary_repr(complement, vli)

def binaryCodeLength(n):
    if n<2:
        return 1
    else:
        return np.floor(np.log2(n)+1).astype(np.uint8)

def EntropyCoding(Bitstream):
    codelen=8
    perfect_len = (len(Bitstream)+codelen-1) // codelen
    perfect_code = Bitstream + '1'*(perfect_len*codelen-len(Bitstream))
    split_perfect_code = re.findall(r".{8}", perfect_code)
    ECS = []
    for code in split_perfect_code:
        ECS.append(code)
        if code == "1"*8:
            ECS.append("0"*8)
    return ECS

def HuffmanTable2FileStructure(huffmanTable, DEBUG=False):
    bitsCount = np.zeros((16), dtype=np.uint8)
    sorted_table = dict(sorted(huffmanTable.items(), key=lambda x: (len(x[0]), x[0])))
    if DEBUG:
        print("[DEBUG] sorted_table")
        print(sorted_table)
    codes = [[] for i in range(16)]
    for code in sorted_table.items():
        if DEBUG:
            print("val={}, code={}, len={}".format(code[1], code[0], len(code[0])))
        bitsCount[len(code[0])-1] += 1
        hexCode = int(code[1], 16)
        codes[len(code[0])-1].append(hexCode)
    return bitsCount, codes

def transfor2CodewordCAT(cat_huffman_table):
    """Transform Category -> Codeword dictionary to Codeword -> Category dictionary"""
    ht = {}
    for Category, Codeword_list in cat_huffman_table.items():
        for codeword in Codeword_list:
            ht[codeword] = Category
    return ht

def transfor2CATCodeword(cw_huffman_table): 
    """Transform Codeword -> Category dictionary to Category -> Codeword list dictionary"""
    ht = {}
    for Codeword, Category in cw_huffman_table.items():
        if Category in ht:
            ht[Category].append(Codeword)
        else:
            ht[Category] = [Codeword]
    return ht
