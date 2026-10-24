from collections import Counter, namedtuple
import pandas as pd
from queue import PriorityQueue
from .huffman_tree_interface import HuffmanTreeInterface

class OptimizedHuffmanTree(HuffmanTreeInterface):
    class _Node:
        def __init__(self, value, freq, left_child, right_child):
            self.value = value
            self.freq = freq
            self.left_child = left_child
            self.right_child = right_child

        @staticmethod
        def init_leaf(self, value, freq):
            return self(value, freq, None, None)

        @staticmethod
        def init_node(self, left_child, right_child):
            freq = left_child.freq + right_child.freq
            return self(None, freq, left_child, right_child)

        def is_leaf(self):
            return self.value is not None

        def __eq__(self, other):
            return self.__dict__ == other.__dict__

        def __nq__(self, other):
            return not (self == other)

        def __lt__(self, other):
            return self.freq < other.freq

        def __le__(self, other):
            return self.freq < other.freq or self.freq == other.freq

        def __gt__(self, other):
            return not (self <= other)

        def __ge__(self, other):
            return not (self < other)

    def __init__(self):
        self.key_freq = {}
        self.key_codelen = {}
        self.key_code = {}
        self.__root = None
        
    def calc_node_codeLen(self, n, codelen=0):
        if n.value is not None:
            self.key_codelen[n.value] = codelen
        else:
            self.calc_node_codeLen(n.left_child, codelen + 1)
            self.calc_node_codeLen(n.right_child, codelen + 1)

    def build_tree(self, data):
        freq_dict = Counter(data)
        freq_dict['虛擬符號'] = -1
        self.key_freq = freq_dict.copy()
        self.key_codelen = {key: 0 for key in freq_dict.keys()}
        q = PriorityQueue()

        for symbol, freq in freq_dict.items():
            q.put(self._Node.init_leaf(symbol, freq))

        while q.qsize() >= 2:
            u = q.get()
            v = q.get()
            q.put(self._Node.init_node(u, v))

        self.__root = q.get()
        self.calc_node_codeLen(self.__root)
        self.key_freq.pop('虛擬符號', None)
        self.key_codelen.pop('虛擬符號', None)

    def limit_code_lengths(self, target_length=16):
        df = self.to_pandas(exclude_virtual=True)
        length_counts = Counter(df['codelen'])
        MAX_LENGTH = df['codelen'].max()

        # 調整編碼長度
        for i in range(MAX_LENGTH, target_length, -1):
            while length_counts[i] > 0:
                j = i - 2
                while length_counts[j] == 0:
                    j -= 1

                length_counts[i] -= 2
                length_counts[i - 1] += 1
                length_counts[j + 1] += 2
                length_counts[j] -= 1

        # 更新代碼長度
        final_lengths = []
        for length, count in length_counts.items():
            final_lengths.extend([length] * count)

        symbols_sorted_by_freq = df.sort_values(by='freq', ascending=False)['symbol']
        for symbol, length in zip(symbols_sorted_by_freq, final_lengths):
            self.key_codelen[symbol] = length

    def generate_codes(self):
        # 生成和返回霍夫曼編碼
        df_nodes = self.to_pandas(exclude_virtual=True)
        df_nodes.sort_values(by=['codelen', 'freq'], ascending=[True, False], inplace=True)

        huffman_table = dict()
        current_code_len = df_nodes.iloc[0]['codelen']
        current_code_val = 0b0

        for i, row in df_nodes.iterrows():
            key = row['symbol']
            code_len = row['codelen']

            if code_len != current_code_len:
                current_code_val <<= (code_len - current_code_len)
                current_code_len = code_len

            huffman_table[key] = f'{current_code_val:0{code_len}b}'
            current_code_val += 1

        self.key_code = huffman_table
        return huffman_table

    def calculate_max_min_lengths(self):
        max_len = max(self.key_codelen.values())
        min_len = min(self.key_codelen.values())
        return max_len, min_len

    def calculate_compressed_size(self):
        compressed_size = 0
        for symbol, freq in self.key_freq.items():
            code_len = self.key_codelen.get(symbol, 0)
            compressed_size += freq * code_len
        return compressed_size


    def to_dict(self):
        # 將霍夫曼編碼轉換為字典
        return self.to_pandas(exclude_virtual=True).set_index('symbol')['code'].to_dict()

    def to_pandas(self, exclude_virtual=False):
        data = {
            "symbol": list(self.key_freq.keys()),
            "freq": list(self.key_freq.values()),
            "codelen": [self.key_codelen[symbol] for symbol in self.key_freq],
            "code": [self.key_code.get(symbol, "") for symbol in self.key_freq]
        }
        df = pd.DataFrame(data)

        if exclude_virtual:
            df = df[df['symbol'] != '虛擬符號']

        return df.sort_values(by=['codelen', 'freq'], ascending=[True, False])