# JPEG Decoder Implementation

這是一個基於 `jpeg_codec` 架構的 JPEG 解碼器實現，參考了 `_JPEG` 項目中的解碼邏輯。

## 功能特點

- 完整的 JPEG 解碼支持
- 支持彩色和灰階圖像
- 模組化設計，易於擴展和維護
- 錯誤處理機制
- 符合 JPEG 標準的實現

## 使用方法

### 基本使用

```python
from decoder import JPEGDecoder

# 方法 1: 直接解碼
decoder = JPEGDecoder("path/to/image.jpg")
decoded_image = decoder.decoded_image

# 方法 2: 分步解碼
decoder = JPEGDecoder()
decoded_image = decoder.decode("path/to/image.jpg")
```

### 調試模式

```python
# 啟用調試模式以查看解碼過程
decoder = JPEGDecoder("path/to/image.jpg", DEBUG=True)
```

## 架構說明

### 主要類別

1. **JPEGDecoder**: 主要的解碼器類別
2. **HuffmanDecoder**: 霍夫曼解碼器
3. **ColorComponent**: 顏色組件信息
4. **ScanComponent**: 掃描組件信息
5. **JPEGError**: 自定義異常類別

### 解碼流程

1. **文件解析**: 解析 JPEG 文件的各個段（segments）
   - SOI (Start of Image)
   - APP0 (Application Header)
   - DQT (Quantization Tables)
   - SOF (Start of Frame)
   - DHT (Huffman Tables)
   - SOS (Start of Scan)
   - EOI (End of Image)

2. **熵解碼**: 使用霍夫曼表解碼壓縮數據

3. **反量化**: 恢復 DCT 係數

4. **逆 DCT**: 從頻域轉換到空域

5. **顏色空間轉換**: YCbCr 轉 RGB（如果是彩色圖像）

## 支持的 JPEG 特性

- ✅ 基線 JPEG (Baseline JPEG)
- ✅ 8 位精度
- ✅ YCbCr 和灰階顏色空間
- ✅ 標準霍夫曼編碼
- ✅ 1:1 採樣比（無色度二次採樣）
- ❌ 漸進式 JPEG (Progressive JPEG)
- ❌ 算術編碼
- ❌ 色度二次採樣

## 測試

項目包含多個測試文件：

```bash
# 基本功能測試
python test_decoder.py

# 簡化測試（無外部依賴）
python test_simple.py

# 完整編碼解碼測試（需要 imageio）
python test_complete.py
```

## 與原始 _JPEG 實現的差異

### 改進之處

1. **模組化設計**: 將功能分散到不同的工具模組
2. **更清晰的類別結構**: 使用抽象基類和明確的接口
3. **更好的錯誤處理**: 自定義異常和詳細的錯誤信息
4. **代碼組織**: 更清晰的文件結構和職責分離

### 保持兼容性

- 保留了原始實現的核心算法
- 支持相同的 JPEG 特性
- 輸出結果與原始實現一致

## 依賴項

- numpy
- opencv-python (cv2)
- pathlib (Python 標準庫)
- struct (Python 標準庫)
- io (Python 標準庫)

## 性能考慮

- 使用 numpy 進行高效的數值計算
- OpenCV 的 DCT/IDCT 實現提供良好的性能
- 內存使用經過優化，適合處理大圖像

## 錯誤處理

解碼器會在以下情況拋出 `JPEGError` 異常：

- 無效的文件格式
- 不支持的 JPEG 特性
- 損壞的文件數據
- 意外的文件結束

## 未來改進方向

1. 支持漸進式 JPEG
2. 支持色度二次採樣
3. 性能優化
4. 更多的 JPEG 標記支持
5. 更詳細的元數據提取
