from __future__ import annotations

from pathlib import Path

import cv2
import imageio.v3 as iio
import numpy as np

from riscv_batch_dct_backend import (
    BLOCK_SIZE,
    RiscVBatchDCTBackend,
    build_q12_dct_matrix,
    round_shift_q12,
)

from utils.color_transforms import (
    RGB2YCbCr,
)


APPLICATION_DIR = (
    Path(__file__).resolve().parent
)

INPUT_IMAGE = (
    APPLICATION_DIR
    / "datasets"
    / "baboon.tiff"
)

RESULT_FILE = (
    APPLICATION_DIR
    / "riscv_color_batch_dct_result.txt"
)

CROP_HEIGHT = 16
CROP_WIDTH = 16


def fixed_python_reference(
    ycbcr: np.ndarray,
) -> np.ndarray:
    working = np.asarray(
        ycbcr,
        dtype=np.float64,
    ).copy()

    working[:, :, 0] -= 128.0

    integer_samples = np.rint(
        working
    ).astype(np.int64)

    dct_matrix = (
        build_q12_dct_matrix()
    )

    output = np.zeros(
        working.shape,
        dtype=np.int64,
    )

    for block_row in range(
        0,
        working.shape[0],
        BLOCK_SIZE,
    ):
        for block_column in range(
            0,
            working.shape[1],
            BLOCK_SIZE,
        ):
            for component in range(
                working.shape[2]
            ):
                block = integer_samples[
                    block_row:
                    block_row + BLOCK_SIZE,
                    block_column:
                    block_column + BLOCK_SIZE,
                    component,
                ]

                first_stage = (
                    round_shift_q12(
                        dct_matrix @ block
                    )
                )

                second_stage = (
                    round_shift_q12(
                        first_stage
                        @ dct_matrix.T
                    )
                )

                output[
                    block_row:
                    block_row + BLOCK_SIZE,
                    block_column:
                    block_column + BLOCK_SIZE,
                    component,
                ] = second_stage

    return output


def opencv_reference(
    ycbcr: np.ndarray,
) -> np.ndarray:
    working = np.asarray(
        ycbcr,
        dtype=np.float64,
    ).copy()

    working[:, :, 0] -= 128.0

    working = np.rint(
        working
    ).astype(np.float64)

    output = np.zeros(
        working.shape,
        dtype=np.float64,
    )

    for block_row in range(
        0,
        working.shape[0],
        BLOCK_SIZE,
    ):
        for block_column in range(
            0,
            working.shape[1],
            BLOCK_SIZE,
        ):
            for component in range(
                working.shape[2]
            ):
                block = working[
                    block_row:
                    block_row + BLOCK_SIZE,
                    block_column:
                    block_column + BLOCK_SIZE,
                    component,
                ]

                output[
                    block_row:
                    block_row + BLOCK_SIZE,
                    block_column:
                    block_column + BLOCK_SIZE,
                    component,
                ] = cv2.dct(block)

    return np.rint(
        output
    ).astype(np.int64)


def main() -> int:
    print(
        "RISC-V CPU COLOR "
        "BATCH DCT TEST"
    )

    print(
        f"Input image: {INPUT_IMAGE}"
    )

    if not INPUT_IMAGE.is_file():
        print(
            "ERROR: Input image "
            "was not found."
        )
        return 1

    original = np.asarray(
        iio.imread(INPUT_IMAGE),
        dtype=np.uint8,
    )

    if (
        original.ndim != 3
        or original.shape[2] < 3
    ):
        print(
            "ERROR: The test image "
            "must be a color image."
        )
        return 1

    if (
        original.shape[0] < CROP_HEIGHT
        or original.shape[1] < CROP_WIDTH
    ):
        print(
            "ERROR: The test image is "
            "smaller than 16x16 pixels."
        )
        return 1

    crop = original[
        :CROP_HEIGHT,
        :CROP_WIDTH,
        :3,
    ]

    ycbcr = RGB2YCbCr(
        crop,
        to_gray=False,
    )

    print(
        f"Test crop: "
        f"{CROP_WIDTH}x{CROP_HEIGHT} color"
    )

    print(
        "Color components: Y, Cb and Cr"
    )

    print(
        "Expected pixel blocks: 4"
    )

    print(
        "Expected component DCT "
        "operations: 12"
    )

    print(
        "Expected CPU matrix jobs: 24"
    )

    backend = RiscVBatchDCTBackend()

    cpu_output = backend.fdct(
        ycbcr
    )

    report = backend.last_report

    if report is None:
        print(
            "ERROR: The RISC-V backend "
            "did not create a report."
        )
        return 1

    cpu_integer = np.rint(
        cpu_output
    ).astype(np.int64)

    python_reference = (
        fixed_python_reference(ycbcr)
    )

    cv_reference = (
        opencv_reference(ycbcr)
    )

    cpu_python_error = int(
        np.max(
            np.abs(
                cpu_integer
                - python_reference
            )
        )
    )

    cpu_opencv_error = int(
        np.max(
            np.abs(
                cpu_integer
                - cv_reference
            )
        )
    )

    checks = {
        "Pixel block count is 4":
            report.block_count == 4,

        "Component count is 3":
            report.component_count == 3,

        "Matrix job count is 24":
            report.matrix_job_count == 24,

        "No arithmetic overflow":
            report.overflow_count == 0,

        "CPU matches fixed Python exactly":
            cpu_python_error == 0,

        "CPU is within 2 of OpenCV":
            cpu_opencv_error <= 2,

        "CPU cycle count is valid":
            report.total_cycles > 0,
    }

    report_lines = [
        "RISC-V CPU COLOR BATCH DCT RESULT",
        "",
        f"Input image: {INPUT_IMAGE}",
        (
            "Original resolution: "
            f"{original.shape[1]}x"
            f"{original.shape[0]}"
        ),
        (
            "Test crop resolution: "
            f"{CROP_WIDTH}x{CROP_HEIGHT}"
        ),
        (
            f"Pixel blocks: "
            f"{report.block_count}"
        ),
        (
            f"Color components: "
            f"{report.component_count}"
        ),
        (
            f"Matrix jobs: "
            f"{report.matrix_job_count}"
        ),
        (
            "First-stage CPU cycles: "
            f"{report.first_stage_cycles}"
        ),
        (
            "Second-stage CPU cycles: "
            f"{report.second_stage_cycles}"
        ),
        (
            f"Total CPU cycles: "
            f"{report.total_cycles}"
        ),
        (
            "RTL CPU time at 100 MHz: "
            f"{report.cpu_time_seconds_at_100_mhz * 1000.0:.6f} ms"
        ),
        (
            "Vivado/XSim elapsed time: "
            f"{report.total_elapsed_seconds:.3f} seconds"
        ),
        (
            f"Overflow count: "
            f"{report.overflow_count}"
        ),
        (
            "Maximum CPU-vs-Python error: "
            f"{cpu_python_error}"
        ),
        (
            "Maximum CPU-vs-OpenCV error: "
            f"{cpu_opencv_error}"
        ),
        "",
    ]

    all_passed = True

    for description, passed in checks.items():
        if passed:
            line = (
                f"PASS: {description}"
            )
        else:
            line = (
                f"FAIL: {description}"
            )
            all_passed = False

        print(line)
        report_lines.append(line)

    report_lines.append("")

    if all_passed:
        final_status = (
            "STATUS: RISC-V COLOR "
            "BATCH DCT TEST PASSED"
        )
    else:
        final_status = (
            "STATUS: RISC-V COLOR "
            "BATCH DCT TEST FAILED"
        )

    print()
    print(final_status)

    print(
        f"Total CPU cycles: "
        f"{report.total_cycles}"
    )

    print(
        "RTL CPU time at 100 MHz: "
        f"{report.cpu_time_seconds_at_100_mhz * 1000.0:.6f} ms"
    )

    print(
        "Vivado/XSim elapsed time: "
        f"{report.total_elapsed_seconds:.3f} seconds"
    )

    print(
        f"Detailed result: "
        f"{RESULT_FILE}"
    )

    report_lines.append(
        final_status
    )

    RESULT_FILE.write_text(
        "\n".join(report_lines) + "\n",
        encoding="utf-8",
    )

    return 0 if all_passed else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())

    except (
        FileNotFoundError,
        RuntimeError,
        ValueError,
    ) as error:
        print()
        print(f"ERROR: {error}")
        raise SystemExit(1)

    except KeyboardInterrupt:
        print()
        print("Operation cancelled.")
        raise SystemExit(130)