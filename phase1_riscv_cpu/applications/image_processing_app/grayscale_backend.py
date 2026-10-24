import numpy as np


def rgb_to_grayscale(rgb):
    """Convert an 8-bit RGB image to an 8-bit grayscale image."""
    rgb = np.asarray(rgb)

    if rgb.ndim != 3 or rgb.shape[2] != 3:
        raise ValueError("Expected an RGB image with three channels.")

    values = rgb.astype(np.float64)

    gray = (
        0.299 * values[:, :, 0]
        + 0.587 * values[:, :, 1]
        + 0.114 * values[:, :, 2]
    )

    return np.clip(
        np.floor(gray + 0.5), 0, 255
    ).astype(np.uint8)