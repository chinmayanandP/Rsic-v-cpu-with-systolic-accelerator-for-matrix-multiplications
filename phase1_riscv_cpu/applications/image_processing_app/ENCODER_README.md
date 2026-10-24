# JPEG Encoder Implementation

這是一個基於模組化設計的 JPEG 編碼器實現，採用清晰的架構和可擴展的設計模式。

## 功能特點

- 完整的 JPEG 編碼支持
- 支持彩色和灰階圖像編碼
- 可調節的品質參數 (1-100)
- 模組化設計，易於擴展和維護
- 支持標準和優化的霍夫曼編碼
- 自動文件管理和路徑處理

## 使用方法

### 基本使用

```python
from encoder import JPEGEncoder

# 編碼彩色圖像
encoder = JPEGEncoder("path/to/image.tiff")
file_data = encoder.encode(quality=70, to_gray=False)

# 編碼為灰階圖像
encoder = JPEGEncoder("path/to/image.tiff")
file_data = encoder.encode(quality=70, to_gray=True)
```

### 自定義保存路徑

```python
encoder = JPEGEncoder("input.tiff")
file_data = encoder.encode(
    quality=90, 
    save_path="custom_output.jpg",
    to_gray=False
)
```

### 不同霍夫曼編碼類型

```python
# 使用標準霍夫曼表（默認）
file_data = encoder.encode(quality=70, huffman_type="standard")

# 使用優化霍夫曼表（未來支持）
file_data = encoder.encode(quality=70, huffman_type="optimized")
```

## 架構說明

### 主要類別

1. **JPEGEncoder**: 主要的編碼器類別
2. **EncoderBase**: 抽象基類，定義編碼器接口
3. **ColorComponent**: 顏色組件配置
4. **JPEGFileWriter**: JPEG 文件寫入器

### 編碼流程

1. **圖像載入**: 支持多種圖像格式
   ```python
   self.load_image(image_path)
   ```

2. **顏色空間轉換**: RGB/Gray → YCbCr
   ```python
   self.ycbcr = self.img2ycbcr(self.image, to_gray)
   ```

3. **離散餘弦變換 (DCT)**
   ```python
   self.fdct = FDCT(self.ycbcr, self.block_size)
   ```

4. **量化**
   ```python
   self.quantized = Quantize(self.fdct, self.QuantizationTable)
   ```

5. **Zigzag 掃描**
   ```python
   self.zigzaged = Zigzag(self.quantized, self.block_size)
   ```

6. **最小編碼單元 (MCU) 生成**
   ```python
   self.MCUs = self.getMCU(self.zigzaged)
   ```

7. **霍夫曼編碼**
   ```python
   self.encodedBitstream = self.encodingMCUs(self.MCUs)
   ```

8. **文件寫入**
   ```python
   self.save_encoded_image(save_path)
   ```

## 支持的編碼特性

- ✅ 基線 JPEG (Baseline JPEG)
- ✅ 8 位精度
- ✅ YCbCr 和灰階顏色空間
- ✅ 標準霍夫曼編碼
- ✅ 可調節品質參數 (1-100)
- ✅ 1:1 採樣比
- ✅ 自動量化表生成
- ❌ 漸進式 JPEG (規劃中)
- ❌ 算術編碼 (規劃中)
- ❌ 色度二次採樣 (規劃中)

## 模組化組件

### 核心工具模組

1. **color_transforms.py**: 顏色空間轉換
   - `RGB2YCbCr()`: RGB 到 YCbCr 轉換
   - `Gray2YCbCr()`: 灰階到 YCbCr 轉換

2. **dct.py**: 離散餘弦變換
   - `FDCT()`: 前向 DCT
   - `IDCT()`: 逆向 DCT

3. **quantization.py**: 量化處理
   - `getQuantizationTable()`: 生成量化表
   - `Quantize()`: 量化操作
   - `Dequantize()`: 反量化操作

4. **zigzag.py**: Zigzag 掃描
   - `Zigzag()`: Zigzag 掃描
   - `Zigzag1Block()`: 單塊 Zigzag 掃描

5. **jpeg_helpers.py**: JPEG 輔助函數
   - `binaryCode()`: 二進制編碼
   - `EntropyCoding()`: 熵編碼
   - `HuffmanTable2FileStructure()`: 霍夫曼表格式轉換

6. **huffman/**: 霍夫曼編碼模組
   - `standard.py`: 標準霍夫曼表
   - `optimized.py`: 優化霍夫曼表（未來）
   - `huffman_tree_interface.py`: 霍夫曼樹接口

## 文件格式支持

### 輸入格式
- TIFF
- PNG
- BMP
- JPEG
- 其他 imageio 支持的格式

### 輸出格式
- JPEG (.jpg)

## 品質參數

品質參數範圍：1-100
- **1-50**: 高壓縮率，較低品質
- **51-75**: 平衡壓縮率和品質
- **76-100**: 低壓縮率，高品質

品質參數影響量化表的縮放：
```python
if quality < 50:
    qualityScale = 5000 / quality
else:
    qualityScale = 200 - quality * 2
```

## 配置選項

### 顏色組件配置

```python
# 灰階模式
self.color_components = [
    ColorComponent(1, 1, 1, 0, 0, 0)
]

# 彩色模式
self.color_components = [
    ColorComponent(1, 1, 1, 0, 0, 0),  # Y 組件
    ColorComponent(2, 1, 1, 1, 1, 1),  # Cb 組件
    ColorComponent(3, 1, 1, 1, 1, 1)   # Cr 組件
]
```

### 霍夫曼表配置

```python
# DC 表
self.HuffmanTable["DC"][0] = transfor2CATCodeword(
    StandardHuffmanTree("LUMIN_DC").generate_codes()
)

# AC 表
self.HuffmanTable["AC"][0] = transfor2CATCodeword(
    StandardHuffmanTree("LUMIN_AC").generate_codes()
)
```

## 性能特性

- **內存效率**: 使用 numpy 陣列進行高效運算
- **處理速度**: OpenCV DCT 實現提供最佳性能
- **文件大小**: 可調節的品質參數實現靈活的壓縮比
- **兼容性**: 生成的 JPEG 文件符合標準，可被所有解碼器讀取

## 輸出文件命名

默認命名規則：
```
{原始文件名}_{灰階後綴}_Q{品質}.jpg
```

範例：
- `baboon_Q70.jpg` (彩色，品質 70)
- `baboon_toGray_Q70.jpg` (灰階，品質 70)

## 錯誤處理

編碼器會在以下情況進行適當處理：
- 自動創建輸出目錄
- 圖像尺寸調整至 8 的倍數
- 不支持的圖像格式提示
- 內存不足時的優雅降級

## 與原始 _JPEG 實現的比較

### 改進之處

1. **模組化設計**: 
   - 功能分散到獨立模組
   - 更好的代碼重用性
   - 易於測試和維護

2. **類別架構**:
   - 使用抽象基類定義接口
   - 清晰的職責分離
   - 可擴展的設計模式

3. **配置管理**:
   - 結構化的組件配置
   - 靈活的參數設置
   - 類型安全的實現

4. **文件處理**:
   - 專門的文件寫入器類別
   - 自動路徑管理
   - 更好的錯誤處理

### 保持兼容性

- 相同的編碼算法和標準
- 兼容的輸出格式
- 一致的品質參數效果

## 依賴項

```
numpy>=1.20.0
opencv-python>=4.5.0
imageio>=2.9.0
pathlib  # Python 標準庫
struct   # Python 標準庫
io       # Python 標準庫
```

## 安裝和使用

```bash
# 安裝依賴
pip install numpy opencv-python imageio

# 使用範例
python encoder.py
```

## 測試

```bash
# 基本編碼測試
python -c "from encoder import JPEGEncoder; encoder = JPEGEncoder('./datasets/baboon.tiff'); encoder.encode(70)"

# 完整測試套件
python test_complete.py
```

## 未來擴展

1. **漸進式 JPEG 支持**
2. **色度二次採樣**
3. **優化霍夫曼編碼**
4. **並行處理**
5. **更多輸入格式支持**
6. **批量處理功能**

## 貢獻指南

歡迎貢獻代碼！請遵循以下原則：
- 保持模組化設計
- 添加適當的測試
- 更新相關文檔
- 遵循現有的代碼風格
