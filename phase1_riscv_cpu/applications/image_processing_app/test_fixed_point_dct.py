from __future__ import annotations

import math
from pathlib import Path

import cv2
import imageio.v3 as iio
import numpy as np


BLOCK = 8
FRACTION_BITS = 12
SCALE = 1 << FRACTION_BITS

INT16_MAX = (1 << 15) - 1
INT40_MAX = (1 << 39) - 1


def make_dct_matrix() -> np.ndarray:
    dct = np.zeros((BLOCK, BLOCK), dtype=np.float64)

    for row in range(BLOCK):
        if row == 0:
            alpha = 1 / math.sqrt(BLOCK)
        else:
            alpha = math.sqrt(2 / BLOCK)

        for column in range(BLOCK):
            angle = (
                (2 * column + 1)
                * row
                * math.pi
                / (2 * BLOCK)
            )

            dct[row, column] = alpha * math.cos(angle)

    return dct


def signed_round_divide(values: np.ndarray) -> np.ndarray:
    values = values.astype(np.int64, copy=False)

    rounded = (
        np.abs(values) + SCALE // 2
    ) // SCALE

    return np.where(
        values < 0,
        -rounded,
        rounded,
    ).astype(np.int64)


def fixed_fdct(
    block: np.ndarray,
    dct_q12: np.ndarray,
):
    block_integer = np.rint(block).astype(np.int64)

    # First matrix multiplication:
    # T = D × X
    first_accumulator = dct_q12 @ block_integer

    # Remove the Q12 scaling before the second multiplication.
    intermediate = signed_round_divide(
        first_accumulator
    )

    # Second matrix multiplication:
    # F = T × D-transpose
    second_accumulator = intermediate @ dct_q12.T

    result = signed_round_divide(
        second_accumulator
    )

    return (
        result,
        intermediate,
        first_accumulator,
        second_accumulator,
    )


def centered_ycbcr(image: np.ndarray) -> np.ndarray:
    red, green, blue = np.moveaxis(
        image.astype(np.float64),
        -1,
        0,
    )

    y = (
        0.299 * red
        + 0.587 * green
        + 0.114 * blue
        - 128.0
    )

    cb = (
        -0.168 * red
        - 0.331 * green
        + 0.499 * blue
    )

    cr = (
        0.500 * red
        - 0.419 * green
        - 0.081 * blue
    )

    return np.stack(
        (y, cb, cr),
        axis=2,
    )


def main() -> int:
    root = Path(__file__).resolve().parent

    images = [
        root / "datasets" / "baboon.tiff",
        root / "datasets" / "Lena.tiff",
    ]

    dct_float = make_dct_matrix()

    dct_q12 = np.rint(
        dct_float * SCALE
    ).astype(np.int64)

    block_count = 0
    coefficient_count = 0
    different_count = 0

    squared_error = 0.0
    maximum_error = 0

    maximum_input = 0
    maximum_intermediate = 0
    maximum_first_accumulator = 0
    maximum_second_accumulator = 0

    for image_path in images:
        image = np.asarray(
            iio.imread(image_path),
            dtype=np.uint8,
        )

        data = centered_ycbcr(image)

        height = (
            data.shape[0]
            - data.shape[0] % BLOCK
        )

        width = (
            data.shape[1]
            - data.shape[1] % BLOCK
        )

        for y in range(0, height, BLOCK):
            for x in range(0, width, BLOCK):
                for channel in range(3):
                    block = data[
                        y:y + BLOCK,
                        x:x + BLOCK,
                        channel,
                    ]

                    (
                        fixed,
                        intermediate,
                        first_accumulator,
                        second_accumulator,
                    ) = fixed_fdct(
                        block,
                        dct_q12,
                    )

                    reference = np.rint(
                        cv2.dct(
                            block.astype(np.float32)
                        )
                    ).astype(np.int64)

                    difference = fixed - reference

                    maximum_error = max(
                        maximum_error,
                        int(
                            np.max(
                                np.abs(difference)
                            )
                        ),
                    )

                    different_count += int(
                        np.count_nonzero(
                            difference
                        )
                    )

                    squared_error += float(
                        np.sum(
                            difference.astype(
                                np.float64
                            ) ** 2
                        )
                    )

                    coefficient_count += (
                        difference.size
                    )

                    block_count += 1

                    maximum_input = max(
                        maximum_input,
                        int(
                            np.max(
                                np.abs(
                                    np.rint(block)
                                )
                            )
                        ),
                    )

                    maximum_intermediate = max(
                        maximum_intermediate,
                        int(
                            np.max(
                                np.abs(
                                    intermediate
                                )
                            )
                        ),
                    )

                    maximum_first_accumulator = max(
                        maximum_first_accumulator,
                        int(
                            np.max(
                                np.abs(
                                    first_accumulator
                                )
                            )
                        ),
                    )

                    maximum_second_accumulator = max(
                        maximum_second_accumulator,
                        int(
                            np.max(
                                np.abs(
                                    second_accumulator
                                )
                            )
                        ),
                    )

    rmse = math.sqrt(
        squared_error / coefficient_count
    )

    print("FIXED-POINT 8x8 JPEG DCT VALIDATION")
    print(f"Q format: Q{FRACTION_BITS}")
    print(f"Scale: {SCALE}")
    print(f"Images tested: {len(images)}")
    print(
        f"Channel blocks tested: "
        f"{block_count}"
    )
    print(
        f"Coefficients compared: "
        f"{coefficient_count}"
    )
    print(
        f"Different rounded coefficients: "
        f"{different_count}"
    )
    print(
        f"Maximum absolute coefficient error: "
        f"{maximum_error}"
    )
    print(
        f"Coefficient RMSE: "
        f"{rmse:.6f}"
    )
    print(
        f"Maximum input magnitude: "
        f"{maximum_input}"
    )
    print(
        f"Maximum intermediate magnitude: "
        f"{maximum_intermediate}"
    )
    print(
        "Maximum first accumulator magnitude: "
        f"{maximum_first_accumulator}"
    )
    print(
        "Maximum second accumulator magnitude: "
        f"{maximum_second_accumulator}"
    )

    maximum_dct_value = int(
        np.max(
            np.abs(dct_q12)
        )
    )

    if maximum_dct_value > INT16_MAX:
        print(
            "FAIL: Q12 DCT matrix does not "
            "fit signed 16-bit."
        )
        return 1

    if (
        maximum_input > INT16_MAX
        or maximum_intermediate > INT16_MAX
    ):
        print(
            "FAIL: Matrix input or intermediate "
            "does not fit signed 16-bit."
        )
        return 1

    maximum_accumulator = max(
        maximum_first_accumulator,
        maximum_second_accumulator,
    )

    if maximum_accumulator > INT40_MAX:
        print(
            "FAIL: A matrix accumulator exceeded "
            "signed 40-bit."
        )
        return 1

    if maximum_error > 2:
        print(
            "FAIL: Fixed-point DCT error exceeded "
            "2 coefficient units."
        )
        return 1

    print(
        "PASS: Q12 fixed-point DCT matches "
        "OpenCV within tolerance."
    )

    print(
        "PASS: Signed 16-bit inputs and "
        "intermediate values are safe."
    )

    print(
        "PASS: Signed 40-bit accumulators "
        "are safe."
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())