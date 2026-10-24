#!/usr/bin/env python3
"""
JPEG Encoder Implementation

Copyright (c) 2025 BRlin-o
Licensed under the MIT License - see LICENSE file for details.

A modular JPEG encoder implementation based on the original _JPEG project,
with improved architecture and maintainability.
"""

from abc import ABC, abstractmethod
import struct
import io
import numpy as np
import cv2
import os
from pathlib import Path
import imageio.v3 as iio

from utils.constants import fileDtype, valueDtype
from utils.jpeg_helpers import binaryCode, transfor2CATCodeword, transfor2CodewordCAT, EntropyCoding, HuffmanTable2FileStructure
from utils.color_transforms import RGB2YCbCr, Gray2YCbCr
from utils.dct import FDCT
from utils.quantization import getQuantizationTable, Quantize
from utils.zigzag import Zigzag, Zigzag1Block
from utils.huffman.standard import StandardHuffmanTree
from utils.huffman.optimized import OptimizedHuffmanTree

class EncoderBase(ABC):
    def __init__(self, image_path=None, DEBUG=False):
        self.DEBUG = DEBUG
        self.init()

    @abstractmethod
    def init(self):
        pass

    @abstractmethod
    def encode(self, image_path, quality, save_path, to_gray):
        pass

class ColorComponent:
    def __init__(self, id, hscale, vscale, q_table_index, dc_table, ac_table):
        self.id = id
        self.hscale = hscale
        self.vscale = vscale
        self.q_table_index = q_table_index
        self.dc_table = dc_table
        self.ac_table = ac_table
    
    def __str__(self):
        return f"ColorComponent(id={self.id}, hscale={self.hscale}, vscale={self.vscale}, q_table_index={self.q_table_index}, dc_table={self.dc_table}, ac_table={self.ac_table})"

class JPEGFileWriter:
    DEFAULT_FOLDER = Path("./output/")
    def __init__(self, image_height, image_width, block_size, quantization_tables, huffman_tables, color_components):
        self.image_height, self.image_width = image_height, image_width
        self.quantization_tables = quantization_tables
        self.huffman_tables = huffman_tables
        self.color_components = color_components
        self.block_size = block_size

    def write_soi(self):
        soi = io.BytesIO()
        soi.write(b'\xFF\xD8')
        return soi.getvalue()

    def write_app0(self):
        app0 = io.BytesIO()
        app0.write(b'\xFF\xE0') ## Marker
        app0.write(struct.pack('>H', 16)) ## Length
        app0.write(struct.pack('5s', b"JFIF\0")) ## identifier
        app0.write(struct.pack('>B', 1)) ## JFIF version 1
        app0.write(struct.pack('>B', 1)) ## JFIF version .1
        app0.write(struct.pack('>B', 1)) ## units
        app0.write(struct.pack('>H', 96)) ## x-density
        app0.write(struct.pack('>H', 96)) ## y-density
        app0.write(struct.pack('>B', 0)) ## x-thumbnail
        app0.write(struct.pack('>B', 0)) ## y-thumbnail
        return app0.getvalue()

    def write_dqt(self, q_table, table_id):
        dqt = io.BytesIO()
        dqt.write(b'\xFF\xDB') ## Marker
        dqt.write(struct.pack('>H', 2+1+len(q_table.flatten()))) ## Length((2))
        dqt.write(struct.pack('>B', table_id)) ## 0: luminance((1))
        for quantization in Zigzag1Block(block=q_table, block_size=self.block_size): ## ((64))
            dqt.write(struct.pack('>B', quantization))
        return dqt.getvalue()

    def write_sof(self):
        sof = io.BytesIO()
        sof = io.BytesIO()
        sof.write(b'\xFF\xC0') ## Marker
        sof.write(struct.pack('>H', 2+1+2+2+1+len(self.color_components)*3)) ## Length
        sof.write(struct.pack('>B', 8)) ## 8: precision
        sof.write(struct.pack('>H', self.image_height)) ## height
        sof.write(struct.pack('>H', self.image_width)) ## width
        sof.write(struct.pack('>B', len(self.color_components))) ## component count
        for color_comp in self.color_components:
            sof.write(struct.pack('>B', color_comp.id))
            sof.write(struct.pack('>B', color_comp.hscale*0x10 + color_comp.vscale*0x01))
            sof.write(struct.pack('>B', color_comp.q_table_index))
        return sof.getvalue()

    def write_dht(self, huffman_table, table_id, is_ac):
        cw_huffman_table = transfor2CodewordCAT(huffman_table)
        bitsCount, codes = HuffmanTable2FileStructure(cw_huffman_table)
        dht = io.BytesIO()
        dht.write(b'\xFF\xC4')
        dht.write(struct.pack('>H', 2+1+16+bitsCount.sum().astype(np.uint16)))
        dht.write(struct.pack('>B', is_ac*0x10 + table_id*0x01))
        dht.write(struct.pack('16B', *bitsCount))
        for len_codes in codes:
            for code in len_codes:
                dht.write(struct.pack('>B', code))
        return dht.getvalue()

    def write_sos(self, bitstream):
        ecs_list = EntropyCoding(bitstream)
        sos = io.BytesIO()
        sos.write(b'\xFF\xDA')
        sos.write(struct.pack('>H', 2+1+len(self.color_components)*2+1+2))
        sos.write(struct.pack('>B', len(self.color_components)))
        for num_comp in self.color_components:
            sos.write(struct.pack('>B', num_comp.id))
            sos.write(struct.pack('>B', num_comp.dc_table*0x10 + num_comp.ac_table*0x01))
        sos.write(struct.pack('>H', 63)) ## spectral select
        sos.write(struct.pack('>B', 0)) ## successive approx.
        for ecs_block in ecs_list:
            sos.write(struct.pack('>B', int(ecs_block, 2)))
        return sos.getvalue()

    def write_eoi(self):
        eoi = io.BytesIO()
        eoi.write(b'\xFF\xD9')
        return eoi.getvalue()

    def write_file(self, bitstream, save_path):
        with io.BytesIO() as data:
            data.write(self.write_soi())
            data.write(self.write_app0())
            for idx, q_table in enumerate(self.quantization_tables):
                data.write(self.write_dqt(q_table, idx))
            # for comp in self.color_components:
            #     print("#write_file - component", comp)
            #     q_table = self.quantization_tables[comp.q_table_index]
            #     data.write(self.write_dqt(q_table, comp.id))
            data.write(self.write_sof())
            for idx, table_type in enumerate(["DC", "AC"]):
                for table_id in range(len(self.huffman_tables[table_type])):
                    data.write(self.write_dht(self.huffman_tables[table_type][table_id], table_id, table_type == "AC"))
            # for comp in self.color_components:
            #     print("#write_file - component", comp)
            #     huff_dc_table = self.huffman_tables["DC"][comp.dc_table]
            #     data.write(self.write_dht(huff_dc_table, comp.dc_table, False))
            #     huff_ac_table = self.huffman_tables["AC"][comp.dc_table]
            #     data.write(self.write_dht(huff_ac_table, comp.ac_table, True))
            data.write(self.write_sos(bitstream))
            data.write(self.write_eoi())

            self.ensure_directory_exists(save_path)
            with open(save_path, "wb") as f:
                f.write(data.getvalue())
            return data.getvalue()

    def create_marker_segment(marker, data):
        segment = io.BytesIO()
        segment.write(marker)
        for item in data:
            if isinstance(item, tuple):  # 如果是元组，表示需要打包
                segment.write(struct.pack(*item))
            else:
                segment.write(item)
        return segment

    def write_soi(self):
        # 返回 SOI 段的字节
        return b'\xFF\xD8'

    def ensure_directory_exists(self, file_path):
        os.makedirs(Path(file_path).parent, exist_ok=True)

class JPEGEncoder(EncoderBase):
    def init(self):
        # 初始化 JPEG 编码器所需的参数
        self.block_size = 8
        self.secret_data = ''
        self.embedded_len = 0

    def __init__(self, image_path, DEBUG=False):
        # super().__init__(image_path, DEBUG)
        self.image_path = Path(image_path)
        self.init()
    
    def load_image(self, image_path):
        self.image = iio.imread(image_path)
        self.image_height, self.image_width = self.image.shape[:2]
    
    @staticmethod
    def img2ycbcr(image, to_gray=False):
        if image.ndim == 3:
            ycbcr = RGB2YCbCr(image, to_gray=to_gray)
        else:
            ycbcr = Gray2YCbCr(image)
        return ycbcr

    def init_color_components(self, to_gray):
        if to_gray:
            self.color_components = [ColorComponent(1, 1, 1, 0, 0, 0)]
            self.QuantizationTable = [[]]
            self.HuffmanTable = {"DC": [[]], "AC": [[]]}
        else:
            self.color_components = [
                ColorComponent(1, 1, 1, 0, 0, 0),
                ColorComponent(2, 1, 1, 1, 1, 1),
                ColorComponent(3, 1, 1, 1, 1, 1)
            ]
            self.QuantizationTable = [[], []]
            self.HuffmanTable = {"DC": [[], []], "AC": [[], []]}

    def AC_encoding(self, vle_arr, HuffmanACTable):
        """
        对AC系数进行霍夫曼编码。

        :param vle_arr: 变长编码数组。
        :param HuffmanACTable: AC霍夫曼编码表。
        :return: 编码后的字符串。
        """
        ac_encoded = []
        for run, amplitude in vle_arr:
            size, word = binaryCode(amplitude)
            # print("run", run, "\tsize", size, "\tword", word)
            huffman_key = f"{run:01x}{size:01x}"
            # huffman_key = f"{hex(run)[-1]}{hex(size)[-1]}"
            # huffman_key = "{}{}".format(hex(run)[-1], hex(size)[-1])
            # print("huffman_key", huffman_key)
            huffman_codes = HuffmanACTable[huffman_key]
            code_index = 0
            if self.embedded_len < len(self.secret_data) and len(huffman_codes) > 1:
                unit_embed_len = np.log2(len(huffman_codes)).astype(int)
                code_index = int(self.secret_data[self.embedded_len:self.embedded_len+unit_embed_len], 2)
                self.embedded_len+=unit_embed_len
            huffman_code = huffman_codes[code_index]
            if run == 0 and size == 0:
                word = ""
            ac_encoded.append(f"{huffman_code}{word}")
        return ''.join(ac_encoded)

    def HuffmanEncodingMCU(self, mcu):
        """
        对单个MCU进行霍夫曼编码。

        :param mcu: MCU数据，包含DPCM和AC系数。
        :return: 编码后的字符串。
        """
        mcu_encoded = []

        for comp_idx, (dpcm, ac_coefs) in enumerate(mcu):
            comp = self.color_components[comp_idx]

            # DPCM 编码
            code_len, code_word = binaryCode(dpcm)
            huffman_dc_table = self.HuffmanTable["DC"][comp.dc_table]
            huffman_bytes = huffman_dc_table[f"{code_len:02x}"][0]
            mcu_encoded.append(f"{huffman_bytes}{code_word}")

            # AC 编码
            huffman_ac_table = self.HuffmanTable["AC"][comp.ac_table]
            mcu_encoded.append(self.AC_encoding(ac_coefs, huffman_ac_table))

        return ''.join(mcu_encoded)

    def encodingMCUs(self, MCUs):
        """
        对所有MCUs进行霍夫曼编码。

        :param MCUs: 所有MCU的集合。
        :return: 编码后的字符串。
        """
        return ''.join(self.HuffmanEncodingMCU(mcu) for mcu in MCUs)

    @staticmethod
    def getVLE(zigzaged_arr):
        """
        从zigzag扫描的数组中获取VLE（变长编码）。

        :param zigzaged_arr: 经过zigzag扫描的数组。
        :return: VLE数组。
        """
        vle = []
        unZeroIndex = np.argwhere(zigzaged_arr != 0).flatten()
        last_unZero_Index = 0
        for i in unZeroIndex:
            while(i+1-last_unZero_Index > 16):
                # print("{}:{}, len={}".format(last_unZero_Index, last_unZero_Index+16, 16))
                vle.append((15, 0))
                last_unZero_Index = last_unZero_Index+16
            # print("{}:{}, len={}".format(last_unZero_Index, i+1, i+1-last_unZero_Index))
            vle.append((i-last_unZero_Index, zigzaged_arr[i]))
            last_unZero_Index = i+1
        if last_unZero_Index < 63:
            vle.append((0, 0))
        return np.array(vle, dtype=np.int32)
    
    def getMCU(self, zigzaged_arr, showOutput=False):
        """
        从zigzag扫描的数组中获取MCUs。

        :param zigzaged_arr: 经过zigzag扫描的数组。
        :param showOutput: 是否打印输出。
        :return: MCU数组。
        """
        MCUs = []
        last_DC = np.zeros(len(self.color_components))

        for mcu in range(len(zigzaged_arr)):
            newMCU = []  # (DPCM, VLE)
            for comp_idx, comp in enumerate(self.color_components):
                # DPCM
                dpcm = int(zigzaged_arr[mcu][comp_idx][0] - last_DC[comp_idx])
                last_DC[comp_idx] = zigzaged_arr[mcu][comp_idx][0]

                # VLE
                vle = self.getVLE(zigzaged_arr[mcu][comp_idx][1:64])
                newMCU.append((dpcm, vle))

            MCUs.append(newMCU)

        if showOutput:
            print("[ShowOutput] getMCU: len=", len(MCUs))
            for mcu in MCUs:
                print(mcu)

        return MCUs
    
    def init_huffman_table(self, MCUs, type="standard"):
        if type == "standard":
            self.HuffmanTable["DC"][0] = transfor2CATCodeword(StandardHuffmanTree("LUMIN_DC").generate_codes())
            self.HuffmanTable["AC"][0] = transfor2CATCodeword(StandardHuffmanTree("LUMIN_AC").generate_codes())
            if len(self.color_components) > 1:
                self.HuffmanTable["DC"][1] = transfor2CATCodeword(StandardHuffmanTree("CHROMIN_DC").generate_codes())
                self.HuffmanTable["AC"][1] = transfor2CATCodeword(StandardHuffmanTree("CHROMIN_AC").generate_codes())

    ## huffman_type=["standard", "optimized", "auto"]
    def encode(self, quality, save_path=None, to_gray=False, huffman_type="standard"):
        self.init_color_components(to_gray)
        self.quality = quality

        # 加载和处理图像
        self.load_image(self.image_path)

        # 颜色空间转换、DCT、量化、霍夫曼编码等
        self.ycbcr = self.img2ycbcr(self.image, to_gray)
        
        self.fdct = FDCT(self.ycbcr, self.block_size)
        
        q_table = getQuantizationTable(quality)
        if len(self.color_components) > 1:
            self.QuantizationTable = q_table
        else:
            self.QuantizationTable = [q_table[0]]
        self.quantized = np.zeros(self.ycbcr.shape, dtype=fileDtype)
        for i in range(len(self.color_components)):
            self.quantized[:, :, i] = Quantize(self.fdct[:, :, i], self.QuantizationTable[self.color_components[i].q_table_index])
        
        self.zigzaged = Zigzag(self.quantized, self.block_size)
        
        # # Minimum Coded Unit
        self.MCUs = self.getMCU(self.zigzaged)
        
        self.init_huffman_table(self.MCUs, huffman_type)
        self.encodedBitstream = self.encodingMCUs(self.MCUs)

        # 将编码后的数据写入文件
        self.save_path, self.file_data = self.save_encoded_image(save_path)
        if save_path is None:
            print(f"文件已保存至 {self.save_path}")
        return self.file_data

    def save_encoded_image(self, save_path=None):
        # 如果没有指定保存路径，生成默认的保存路径和文件名
        if save_path is None:
            original_filename_stem = self.image_path.stem  # 原始文件名（不含扩展名）
            grayscale_suffix = "_toGray" if len(self.color_components) == 1 else ""
            quality_suffix = f"_Q{self.quality}"
            default_filename = f"{original_filename_stem}{grayscale_suffix}{quality_suffix}.jpg"
            save_path = JPEGFileWriter.DEFAULT_FOLDER / default_filename

        # 创建JPEG文件写入器
        writer = JPEGFileWriter(
            image_height=self.image_height,
            image_width=self.image_width,
            block_size=self.block_size,
            quantization_tables=self.QuantizationTable,
            huffman_tables=self.HuffmanTable,
            color_components=self.color_components
        )

        # 写入文件
        file_data = writer.write_file(self.encodedBitstream, save_path)
        return save_path, file_data


if __name__ == "__main__":
    encoder = JPEGEncoder("./datasets/baboon.tiff")
    encoder.encode(quality=70, to_gray=False)