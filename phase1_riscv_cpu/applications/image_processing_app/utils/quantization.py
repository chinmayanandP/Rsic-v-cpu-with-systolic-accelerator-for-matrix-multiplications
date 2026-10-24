import numpy as np
from .constants import fileDtype, valueDtype

def getQuantizationTable(quality=50):
    std_lumQT = np.array( ## Q_Y: 標準亮度量化表
        [[ 16,  11,  10,  16,  24,  40,  51,  61],
        [ 12,  12,  14,  19,  26,  58,  60,  55],
        [ 14,  13,  16,  24,  40,  57,  69,  56],
        [ 14,  17,  22,  29,  51,  87,  80,  62],
        [ 18,  22,  37,  56,  68, 109, 103,  77],
        [ 24,  35,  55,  64,  81, 104, 113,  92],
        [ 49,  64,  78,  87, 103, 121, 120, 101],
        [ 72,  92,  95,  98, 112, 100, 103,  99]], dtype=valueDtype)
    std_chrQT = np.array( ## Q_C: 標準色差量化表
        [[ 17,  18,  24,  47,  99,  99,  99,  99],
        [ 18,  21,  26,  66,  99,  99,  99,  99],
        [ 24,  26,  56,  99,  99,  99,  99,  99],
        [ 47,  66,  99,  99,  99,  99,  99,  99],
        [ 99,  99,  99,  99,  99,  99,  99,  99],
        [ 99,  99,  99,  99,  99,  99,  99,  99],
        [ 99,  99,  99,  99,  99,  99,  99,  99],
        [ 99,  99,  99,  99,  99,  99,  99,  99]], dtype=valueDtype)
            
    if(quality < 50):
        qualityScale = 5000 / quality
    else:
        qualityScale = 200 - quality * 2
            
    lumQT = np.array(np.floor((std_lumQT * qualityScale + 50) / 100))
    lumQT[lumQT == 0] = 1
    lumQT[lumQT > 255] = 255
    lumQT = lumQT.reshape([8, 8]).astype(fileDtype)
        
    chrQT = np.array(np.floor((std_chrQT * qualityScale + 50) / 100))
    chrQT[chrQT == 0] = 1
    chrQT[chrQT > 255] = 255
    chrQT = chrQT.reshape([8, 8]).astype(fileDtype)
            
    return lumQT,chrQT

def Quantize(img, qTable):
    _img = np.divide(img, np.tile(qTable, (img.shape[0] // 8, img.shape[1] // 8)))
    return np.round(_img).astype(np.int32)

def Dequantize(img, QuantizationTable):
    _img = np.round(img * np.tile(QuantizationTable, (img.shape[0] // 8, img.shape[1] // 8)))
    return _img
