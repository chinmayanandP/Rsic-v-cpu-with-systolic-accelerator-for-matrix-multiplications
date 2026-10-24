#!/usr/bin/env python3
"""
JPEG Decoder Implementation

Copyright (c) 2025 BRlin-o
Licensed under the MIT License - see LICENSE file for details.

A modular JPEG decoder implementation that complements the encoder,
providing complete JPEG codec functionality.
"""

from abc import ABC, abstractmethod
import struct
import io
import numpy as np
import cv2
import os
from pathlib import Path
from collections import namedtuple

from utils.constants import fileDtype, valueDtype
from utils.dct import IDCT
from utils.quantization import Dequantize

class JPEGError(Exception):
    """JPEG decoder specific exception"""
    pass

class ColorComponent:
    """Color component information from SOF segment"""
    def __init__(self, id, hscale, vscale, q_table_index):
        self.id = id
        self.hscale = hscale
        self.vscale = vscale
        self.q_table_index = q_table_index
        self.q_table = None  # Will be set after quantization tables are loaded

class ScanComponent:
    """Scan component information from SOS segment"""
    def __init__(self, color_component, dc_entropy, ac_entropy):
        self.color_component = color_component
        self.dc_entropy = dc_entropy
        self.ac_entropy = ac_entropy

class HuffmanDecoder:
    """Huffman decoder for DC and AC coefficients"""
    def __init__(self):
        self.codes = {}  # Maps binary code strings to values
        
    def add_code(self, code_val, code_len, symbol):
        """Add a Huffman code to the decoder"""
        code_str = format(code_val, f'0{code_len}b')
        self.codes[code_str] = symbol
        
    def decode_from(self, bitstream, category=False):
        """Decode a symbol from the bitstream"""
        code = ""
        while True:
            bit = bitstream.read(1)
            if not bit:
                raise JPEGError("Unexpected end of bitstream")
            code += bit.decode('ascii')
            
            if code in self.codes:
                symbol = self.codes[code]
                if category:
                    return symbol
                else:
                    return symbol
                    
            # Prevent infinite loop if code not found
            if len(code) > 16:
                raise JPEGError(f"Invalid Huffman code: {code}")

class DecoderBase(ABC):
    """Abstract base class for JPEG decoder"""
    def __init__(self, DEBUG=False):
        self.DEBUG = DEBUG

    @abstractmethod
    def decode(self, jpeg_path):
        pass

class JPEGDecoder(DecoderBase):
    """JPEG Decoder implementation"""
    
    # JPEG markers
    MARKERS = {
        'SOI': 0xD8,    # Start of Image
        'APP0': 0xE0,   # Application Default Header
        'DQT': 0xDB,    # Quantization Table
        'SOF0': 0xC0,   # Start of Frame
        'DHT': 0xC4,    # Define Huffman Table
        'SOS': 0xDA,    # Start of Scan
        'EOI': 0xD9,    # End of Image
    }
    
    # Zigzag order for 8x8 blocks
    ZIGZAG_ORDER = np.array([
        [ 0,  1,  5,  6, 14, 15, 27, 28],
        [ 2,  4,  7, 13, 16, 26, 29, 42],
        [ 3,  8, 12, 17, 25, 30, 41, 43],
        [ 9, 11, 18, 24, 31, 40, 44, 53],
        [10, 19, 23, 32, 39, 45, 52, 54],
        [20, 22, 33, 38, 46, 51, 55, 60],
        [21, 34, 37, 47, 50, 56, 59, 61],
        [35, 36, 48, 49, 57, 58, 62, 63]
    ])

    def __init__(self, jpeg_path=None, DEBUG=False):
        super().__init__(DEBUG)
        self.reset()
        if jpeg_path:
            self.decode(jpeg_path)

    def reset(self):
        """Reset decoder state"""
        self.file_handle = None
        self.height = 0
        self.width = 0
        self.quantization_tables = {}
        self.color_components = {}
        self.dc_huffman_tables = {}
        self.ac_huffman_tables = {}
        self.decoded_image = None

    def decode(self, jpeg_path):
        """Main decode function"""
        try:
            with open(jpeg_path, 'rb') as f:
                self.file_handle = f
                self._decode_file()
            return self.decoded_image
        except Exception as e:
            raise JPEGError(f"Failed to decode JPEG file: {e}")

    def _decode_file(self):
        """Process JPEG file segments"""
        while True:
            marker = self._read_marker()
            if not marker:
                break
                
            if self.DEBUG:
                print(f"Processing marker: 0x{marker:02X}")
                
            if marker == self.MARKERS['SOI']:
                if self.DEBUG:
                    print("Start of Image")
                continue
                
            elif marker == self.MARKERS['APP0']:
                self._skip_app0()
                
            elif marker == self.MARKERS['DQT']:
                self._read_quantization_table()
                
            elif marker == self.MARKERS['SOF0']:
                self._read_start_of_frame()
                
            elif marker == self.MARKERS['DHT']:
                self._read_huffman_table()
                
            elif marker == self.MARKERS['SOS']:
                self._read_start_of_scan()
                break  # Image data follows
                
            elif marker == self.MARKERS['EOI']:
                if self.DEBUG:
                    print("End of Image")
                break
                
            else:
                if self.DEBUG:
                    print(f"Unknown marker: 0x{marker:02X}")
                self._skip_segment()

    def _read_marker(self):
        """Read next marker from file"""
        marker_bytes = self.file_handle.read(2)
        if len(marker_bytes) != 2:
            return None
            
        if marker_bytes[0] != 0xFF:
            raise JPEGError("Invalid marker format")
            
        return marker_bytes[1]

    def _read_length(self):
        """Read segment length"""
        length_bytes = self.file_handle.read(2)
        if len(length_bytes) != 2:
            raise JPEGError("Unexpected end of file reading length")
        return int.from_bytes(length_bytes, 'big')

    def _skip_app0(self):
        """Skip APP0 segment"""
        length = self._read_length()
        self.file_handle.read(length - 2)

    def _skip_segment(self):
        """Skip unknown segment"""
        length = self._read_length()
        self.file_handle.read(length - 2)

    def _read_quantization_table(self):
        """Read quantization table"""
        length = self._read_length()
        data = self.file_handle.read(length - 2)
        
        if len(data) % 65 != 0:
            raise JPEGError("Invalid DQT length")
            
        for i in range(0, len(data), 65):
            table_info = data[i]
            precision = table_info >> 4
            table_id = table_info & 0x0F
            
            if precision != 0:
                raise JPEGError("Only 8-bit quantization tables supported")
                
            # Read 64 quantization values
            q_values = list(data[i+1:i+65])
            
            # Convert to 8x8 matrix in zigzag order
            q_table = np.zeros((8, 8), dtype=np.int32)
            for j, val in enumerate(q_values):
                row, col = np.where(self.ZIGZAG_ORDER == j)
                q_table[row[0], col[0]] = val
                
            self.quantization_tables[table_id] = q_table
            
            if self.DEBUG:
                print(f"Quantization table {table_id} loaded")

    def _read_start_of_frame(self):
        """Read Start of Frame segment"""
        length = self._read_length()
        data = self.file_handle.read(length - 2)
        
        if len(data) < 6:
            raise JPEGError("SOF too short")
            
        precision = data[0]
        if precision != 8:
            raise JPEGError("Only 8-bit precision supported")
            
        self.height = int.from_bytes(data[1:3], 'big')
        self.width = int.from_bytes(data[3:5], 'big')
        num_components = data[5]
        
        if self.DEBUG:
            print(f"Image size: {self.width} x {self.height}")
            print(f"Components: {num_components}")
            
        # Read component information
        for i in range(num_components):
            comp_data = data[6 + 3*i:6 + 3*(i+1)]
            comp_id = comp_data[0]
            sampling = comp_data[1]
            hscale = sampling >> 4
            vscale = sampling & 0x0F
            q_table_index = comp_data[2]
            
            component = ColorComponent(comp_id, hscale, vscale, q_table_index)
            component.q_table = self.quantization_tables[q_table_index]
            self.color_components[comp_id] = component
            
            if self.DEBUG:
                print(f"Component {comp_id}: h={hscale}, v={vscale}, q_table={q_table_index}")

    def _read_huffman_table(self):
        """Read Huffman table"""
        length = self._read_length()
        data = self.file_handle.read(length - 2)
        
        if len(data) < 17:
            raise JPEGError("DHT too short")
            
        table_info = data[0]
        is_ac = (table_info >> 4) & 1
        table_id = table_info & 0x0F
        
        if self.DEBUG:
            print(f"Huffman table: {'AC' if is_ac else 'DC'} table {table_id}")
            
        # Read number of codes for each length
        num_codes = list(data[1:17])
        
        # Create decoder
        decoder = HuffmanDecoder()
        
        # Read symbols and build codes
        code_val = 0
        data_ptr = 17
        
        for code_len, num_symbols in enumerate(num_codes, 1):
            for _ in range(num_symbols):
                symbol = data[data_ptr]
                decoder.add_code(code_val, code_len, symbol)
                data_ptr += 1
                code_val += 1
            code_val <<= 1
            
        # Store decoder
        if is_ac:
            self.ac_huffman_tables[table_id] = decoder
        else:
            self.dc_huffman_tables[table_id] = decoder

    def _read_start_of_scan(self):
        """Read Start of Scan segment and decode image data"""
        length = self._read_length()
        data = self.file_handle.read(length - 2)
        
        num_components = data[0]
        scan_components = []
        
        for i in range(num_components):
            comp_id = data[1 + 2*i]
            huffman_tables = data[1 + 2*i + 1]
            dc_table = huffman_tables >> 4
            ac_table = huffman_tables & 0x0F
            
            color_comp = self.color_components[comp_id]
            dc_huffman = self.dc_huffman_tables[dc_table]
            ac_huffman = self.ac_huffman_tables[ac_table]
            
            scan_component = ScanComponent(color_comp, dc_huffman, ac_huffman)
            scan_components.append(scan_component)
            
            if self.DEBUG:
                print(f"Scan component {comp_id}: DC={dc_table}, AC={ac_table}")
        
        # Read compressed image data
        self._decode_image_data(scan_components)

    def _decode_image_data(self, scan_components):
        """Decode the actual image data"""
        # Read entropy coded data until EOI or end of file
        entropy_data = self._read_entropy_data()
        
        # Create bitstream
        bitstream = io.BytesIO()
        for byte in entropy_data:
            bitstream.write(format(byte, '08b').encode())
        bitstream.seek(0)
        
        # Decode MCUs
        freq_domain_data = self._decode_mcus(bitstream, scan_components)
        
        # Dequantize
        dequantized_data = self._dequantize(freq_domain_data, scan_components)
        
        # IDCT
        spatial_data = self._inverse_dct(dequantized_data)
        
        # Color space conversion
        self.decoded_image = self._convert_color_space(spatial_data, scan_components)

    def _read_entropy_data(self):
        """Read entropy coded data, handling byte stuffing"""
        entropy_data = []
        
        while True:
            byte = self.file_handle.read(1)
            if not byte:
                break
                
            if byte[0] == 0xFF:
                next_byte = self.file_handle.read(1)
                if not next_byte:
                    break
                if next_byte[0] == 0x00:
                    # Byte stuffing - 0xFF 0x00 becomes 0xFF
                    entropy_data.append(0xFF)
                else:
                    # Found a marker, put it back and stop
                    self.file_handle.seek(-2, 1)
                    break
            else:
                entropy_data.append(byte[0])
                
        return entropy_data

    def _decode_mcus(self, bitstream, scan_components):
        """Decode MCUs from bitstream"""
        # Calculate MCU dimensions
        max_h_scale = max(comp.color_component.hscale for comp in scan_components)
        max_v_scale = max(comp.color_component.vscale for comp in scan_components)
        
        mcu_width = max_h_scale * 8
        mcu_height = max_v_scale * 8
        
        mcus_h = (self.width + mcu_width - 1) // mcu_width
        mcus_v = (self.height + mcu_height - 1) // mcu_height
        
        if self.DEBUG:
            print(f"MCU size: {mcu_width} x {mcu_height}")
            print(f"MCUs: {mcus_h} x {mcus_v}")
        
        # Initialize output array
        if len(scan_components) == 1:
            # Grayscale
            output_shape = (mcus_v * mcu_height, mcus_h * mcu_width)
        else:
            # Color
            output_shape = (mcus_v * mcu_height, mcus_h * mcu_width, len(scan_components))
            
        freq_data = np.zeros(output_shape, dtype=np.int32)
        
        # Track DC coefficients for DPCM
        last_dc = {comp.color_component.id: 0 for comp in scan_components}
        
        # Decode each MCU
        for mcu_y in range(mcus_v):
            for mcu_x in range(mcus_h):
                for comp_idx, component in enumerate(scan_components):
                    # Decode blocks for this component in the MCU
                    for block_y in range(component.color_component.vscale):
                        for block_x in range(component.color_component.hscale):
                            block = self._decode_block(bitstream, component, last_dc)
                            
                            # Place block in output array
                            y_start = mcu_y * mcu_height + block_y * 8
                            x_start = mcu_x * mcu_width + block_x * 8
                            
                            if len(scan_components) == 1:
                                freq_data[y_start:y_start+8, x_start:x_start+8] = block
                            else:
                                freq_data[y_start:y_start+8, x_start:x_start+8, comp_idx] = block
        
        # Crop to actual image size
        if len(scan_components) == 1:
            return freq_data[:self.height, :self.width]
        else:
            return freq_data[:self.height, :self.width, :]

    def _decode_block(self, bitstream, component, last_dc):
        """Decode a single 8x8 block"""
        # Decode DC coefficient
        dc_category = component.dc_entropy.decode_from(bitstream)
        dc_bits = self._read_bits(bitstream, dc_category)
        dc_value = self._decode_magnitude(dc_bits) if dc_category > 0 else 0
        
        # DPCM decoding
        dc_value += last_dc[component.color_component.id]
        last_dc[component.color_component.id] = dc_value
        
        # Initialize block
        block_coeffs = [dc_value] + [0] * 63
        
        # Decode AC coefficients
        ac_index = 1
        while ac_index < 64:
            ac_symbol = component.ac_entropy.decode_from(bitstream, category=True)
            
            # End of block
            if ac_symbol == 0x00:
                break
                
            # Extract run and size
            run_length = ac_symbol >> 4
            ac_category = ac_symbol & 0x0F
            
            # Skip zeros
            ac_index += run_length
            
            if ac_index >= 64:
                break
                
            # Read AC value
            if ac_category > 0:
                ac_bits = self._read_bits(bitstream, ac_category)
                ac_value = self._decode_magnitude(ac_bits)
                block_coeffs[ac_index] = ac_value
                
            ac_index += 1
        
        # Convert from zigzag order to 8x8 block
        block = np.zeros((8, 8), dtype=np.int32)
        for i, coeff in enumerate(block_coeffs):
            row, col = np.where(self.ZIGZAG_ORDER == i)
            if len(row) > 0:
                block[row[0], col[0]] = coeff
                
        return block

    def _read_bits(self, bitstream, num_bits):
        """Read specified number of bits from bitstream"""
        if num_bits == 0:
            return ""
        bits = bitstream.read(num_bits)
        if len(bits) != num_bits:
            raise JPEGError("Unexpected end of bitstream")
        return bits.decode('ascii')

    def _decode_magnitude(self, bit_string):
        """Decode magnitude from bit string"""
        if not bit_string:
            return 0
            
        value = int(bit_string, 2)
        
        # If first bit is 0, it's negative
        if bit_string[0] == '0':
            value = value - (1 << len(bit_string)) + 1
            
        return value

    def _dequantize(self, freq_data, scan_components):
        """Apply inverse quantization"""
        if freq_data.ndim == 2:
            # Grayscale
            component = scan_components[0]
            return Dequantize(freq_data, component.color_component.q_table)
        else:
            # Color
            dequant_data = np.zeros_like(freq_data, dtype=valueDtype)
            for i, component in enumerate(scan_components):
                dequant_data[:, :, i] = Dequantize(freq_data[:, :, i], component.color_component.q_table)
            return dequant_data

    def _inverse_dct(self, dequant_data):
        """Apply inverse DCT"""
        return IDCT(dequant_data)

    def _convert_color_space(self, spatial_data, scan_components):
        """Convert from YCbCr to RGB"""
        if len(scan_components) == 1:
            # Grayscale - just clip to valid range
            return np.clip(spatial_data, 0, 255).astype(np.uint8)
        else:
            # Color - convert YCbCr to RGB
            Y = spatial_data[:, :, 0]
            Cb = spatial_data[:, :, 1]
            Cr = spatial_data[:, :, 2]
            
            R = Y + 1.402 * Cr
            G = Y - 0.34414 * Cb - 0.71414 * Cr
            B = Y + 1.772 * Cb
            
            rgb = np.dstack((R, G, B))
            return np.clip(rgb, 0, 255).astype(np.uint8)


# Usage example
if __name__ == "__main__":
    # Test the decoder
    decoder = JPEGDecoder("./output/baboon_Q70.jpg", DEBUG=True)
    if decoder.decoded_image is not None:
        print(f"Successfully decoded image: {decoder.decoded_image.shape}")
        
        # Optional: save or display the image
        try:
            import matplotlib.pyplot as plt
            if decoder.decoded_image.ndim == 3:
                plt.imshow(decoder.decoded_image)
            else:
                plt.imshow(decoder.decoded_image, cmap='gray')
            plt.title("Decoded JPEG Image")
            plt.axis('off')
            plt.show()
        except ImportError:
            print("matplotlib not available, cannot display image")
    else:
        print("Failed to decode image")
