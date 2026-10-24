import numpy as np

def RGB2YCbCr(img, to_gray=False):
    r, g, b = np.moveaxis(np.copy(img), -1, 0)
    y = 0.299 * r + 0.587 * g + 0.114 * b
    cb = (-0.168 * r - 0.331 * g + 0.499 * b) * (0 if to_gray else 1)
    cr = (0.500 * r - 0.419 * g - 0.081 * b) * (0 if to_gray else 1)
    return np.stack((y, cb, cr), axis=2)

def Gray2YCbCr(img):
    return np.stack((img, np.zeros(img.shape), np.zeros(img.shape)), axis=2)
