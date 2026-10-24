#!/usr/bin/env python3
"""
JPEG 編解碼器使用範例

這個範例展示了如何使用 jpeg_codec 項目進行圖像的編碼和解碼。
"""

import sys
import os
from pathlib import Path
import numpy as np

# 添加項目根目錄到路徑
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

def example_basic_encoding():
    """基本編碼範例"""
    print("=== 基本編碼範例 ===")
    
    from encoder import JPEGEncoder
    
    # 檢查測試圖像是否存在
    test_image = "./datasets/baboon.tiff"
    if not os.path.exists(test_image):
        print(f"測試圖像不存在: {test_image}")
        return
    
    # 創建編碼器並編碼
    encoder = JPEGEncoder(test_image)
    
    # 編碼為不同品質的 JPEG
    qualities = [30, 70, 90]
    
    for quality in qualities:
        print(f"\n編碼品質 {quality}:")
        file_data = encoder.encode(quality=quality, to_gray=False)
        print(f"  保存路徑: {encoder.save_path}")
        print(f"  文件大小: {len(file_data)} bytes")
        
        # 計算壓縮比（需要原始文件大小）
        original_size = os.path.getsize(test_image)
        compression_ratio = original_size / len(file_data)
        print(f"  壓縮比: {compression_ratio:.2f}:1")

def example_basic_decoding():
    """基本解碼範例"""
    print("\n=== 基本解碼範例 ===")
    
    from decoder import JPEGDecoder
    
    # 檢查已編碼的 JPEG 文件
    test_files = [
        "./output/baboon_Q70.jpg",
        "./output/baboon_toGray_Q70.jpg"
    ]
    
    for jpeg_file in test_files:
        if not os.path.exists(jpeg_file):
            print(f"JPEG 文件不存在: {jpeg_file}")
            continue
            
        print(f"\n解碼文件: {jpeg_file}")
        
        # 創建解碼器並解碼
        decoder = JPEGDecoder(jpeg_file)
        decoded_image = decoder.decoded_image
        
        if decoded_image is not None:
            print(f"  解碼成功!")
            print(f"  圖像尺寸: {decoded_image.shape}")
            print(f"  數據類型: {decoded_image.dtype}")
            print(f"  數值範圍: [{decoded_image.min()}, {decoded_image.max()}]")
            
            # 保存解碼結果（可選）
            output_name = f"decoded_{Path(jpeg_file).stem}.npy"
            np.save(output_name, decoded_image)
            print(f"  已保存解碼結果: {output_name}")
        else:
            print("  解碼失敗!")

def example_complete_pipeline():
    """完整編解碼流程範例"""
    print("\n=== 完整編解碼流程範例 ===")
    
    from encoder import JPEGEncoder
    from decoder import JPEGDecoder
    
    test_image = "./datasets/baboon.tiff"
    if not os.path.exists(test_image):
        print(f"測試圖像不存在: {test_image}")
        return
    
    # 步驟 1: 編碼
    print("\n步驟 1: 編碼圖像")
    encoder = JPEGEncoder(test_image)
    file_data = encoder.encode(quality=75, to_gray=False)
    encoded_path = encoder.save_path
    print(f"  編碼完成: {encoded_path}")
    
    # 步驟 2: 解碼
    print("\n步驟 2: 解碼圖像")
    decoder = JPEGDecoder(encoded_path)
    decoded_image = decoder.decoded_image
    print(f"  解碼完成: {decoded_image.shape}")
    
    # 步驟 3: 品質評估（簡單）
    print("\n步驟 3: 品質評估")
    
    # 載入原始圖像進行比較（需要適當的庫）
    try:
        import imageio.v3 as iio
        original_image = np.array(iio.imread(test_image), dtype=np.uint8)
        
        # 計算 PSNR
        def calculate_psnr(original, reconstructed):
            mse = np.mean((original - reconstructed) ** 2)
            if mse == 0:
                return float('inf')
            max_pixel = 255.0
            psnr = 20 * np.log10(max_pixel / np.sqrt(mse))
            return psnr
        
        # 調整尺寸匹配（如果需要）
        if original_image.shape != decoded_image.shape:
            original_image = original_image[:decoded_image.shape[0], :decoded_image.shape[1]]
        
        psnr = calculate_psnr(original_image, decoded_image)
        print(f"  PSNR: {psnr:.2f} dB")
        
    except ImportError:
        print("  需要 imageio 庫來進行品質評估")
    except Exception as e:
        print(f"  品質評估出錯: {e}")

def example_grayscale_processing():
    """灰階圖像處理範例"""
    print("\n=== 灰階圖像處理範例 ===")
    
    from encoder import JPEGEncoder
    from decoder import JPEGDecoder
    
    test_image = "./datasets/baboon.tiff"
    if not os.path.exists(test_image):
        print(f"測試圖像不存在: {test_image}")
        return
    
    # 編碼為灰階
    print("編碼為灰階圖像:")
    encoder = JPEGEncoder(test_image)
    file_data = encoder.encode(quality=80, to_gray=True)
    print(f"  保存路徑: {encoder.save_path}")
    print(f"  文件大小: {len(file_data)} bytes")
    
    # 解碼灰階圖像
    print("\n解碼灰階圖像:")
    decoder = JPEGDecoder(encoder.save_path)
    decoded_gray = decoder.decoded_image
    print(f"  解碼尺寸: {decoded_gray.shape}")
    print(f"  這是 {'2D' if decoded_gray.ndim == 2 else '3D'} 陣列")

def example_quality_comparison():
    """不同品質比較範例"""
    print("\n=== 品質比較範例 ===")
    
    from encoder import JPEGEncoder
    
    test_image = "./datasets/baboon.tiff"
    if not os.path.exists(test_image):
        print(f"測試圖像不存在: {test_image}")
        return
    
    qualities = [10, 30, 50, 70, 90]
    print("品質\t文件大小\t壓縮比")
    print("-" * 30)
    
    original_size = os.path.getsize(test_image)
    
    for quality in qualities:
        encoder = JPEGEncoder(test_image)
        file_data = encoder.encode(quality=quality, to_gray=False)
        
        file_size = len(file_data)
        compression_ratio = original_size / file_size
        
        print(f"{quality}\t{file_size:,}\t\t{compression_ratio:.1f}:1")

def main():
    """主函數 - 運行所有範例"""
    print("JPEG 編解碼器使用範例")
    print("=" * 50)
    
    try:
        example_basic_encoding()
        example_basic_decoding()
        example_complete_pipeline()
        example_grayscale_processing()
        example_quality_comparison()
        
        print("\n" + "=" * 50)
        print("所有範例執行完成!")
        print("=" * 50)
        
    except Exception as e:
        print(f"範例執行出錯: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
