def transfor2CATCodeword(cw_huffman_table): 
    ht = {}
    for Codeword, Category in cw_huffman_table.items():
        if Category in ht:
            ht[Category].append(Codeword)
        else:
            ht[Category] = [Codeword]
    return ht

def transfor2CodewordCAT(cat_huffman_table):
    ht = {}
    for Category, Codeword_list in cat_huffman_table.items():
        for codeword in Codeword_list:
            ht[codeword] = Category
    return ht
