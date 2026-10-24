#!/usr/bin/env python3
"""
Simple test to verify the decoder implementation
"""

import sys
import os
import numpy as np
from pathlib import Path

# Add the project root to the path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from decoder import JPEGDecoder

def test_decoder_basic():
    """Basic decoder functionality test"""
    print("JPEG Decoder Basic Test")
    print("="*40)
    
    # Test with existing JPEG files
    test_files = [
        "./output/baboon_Q70.jpg",
        "./output/baboon_toGray_Q70.jpg"
    ]
    
    for jpeg_file in test_files:
        if not os.path.exists(jpeg_file):
            print(f"Test file not found: {jpeg_file}")
            continue
            
        print(f"\nTesting: {jpeg_file}")
        print("-" * 30)
        
        try:
            # Test basic decoding
            decoder = JPEGDecoder(DEBUG=False)
            decoded_image = decoder.decode(jpeg_file)
            
            if decoded_image is not None:
                print(f"✓ Decoding successful")
                print(f"  Shape: {decoded_image.shape}")
                print(f"  Data type: {decoded_image.dtype}")
                print(f"  Value range: [{decoded_image.min()}, {decoded_image.max()}]")
                
                # Check basic properties
                if decoded_image.dtype != np.uint8:
                    print("  ⚠ Warning: Expected uint8 data type")
                    
                if decoded_image.min() < 0 or decoded_image.max() > 255:
                    print("  ⚠ Warning: Values outside expected range [0, 255]")
                    
                # Test different instantiation methods
                decoder2 = JPEGDecoder(jpeg_file, DEBUG=False)
                if decoder2.decoded_image is not None:
                    print("✓ Direct instantiation works")
                else:
                    print("✗ Direct instantiation failed")
                    
            else:
                print("✗ Decoding failed")
                
        except Exception as e:
            print(f"✗ Error: {e}")
            import traceback
            traceback.print_exc()

def test_decoder_structure():
    """Test decoder class structure and methods"""
    print(f"\n{'='*40}")
    print("Testing Decoder Structure")
    print("="*40)
    
    # Test class instantiation
    try:
        decoder = JPEGDecoder(DEBUG=False)
        print("✓ Decoder instantiation successful")
        
        # Check required attributes
        required_attrs = [
            'height', 'width', 'quantization_tables', 
            'color_components', 'dc_huffman_tables', 
            'ac_huffman_tables', 'decoded_image'
        ]
        
        for attr in required_attrs:
            if hasattr(decoder, attr):
                print(f"✓ Has attribute: {attr}")
            else:
                print(f"✗ Missing attribute: {attr}")
                
        # Check required methods
        required_methods = [
            'decode', 'reset', '_decode_file', 
            '_read_marker', '_read_quantization_table',
            '_read_start_of_frame', '_read_huffman_table'
        ]
        
        for method in required_methods:
            if hasattr(decoder, method) and callable(getattr(decoder, method)):
                print(f"✓ Has method: {method}")
            else:
                print(f"✗ Missing method: {method}")
                
    except Exception as e:
        print(f"✗ Decoder instantiation failed: {e}")

def test_error_handling():
    """Test error handling capabilities"""
    print(f"\n{'='*40}")
    print("Testing Error Handling")
    print("="*40)
    
    decoder = JPEGDecoder(DEBUG=False)
    
    # Test with non-existent file
    try:
        result = decoder.decode("non_existent_file.jpg")
        print("✗ Should have failed for non-existent file")
    except Exception as e:
        print(f"✓ Correctly handled non-existent file: {type(e).__name__}")
    
    # Test with invalid file (if we can create one)
    try:
        # Create a fake JPEG file with invalid content
        with open("fake.jpg", "wb") as f:
            f.write(b"This is not a JPEG file")
        
        result = decoder.decode("fake.jpg")
        print("✗ Should have failed for invalid file")
        
    except Exception as e:
        print(f"✓ Correctly handled invalid file: {type(e).__name__}")
    finally:
        # Clean up
        if os.path.exists("fake.jpg"):
            os.remove("fake.jpg")

if __name__ == "__main__":
    test_decoder_basic()
    test_decoder_structure()
    test_error_handling()
    
    print(f"\n{'='*40}")
    print("All tests completed!")
    print("="*40)
