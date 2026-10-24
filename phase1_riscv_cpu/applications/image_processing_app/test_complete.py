#!/usr/bin/env python3
"""
Complete test script to verify JPEG encoder-decoder pair
"""

import sys
import os
import numpy as np
from pathlib import Path

# Add the project root to the path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from encoder import JPEGEncoder
from decoder import JPEGDecoder

def calculate_psnr(original, reconstructed):
    """Calculate PSNR between original and reconstructed images"""
    mse = np.mean((original - reconstructed) ** 2)
    if mse == 0:
        return float('inf')
    max_pixel = 255.0
    psnr = 20 * np.log10(max_pixel / np.sqrt(mse))
    return psnr

def test_encode_decode_cycle():
    """Test complete encode-decode cycle"""
    
    # Test with available datasets
    test_images = [
        "./datasets/baboon.tiff",
        "./datasets/Lena.tiff"
    ]
    
    qualities = [50, 70, 90]
    
    for image_path in test_images:
        if not os.path.exists(image_path):
            print(f"Test image not found: {image_path}")
            continue
            
        print(f"\n{'='*60}")
        print(f"Testing {Path(image_path).name}")
        print(f"{'='*60}")
        
        # Load original image
        import imageio.v3 as iio
        original_image = np.array(iio.imread(image_path), dtype=np.uint8)
        print(f"Original image shape: {original_image.shape}")
        
        for quality in qualities:
            print(f"\n--- Quality {quality} ---")
            
            # Test color image
            if original_image.ndim == 3:
                print("Testing color image...")
                
                try:
                    # Encode
                    encoder = JPEGEncoder(image_path)
                    file_data = encoder.encode(quality=quality, to_gray=False)
                    save_path = encoder.save_path
                    print(f"  Encoded to: {save_path}")
                    print(f"  File size: {len(file_data)} bytes")
                    
                    # Decode
                    decoder = JPEGDecoder()
                    decoded_image = decoder.decode(save_path)
                    print(f"  Decoded shape: {decoded_image.shape}")
                    
                    # Calculate PSNR
                    if decoded_image.shape == original_image.shape:
                        psnr = calculate_psnr(original_image, decoded_image)
                        print(f"  PSNR: {psnr:.2f} dB")
                    else:
                        print(f"  Shape mismatch: original {original_image.shape} vs decoded {decoded_image.shape}")
                        
                except Exception as e:
                    print(f"  ✗ Error in color test: {e}")
            
            # Test grayscale
            print("Testing grayscale image...")
            
            try:
                # Encode as grayscale
                encoder = JPEGEncoder(image_path)
                file_data = encoder.encode(quality=quality, to_gray=True)
                save_path = encoder.save_path
                print(f"  Encoded to: {save_path}")
                print(f"  File size: {len(file_data)} bytes")
                
                # Decode
                decoder = JPEGDecoder()
                decoded_image = decoder.decode(save_path)
                print(f"  Decoded shape: {decoded_image.shape}")
                
                # Compare with grayscale version of original
                if original_image.ndim == 3:
                    # Convert original to grayscale for comparison
                    gray_original = np.dot(original_image[...,:3], [0.299, 0.587, 0.114]).astype(np.uint8)
                else:
                    gray_original = original_image
                
                if decoded_image.shape == gray_original.shape:
                    psnr = calculate_psnr(gray_original, decoded_image)
                    print(f"  PSNR: {psnr:.2f} dB")
                else:
                    print(f"  Shape mismatch: original {gray_original.shape} vs decoded {decoded_image.shape}")
                    
            except Exception as e:
                print(f"  ✗ Error in grayscale test: {e}")

def test_compatibility_with_original():
    """Test compatibility with original _JPEG implementation"""
    print(f"\n{'='*60}")
    print("Testing compatibility with original _JPEG implementation")
    print(f"{'='*60}")
    
    # Check if we can decode images created by the original implementation
    original_outputs = [
        "../_JPEG/output/"  # Adjust path as needed
    ]
    
    for output_dir in original_outputs:
        if os.path.exists(output_dir):
            jpeg_files = list(Path(output_dir).glob("*.jpg"))
            for jpeg_file in jpeg_files[:3]:  # Test first 3 files
                print(f"\nTesting {jpeg_file.name}...")
                try:
                    decoder = JPEGDecoder()
                    decoded_image = decoder.decode(str(jpeg_file))
                    print(f"  ✓ Successfully decoded: {decoded_image.shape}")
                except Exception as e:
                    print(f"  ✗ Failed to decode: {e}")

if __name__ == "__main__":
    print("JPEG Encoder-Decoder Test Suite")
    print("This will test the complete encoding and decoding pipeline.")
    
    test_encode_decode_cycle()
    test_compatibility_with_original()
    
    print(f"\n{'='*60}")
    print("Test completed!")
    print(f"{'='*60}")
