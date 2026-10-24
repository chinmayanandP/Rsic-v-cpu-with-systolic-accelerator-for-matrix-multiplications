import numpy as np

def Zigzag1Block_indexList(n):
    index_list = np.array([])
    for i in range(n):
        indexs = np.zeros((i+1, 2), dtype=np.uint8)
        indexs[:, 0] = np.arange(i+1) if i % 2 else np.arange(i+1)[::-1]
        indexs[:, 1] = indexs[::-1, 0]
        try:
            index_list = np.concatenate((index_list, indexs))
        except:
            index_list = indexs
    for i in list(reversed(range(n-1))):
        indexs = np.zeros((i+1, 2), dtype=np.uint8)
        indexs[:, 1] = (np.arange(i+1)+n-1-i) if i % 2 == 0 else (np.arange(i+1)+n-1-i)[::-1]
        indexs[:, 0] = indexs[::-1, 1]
        index_list = np.concatenate((index_list, indexs))
    
    return index_list[:, 0] * n + index_list[:, 1]

def Zigzag1Block(block, block_size=8):
    index_list = Zigzag1Block_indexList(block_size)
    return np.array([np.array(block).flatten()])[:, index_list].flatten()

def Zigzag(img, block_size=8, showOutput=False):
    height, width = img.shape[:2]
    zigzag = []
    for i in range(0, height, block_size):
        for j in range(0, width, block_size):
            comp = []
            if img.ndim == 2:
                comp.append(Zigzag1Block(img[i:i+block_size,j:j+block_size]))
            else:
                for k in range(img.shape[2]):
                    comp.append(Zigzag1Block(img[i:i+block_size,j:j+block_size, k]))
            zigzag.append(comp)
    zigzag = np.array(zigzag)
    if showOutput:
        print("[ShowOutput] Zigzag: shape=", zigzag.shape)
        print("\t", zigzag)
    return zigzag

# def Zigzag(img, block_size=8, showOutput=False):
#     height, width = img.shape[:2]
#     zigzag = []
#     for i in range(0, height, block_size):
#         for j in range(0, width, block_size):
#             block = img[i:i+block_size, j:j+block_size]
#             if block.ndim == 2:
#                 block = block[:, :, np.newaxis]
#             block_zigzag = np.apply_along_axis(Zigzag1Block, axis=0, arr=block)
#             zigzag.append(block_zigzag.squeeze())

#     zigzag = np.array(zigzag)
#     if showOutput:
#         print("[ShowOutput] Zigzag: shape=", zigzag.shape)
#         print("\t", zigzag)
#     return zigzag
