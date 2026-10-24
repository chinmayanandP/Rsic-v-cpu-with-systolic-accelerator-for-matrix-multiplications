from __future__ import annotations

import math
import re
import subprocess
import time
from pathlib import Path

import cv2
import imageio.v3 as iio
import numpy as np

from utils.quantization import getQuantizationTable


PROJECT_ROOT = Path(
    r"E:\project\Project Final riscv"
)

JPEG_ROOT = Path(__file__).resolve().parent

VIVADO = Path(
    r"D:\vivado\2026.1\Vivado\bin\vivado.bat"
)

TCL_FILE = (
    PROJECT_ROOT
    / "run_matrix_sim.tcl"
)

INPUT_FILE = (
    PROJECT_ROOT
    / "matrix_input.mem"
)

OUTPUT_FILE = (
    PROJECT_ROOT
    / "matrix_output.txt"
)

IMAGE_FILE = (
    JPEG_ROOT
    / "datasets"
    / "baboon.tiff"
)

RESULT_FILE = (
    JPEG_ROOT
    / "riscv_dct_32x32_result.txt"
)

ORIGINAL_IMAGE_FILE = (
    JPEG_ROOT
    / "riscv_dct_32x32_original.png"
)

RECONSTRUCTED_IMAGE_FILE = (
    JPEG_ROOT
    / "riscv_dct_32x32_reconstructed.png"
)


MEMORY_WORDS = 4096

A_BASE = 0
B_BASE = 1024
C_BASE = 2048

M_WORD = 3072
K_WORD = 3073
N_WORD = 3074
OVERFLOW_WORD = 3075
DONE_WORD = 3076

BLOCK_SIZE = 8
IMAGE_SIZE = 32
JPEG_QUALITY = 70

FRACTION_BITS = 12
SCALE = 1 << FRACTION_BITS

CLOCK_FREQUENCY_HZ = 100_000_000
CLOCK_PERIOD_NS = 10


def make_dct_matrix() -> np.ndarray:
    """Create the orthonormal 8x8 JPEG DCT matrix."""
    matrix = np.zeros(
        (BLOCK_SIZE, BLOCK_SIZE),
        dtype=np.float64,
    )

    for row in range(BLOCK_SIZE):
        if row == 0:
            alpha = (
                1.0
                / math.sqrt(BLOCK_SIZE)
            )
        else:
            alpha = math.sqrt(
                2.0 / BLOCK_SIZE
            )

        for column in range(BLOCK_SIZE):
            angle = (
                (2 * column + 1)
                * row
                * math.pi
                / (2 * BLOCK_SIZE)
            )

            matrix[row, column] = (
                alpha
                * math.cos(angle)
            )

    return matrix


def signed_round_divide(
    values: np.ndarray,
) -> np.ndarray:
    """Perform signed rounded Q12 division."""
    values = np.asarray(
        values,
        dtype=np.int64,
    )

    magnitude = (
        np.abs(values)
        + SCALE // 2
    ) // SCALE

    result = np.where(
        values < 0,
        -magnitude,
        magnitude,
    )

    return result.astype(
        np.int64
    )


def check_signed_16(
    name: str,
    matrix: np.ndarray,
) -> None:
    """Check that matrix values fit signed 16-bit."""
    minimum = int(
        np.min(matrix)
    )

    maximum = int(
        np.max(matrix)
    )

    if (
        minimum < -32768
        or maximum > 32767
    ):
        raise ValueError(
            f"{name} is outside signed 16-bit "
            f"range: [{minimum}, {maximum}]"
        )


def load_grayscale_crop() -> np.ndarray:
    """Load a 32x32 grayscale crop from Baboon."""
    image = np.asarray(
        iio.imread(IMAGE_FILE),
        dtype=np.uint8,
    )

    if (
        image.ndim != 3
        or image.shape[2] < 3
    ):
        raise ValueError(
            "The source image must contain RGB channels."
        )

    if (
        image.shape[0] < IMAGE_SIZE
        or image.shape[1] < IMAGE_SIZE
    ):
        raise ValueError(
            "The source image must be at least "
            f"{IMAGE_SIZE}x{IMAGE_SIZE}."
        )

    red = image[
        :, :, 0
    ].astype(np.float64)

    green = image[
        :, :, 1
    ].astype(np.float64)

    blue = image[
        :, :, 2
    ].astype(np.float64)

    grayscale = (
        0.299 * red
        + 0.587 * green
        + 0.114 * blue
    )

    grayscale = np.clip(
        np.rint(grayscale),
        0,
        255,
    ).astype(np.uint8)

    return grayscale[
        :IMAGE_SIZE,
        :IMAGE_SIZE,
    ]


def write_matrix_input(
    matrix_a: np.ndarray,
    matrix_b: np.ndarray,
) -> None:
    """Write two matrices into matrix_input.mem."""
    rows_a, columns_a = matrix_a.shape
    rows_b, columns_b = matrix_b.shape

    if columns_a != rows_b:
        raise ValueError(
            "Matrix dimensions are incompatible."
        )

    check_signed_16(
        "Matrix A",
        matrix_a,
    )

    check_signed_16(
        "Matrix B",
        matrix_b,
    )

    memory = [0] * MEMORY_WORDS

    for index, value in enumerate(
        matrix_a.reshape(-1)
    ):
        memory[
            A_BASE + index
        ] = int(value) & 0xFFFFFFFF

    for index, value in enumerate(
        matrix_b.reshape(-1)
    ):
        memory[
            B_BASE + index
        ] = int(value) & 0xFFFFFFFF

    memory[M_WORD] = rows_a
    memory[K_WORD] = columns_a
    memory[N_WORD] = columns_b

    memory[OVERFLOW_WORD] = 0
    memory[DONE_WORD] = 0

    memory_text = "".join(
        f"{word:08x}\n"
        for word in memory
    )

    INPUT_FILE.write_text(
        memory_text,
        encoding="ascii",
    )


def parse_matrix_output(
    rows: int,
    columns: int,
):
    """Read CPU cycles, overflow and Matrix C."""
    if not OUTPUT_FILE.is_file():
        raise RuntimeError(
            "Vivado did not create matrix_output.txt."
        )

    text = OUTPUT_FILE.read_text(
        encoding="utf-8"
    )

    required_status = (
        "STATUS: MANUAL CPU MATRIX "
        "MULTIPLICATION PASSED"
    )

    if required_status not in text:
        raise RuntimeError(
            "The RTL CPU matrix multiplication "
            "did not report PASS.\n"
            + text
        )

    cycle_match = re.search(
        r"CPU cycles:\s*(\d+)",
        text,
    )

    overflow_match = re.search(
        r"Overflow flag:\s*(\d+)",
        text,
    )

    if (
        cycle_match is None
        or overflow_match is None
    ):
        raise RuntimeError(
            "Cycle or overflow information is missing."
        )

    matrix_section = text.split(
        "Matrix C:",
        1,
    )[1]

    matrix_rows = []

    for line in matrix_section.splitlines():
        stripped = line.strip()

        if not stripped:
            continue

        if stripped.startswith(
            "STATUS:"
        ):
            break

        fields = stripped.split()

        if len(fields) != columns:
            continue

        try:
            values = [
                int(field, 10)
                for field in fields
            ]
        except ValueError:
            continue

        matrix_rows.append(
            values
        )

        if len(matrix_rows) == rows:
            break

    if len(matrix_rows) != rows:
        raise RuntimeError(
            "Could not parse Matrix C "
            "from matrix_output.txt."
        )

    matrix_c = np.asarray(
        matrix_rows,
        dtype=np.int64,
    )

    cycles = int(
        cycle_match.group(1)
    )

    overflow = int(
        overflow_match.group(1)
    )

    return (
        matrix_c,
        cycles,
        overflow,
    )


def run_cpu_multiplication(
    matrix_a: np.ndarray,
    matrix_b: np.ndarray,
    label: str,
):
    """Run one matrix multiplication on the RTL CPU."""
    write_matrix_input(
        matrix_a,
        matrix_b,
    )

    OUTPUT_FILE.unlink(
        missing_ok=True
    )

    completed = subprocess.run(
        [
            str(VIVADO),
            "-mode",
            "batch",
            "-source",
            str(TCL_FILE),
            "-notrace",
        ],
        cwd=PROJECT_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )

    if completed.returncode != 0:
        diagnostic = (
            completed.stdout
            + "\n"
            + completed.stderr
        )[-8000:]

        raise RuntimeError(
            f"Vivado failed during {label} "
            f"with exit code "
            f"{completed.returncode}.\n"
            f"{diagnostic}"
        )

    return parse_matrix_output(
        matrix_a.shape[0],
        matrix_b.shape[1],
    )


def calculate_psnr(
    reference: np.ndarray,
    result: np.ndarray,
) -> float:
    """Calculate reconstructed-image PSNR."""
    difference = (
        reference.astype(np.float64)
        - result.astype(np.float64)
    )

    mse = float(
        np.mean(
            difference * difference
        )
    )

    if mse == 0.0:
        return float("inf")

    return float(
        20.0
        * np.log10(
            255.0
            / np.sqrt(mse)
        )
    )


def reconstruct_block(
    dct_coefficients: np.ndarray,
    quantization_table: np.ndarray,
) -> np.ndarray:
    """Quantize, dequantize and reconstruct one block."""
    quantized = np.round(
        dct_coefficients.astype(np.float64)
        / quantization_table.astype(np.float64)
    ).astype(np.int32)

    dequantized = (
        quantized.astype(np.float32)
        * quantization_table.astype(np.float32)
    )

    reconstructed = (
        cv2.idct(dequantized)
        + 128.0
    )

    return np.clip(
        np.rint(reconstructed),
        0,
        255,
    ).astype(np.uint8)


def main() -> int:
    """Run the 32x32 multi-block RTL CPU test."""
    required_files = [
        VIVADO,
        TCL_FILE,
        IMAGE_FILE,
    ]

    missing_files = [
        str(path)
        for path in required_files
        if not path.is_file()
    ]

    if missing_files:
        print(
            "ERROR: Required file was not found:"
        )

        for path in missing_files:
            print(path)

        return 1

    grayscale = load_grayscale_crop()

    reconstructed = np.zeros_like(
        grayscale
    )

    dct_q12 = np.rint(
        make_dct_matrix()
        * SCALE
    ).astype(np.int64)

    dct_q12_transpose = (
        dct_q12.T
    )

    luminance_table = np.asarray(
        getQuantizationTable(
            JPEG_QUALITY
        )[0],
        dtype=np.int32,
    )

    total_first_cycles = 0
    total_second_cycles = 0

    maximum_cpu_python_error = 0
    maximum_cpu_opencv_error = 0

    overflow_count = 0
    block_count = 0

    host_start = time.perf_counter()

    print(
        "RISC-V CPU 32x32 GRAYSCALE "
        "JPEG DCT TEST"
    )

    print(
        f"Input image: {IMAGE_FILE}"
    )

    print(
        f"Crop size: "
        f"{IMAGE_SIZE}x{IMAGE_SIZE}"
    )

    print(
        f"Block size: "
        f"{BLOCK_SIZE}x{BLOCK_SIZE}"
    )

    print(
        f"JPEG quality: {JPEG_QUALITY}"
    )

    print(
        "Vivado runs required: 32"
    )

    for block_row in range(
        0,
        IMAGE_SIZE,
        BLOCK_SIZE,
    ):
        for block_column in range(
            0,
            IMAGE_SIZE,
            BLOCK_SIZE,
        ):
            block_count += 1

            print(
                f"\nProcessing block "
                f"{block_count}/16"
            )

            source_block = grayscale[
                block_row:
                block_row + BLOCK_SIZE,
                block_column:
                block_column + BLOCK_SIZE,
            ]

            centered_block = (
                source_block.astype(np.int64)
                - 128
            )

            (
                first_raw,
                first_cycles,
                first_overflow,
            ) = run_cpu_multiplication(
                dct_q12,
                centered_block,
                (
                    f"block {block_count}, "
                    "D_q12 x X"
                ),
            )

            intermediate = (
                signed_round_divide(
                    first_raw
                )
            )

            check_signed_16(
                "Q12 intermediate",
                intermediate,
            )

            (
                second_raw,
                second_cycles,
                second_overflow,
            ) = run_cpu_multiplication(
                intermediate,
                dct_q12_transpose,
                (
                    f"block {block_count}, "
                    "T x D_q12_transpose"
                ),
            )

            cpu_dct = signed_round_divide(
                second_raw
            )

            python_intermediate = (
                signed_round_divide(
                    dct_q12
                    @ centered_block
                )
            )

            python_dct = (
                signed_round_divide(
                    python_intermediate
                    @ dct_q12_transpose
                )
            )

            opencv_dct = np.rint(
                cv2.dct(
                    centered_block.astype(
                        np.float32
                    )
                )
            ).astype(np.int64)

            cpu_python_error = int(
                np.max(
                    np.abs(
                        cpu_dct
                        - python_dct
                    )
                )
            )

            cpu_opencv_error = int(
                np.max(
                    np.abs(
                        cpu_dct
                        - opencv_dct
                    )
                )
            )

            maximum_cpu_python_error = max(
                maximum_cpu_python_error,
                cpu_python_error,
            )

            maximum_cpu_opencv_error = max(
                maximum_cpu_opencv_error,
                cpu_opencv_error,
            )

            overflow_count += (
                first_overflow
                + second_overflow
            )

            total_first_cycles += (
                first_cycles
            )

            total_second_cycles += (
                second_cycles
            )

            reconstructed_block = (
                reconstruct_block(
                    cpu_dct,
                    luminance_table,
                )
            )

            reconstructed[
                block_row:
                block_row + BLOCK_SIZE,
                block_column:
                block_column + BLOCK_SIZE,
            ] = reconstructed_block

            print(
                f"  First cycles="
                f"{first_cycles}, "
                f"second cycles="
                f"{second_cycles}, "
                f"CPU/Python error="
                f"{cpu_python_error}, "
                f"CPU/OpenCV error="
                f"{cpu_opencv_error}"
            )

    host_seconds = (
        time.perf_counter()
        - host_start
    )

    total_cpu_cycles = (
        total_first_cycles
        + total_second_cycles
    )

    cpu_time_ns = (
        total_cpu_cycles
        * CLOCK_PERIOD_NS
    )

    cpu_time_ms = (
        cpu_time_ns
        / 1_000_000.0
    )

    psnr = calculate_psnr(
        grayscale,
        reconstructed,
    )

    maximum_pixel_error = int(
        np.max(
            np.abs(
                grayscale.astype(np.int16)
                - reconstructed.astype(
                    np.int16
                )
            )
        )
    )

    iio.imwrite(
        ORIGINAL_IMAGE_FILE,
        grayscale,
    )

    iio.imwrite(
        RECONSTRUCTED_IMAGE_FILE,
        reconstructed,
    )

    passed = (
        overflow_count == 0
        and maximum_cpu_python_error == 0
        and maximum_cpu_opencv_error <= 2
        and np.isfinite(psnr)
    )

    report_lines = [
        (
            "RISC-V CPU 32x32 GRAYSCALE "
            "JPEG DCT RESULT"
        ),
        "",
        f"Source image: {IMAGE_FILE}",
        (
            f"Crop size: "
            f"{IMAGE_SIZE}x{IMAGE_SIZE}"
        ),
        (
            f"JPEG block size: "
            f"{BLOCK_SIZE}x{BLOCK_SIZE}"
        ),
        (
            f"Blocks processed: "
            f"{block_count}"
        ),
        (
            "Matrix multiplications executed "
            f"by RTL CPU: {block_count * 2}"
        ),
        (
            f"JPEG quality: "
            f"{JPEG_QUALITY}"
        ),
        (
            f"Q format: "
            f"Q{FRACTION_BITS}"
        ),
        "",
        (
            f"First-stage CPU cycles: "
            f"{total_first_cycles}"
        ),
        (
            f"Second-stage CPU cycles: "
            f"{total_second_cycles}"
        ),
        (
            f"Total RTL CPU cycles: "
            f"{total_cpu_cycles}"
        ),
        (
            "RTL CPU time at 100 MHz: "
            f"{cpu_time_ns} ns "
            f"({cpu_time_ms:.6f} ms)"
        ),
        (
            "Host/Vivado elapsed time: "
            f"{host_seconds:.3f} seconds"
        ),
        "",
        (
            f"Overflow count: "
            f"{overflow_count}"
        ),
        (
            "Maximum CPU-vs-Python "
            "coefficient error: "
            f"{maximum_cpu_python_error}"
        ),
        (
            "Maximum CPU-vs-OpenCV "
            "coefficient error: "
            f"{maximum_cpu_opencv_error}"
        ),
        (
            "Reconstructed-image PSNR: "
            f"{psnr:.6f} dB"
        ),
        (
            "Maximum reconstructed "
            f"pixel error: {maximum_pixel_error}"
        ),
        (
            f"Original crop: "
            f"{ORIGINAL_IMAGE_FILE}"
        ),
        (
            f"Reconstructed crop: "
            f"{RECONSTRUCTED_IMAGE_FILE}"
        ),
    ]

    if passed:
        report_lines.append(
            "STATUS: RISC-V CPU 32x32 "
            "JPEG DCT TEST PASSED"
        )
    else:
        report_lines.append(
            "STATUS: RISC-V CPU 32x32 "
            "JPEG DCT TEST FAILED"
        )

    report = (
        "\n".join(report_lines)
        + "\n"
    )

    RESULT_FILE.write_text(
        report,
        encoding="utf-8",
    )

    print(
        "\n" + report
    )

    print(
        "Detailed result saved to: "
        f"{RESULT_FILE}"
    )

    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(
        main()
    )