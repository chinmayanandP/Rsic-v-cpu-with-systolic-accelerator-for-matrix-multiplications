import math
import os

import cv2
import numpy as np


BLOCK_SIZE = 8
FRACTION_BITS = 12
FIXED_SCALE = 1 << FRACTION_BITS

SUPPORTED_BACKENDS = (
    "opencv",
    "fixed_python",
)


def _make_dct_matrix(block_size=BLOCK_SIZE):
    """Create the orthonormal JPEG DCT transform matrix."""
    matrix = np.zeros(
        (block_size, block_size),
        dtype=np.float64,
    )

    for row in range(block_size):
        if row == 0:
            alpha = 1.0 / math.sqrt(block_size)
        else:
            alpha = math.sqrt(2.0 / block_size)

        for column in range(block_size):
            angle = (
                (2 * column + 1)
                * row
                * math.pi
                / (2 * block_size)
            )

            matrix[row, column] = (
                alpha * math.cos(angle)
            )

    return matrix


DCT_MATRIX_Q12 = np.rint(
    _make_dct_matrix(BLOCK_SIZE)
    * FIXED_SCALE
).astype(np.int64)


def _signed_round_divide(
    values,
    divisor=FIXED_SCALE,
):
    """
    Divide signed integer values and round them
    to the nearest integer.
    """
    values = np.asarray(
        values,
        dtype=np.int64,
    )

    magnitude = (
        np.abs(values)
        + divisor // 2
    ) // divisor

    result = np.where(
        values < 0,
        -magnitude,
        magnitude,
    )

    return result.astype(
        np.int64
    )


def _fixed_fdct_block(block):
    """
    Calculate one 8x8 forward DCT block
    using Q12 fixed-point integer arithmetic.
    """
    integer_block = np.rint(
        block
    ).astype(np.int64)

    first_accumulator = (
        DCT_MATRIX_Q12
        @ integer_block
    )

    intermediate = _signed_round_divide(
        first_accumulator
    )

    second_accumulator = (
        intermediate
        @ DCT_MATRIX_Q12.T
    )

    result = _signed_round_divide(
        second_accumulator
    )

    return result.astype(
        np.float64
    )


def _validate_image_shape(
    image,
    block_size,
):
    """Check that the input image can be divided into blocks."""
    if image.ndim != 3:
        raise ValueError(
            "FDCT expects an H x W x C image array."
        )

    height, width, _ = image.shape

    if (
        height % block_size != 0
        or width % block_size != 0
    ):
        raise ValueError(
            "Image height and width must be multiples "
            f"of the DCT block size ({block_size}). "
            f"Received {height}x{width}."
        )


def FDCT(
    img,
    block_size=8,
    color_space="YUV",
    backend=None,
):
    """
    Perform block-based Forward DCT.

    Supported backends:

    opencv:
        Original floating-point OpenCV DCT.

    fixed_python:
        Q12 fixed-point integer DCT matching
        the RISC-V and RTL arithmetic plan.

    If backend is not provided, the function checks
    the JPEG_DCT_BACKEND environment variable.

    If the environment variable is also absent,
    OpenCV is used by default.
    """
    if backend is None:
        backend = os.environ.get(
            "JPEG_DCT_BACKEND",
            "opencv",
        )

    backend = backend.strip().lower()

    if backend not in SUPPORTED_BACKENDS:
        raise ValueError(
            f"Unsupported DCT backend '{backend}'. "
            "Choose one of: "
            f"{', '.join(SUPPORTED_BACKENDS)}."
        )

    if (
        backend == "fixed_python"
        and block_size != BLOCK_SIZE
    ):
        raise ValueError(
            "The fixed-point backend supports "
            "only 8x8 JPEG blocks."
        )

    work_image = np.array(
        img,
        dtype=np.float64,
        copy=True,
    )

    _validate_image_shape(
        work_image,
        block_size,
    )

    if color_space == "YUV":
        work_image[:, :, 0] -= 128.0

    fdct = np.zeros(
        work_image.shape,
        dtype=np.float64,
    )

    for row in range(
        0,
        work_image.shape[0],
        block_size,
    ):
        for column in range(
            0,
            work_image.shape[1],
            block_size,
        ):
            for channel in range(
                work_image.shape[2]
            ):
                block = work_image[
                    row:row + block_size,
                    column:column + block_size,
                    channel,
                ]

                if backend == "opencv":
                    transformed = cv2.dct(
                        block
                    )
                else:
                    transformed = _fixed_fdct_block(
                        block
                    )

                fdct[
                    row:row + block_size,
                    column:column + block_size,
                    channel,
                ] = transformed

    return fdct


def IDCT(
    img,
    block_size=8,
    color_space="YUV",
):
    """
    Perform the block-based inverse DCT.

    For a colour image, only the Y channel receives
    the +128 level shift because only Y was shifted
    before the forward DCT.

    Cb and Cr remain centred around zero.
    """
    work_image = np.copy(
        img
    ).astype(np.float32)

    idct_img = np.zeros(
        img.shape,
        dtype=np.float32,
    )

    for row in range(
        0,
        idct_img.shape[0],
        block_size,
    ):
        for column in range(
            0,
            idct_img.shape[1],
            block_size,
        ):
            if img.ndim == 3:
                for channel in range(
                    idct_img.shape[2]
                ):
                    block = work_image[
                        row:row + block_size,
                        column:column + block_size,
                        channel,
                    ]

                    reconstructed = cv2.idct(
                        block
                    )

                    idct_img[
                        row:row + block_size,
                        column:column + block_size,
                        channel,
                    ] = reconstructed
            else:
                block = work_image[
                    row:row + block_size,
                    column:column + block_size,
                ]

                reconstructed = cv2.idct(
                    block
                )

                idct_img[
                    row:row + block_size,
                    column:column + block_size,
                ] = reconstructed

    if color_space == "YUV":
        if idct_img.ndim == 3:
            idct_img[:, :, 0] += 128.0
        else:
            idct_img += 128.0

    return idct_img