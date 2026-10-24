from abc import ABC, abstractmethod

class HuffmanTreeInterface(ABC):

    @abstractmethod
    def build_tree(self, data):
        pass

    @abstractmethod
    def generate_codes(self):
        pass

    @abstractmethod
    def to_dict(self):
        pass
