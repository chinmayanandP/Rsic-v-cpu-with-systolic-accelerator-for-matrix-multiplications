#!/usr/bin/env python3
"""
Test script for JPEG decoder
"""

import sys
import os
from pathlib import Path

# Add the project root to the path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from decoder import JPEGDecoder

def test_decoder():
    """Test the JPEG decoder with available test images"""
    
    # Test images
    test_images = [
        "./output/baboon_Q70.jpg",
        "./output/baboon_toGray_Q70.jpg"
    ]
    
    for image_path in test_images:
        if not os.path.exists(image_path):
            print(f"Test image not found: {image_path}")
            continue
            
        print(f"\n=== Testing {image_path} ===")
        
        try:
            # Create decoder with debug output
            decoder = JPEGDecoder(DEBUG=True)
            
            # Decode the image
            decoded_image = decoder.decode(image_path)
            
            if decoded_image is not None:
                print(f"✓ Successfully decoded image")
                print(f"  - Shape: {decoded_image.shape}")
                print(f"  - Data type: {decoded_image.dtype}")
                print(f"  - Value range: [{decoded_image.min()}, {decoded_image.max()}]")
                
                # Optional: save decoded image as numpy array for verification
                import numpy as np
                output_name = f"decoded_{Path(image_path).stem}.npy"
                np.save(output_name, decoded_image)
                print(f"  - Saved as: {output_name}")
                
            else:
                print("✗ Failed to decode image")
                
        except Exception as e:
            print(f"✗ Error decoding {image_path}: {e}")
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    test_decoder()
