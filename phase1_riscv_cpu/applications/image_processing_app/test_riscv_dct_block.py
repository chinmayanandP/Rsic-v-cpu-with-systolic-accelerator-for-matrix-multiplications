from __future__ import annotations

import math
import re
import subprocess
from pathlib import Path

import cv2
import imageio.v3 as iio
import numpy as np


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

RESULT_FILE = (
    JPEG_ROOT
    / "riscv_dct_block_result.txt"
)

IMAGE_FILE = (
    JPEG_ROOT
    / "datasets"
    / "baboon.tiff"
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

BLOCK = 8
FRACTION_BITS = 12
SCALE = 1 << FRACTION_BITS


def make_dct_matrix() -> np.ndarray:
    dct = np.zeros(
        (BLOCK, BLOCK),
        dtype=np.float64,
    )

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

            dct[row, column] = (
                alpha * math.cos(angle)
            )

    return dct


def centered_y_block(
    image: np.ndarray,
) -> np.ndarray:
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

    return np.rint(
        y[:BLOCK, :BLOCK]
    ).astype(np.int64)


def signed_round_divide(
    values: np.ndarray,
) -> np.ndarray:
    values = values.astype(
        np.int64,
        copy=False,
    )

    rounded = (
        np.abs(values) + SCALE // 2
    ) // SCALE

    return np.where(
        values < 0,
        -rounded,
        rounded,
    ).astype(np.int64)


def check_signed_16(
    name: str,
    matrix: np.ndarray,
) -> None:
    minimum = int(np.min(matrix))
    maximum = int(np.max(matrix))

    if minimum < -32768 or maximum > 32767:
        raise ValueError(
            f"{name} is outside signed 16-bit "
            f"range: [{minimum}, {maximum}]"
        )


def write_matrix_input(
    matrix_a: np.ndarray,
    matrix_b: np.ndarray,
) -> None:
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
        memory[A_BASE + index] = (
            int(value) & 0xFFFFFFFF
        )

    for index, value in enumerate(
        matrix_b.reshape(-1)
    ):
        memory[B_BASE + index] = (
            int(value) & 0xFFFFFFFF
        )

    memory[M_WORD] = rows_a
    memory[K_WORD] = columns_a
    memory[N_WORD] = columns_b

    memory[OVERFLOW_WORD] = 0
    memory[DONE_WORD] = 0

    INPUT_FILE.write_text(
        "".join(
            f"{word:08x}\n"
            for word in memory
        ),
        encoding="ascii",
    )


def parse_matrix_output(
    rows: int,
    columns: int,
):
    if not OUTPUT_FILE.is_file():
        raise RuntimeError(
            "Vivado did not create "
            "matrix_output.txt."
        )

    output_text = OUTPUT_FILE.read_text(
        encoding="utf-8"
    )

    required_status = (
        "STATUS: MANUAL CPU MATRIX "
        "MULTIPLICATION PASSED"
    )

    if required_status not in output_text:
        raise RuntimeError(
            "The RTL CPU matrix test did not "
            "report PASS.\n"
            + output_text
        )

    cycle_match = re.search(
        r"CPU cycles:\s*(\d+)",
        output_text,
    )

    overflow_match = re.search(
        r"Overflow flag:\s*(\d+)",
        output_text,
    )

    if (
        cycle_match is None
        or overflow_match is None
    ):
        raise RuntimeError(
            "Cycle or overflow information "
            "is missing."
        )

    if "Matrix C:" not in output_text:
        raise RuntimeError(
            "Matrix C is missing from "
            "matrix_output.txt."
        )

    matrix_section = output_text.split(
        "Matrix C:",
        1,
    )[1]

    matrix_rows = []

    for line in matrix_section.splitlines():
        stripped = line.strip()

        if not stripped:
            continue

        if stripped.startswith("STATUS:"):
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

        matrix_rows.append(values)

        if len(matrix_rows) == rows:
            break

    if len(matrix_rows) != rows:
        raise RuntimeError(
            "Could not parse Matrix C from "
            "matrix_output.txt."
        )

    return (
        np.asarray(
            matrix_rows,
            dtype=np.int64,
        ),
        int(cycle_match.group(1)),
        int(overflow_match.group(1)),
    )


def run_cpu_multiplication(
    matrix_a: np.ndarray,
    matrix_b: np.ndarray,
    label: str,
):
    print()
    print(
        "Starting RTL CPU multiplication: "
        f"{label}"
    )

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
    )

    if completed.returncode != 0:
        raise RuntimeError(
            "Vivado exited with code "
            f"{completed.returncode}."
        )

    return parse_matrix_output(
        matrix_a.shape[0],
        matrix_b.shape[1],
    )


def format_matrix(
    name: str,
    matrix: np.ndarray,
) -> str:
    lines = [f"{name}:"]

    for row in matrix:
        lines.append(
            " ".join(
                f"{int(value):6d}"
                for value in row
            )
        )

    return "\n".join(lines)


def main() -> int:
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
            "ERROR: Required file was "
            "not found:"
        )

        for path in missing_files:
            print(path)

        return 1

    image = np.asarray(
        iio.imread(IMAGE_FILE),
        dtype=np.uint8,
    )

    input_block = centered_y_block(
        image
    )

    dct_q12 = np.rint(
        make_dct_matrix() * SCALE
    ).astype(np.int64)

    (
        first_raw,
        first_cycles,
        first_overflow,
    ) = run_cpu_multiplication(
        dct_q12,
        input_block,
        "D_q12 x X",
    )

    intermediate = signed_round_divide(
        first_raw
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
        dct_q12.T,
        "T x D_q12_transpose",
    )

    cpu_dct = signed_round_divide(
        second_raw
    )

    python_first = (
        dct_q12 @ input_block
    )

    python_intermediate = (
        signed_round_divide(
            python_first
        )
    )

    python_fixed_dct = (
        signed_round_divide(
            python_intermediate
            @ dct_q12.T
        )
    )

    source_image = np.asarray(
        iio.imread(IMAGE_FILE),
        dtype=np.uint8,
    )

    red, green, blue = np.moveaxis(
        source_image.astype(np.float64),
        -1,
        0,
    )

    y_float = (
        0.299 * red
        + 0.587 * green
        + 0.114 * blue
        - 128.0
    )

    opencv_dct = np.rint(
        cv2.dct(
            y_float[
                :BLOCK,
                :BLOCK,
            ].astype(np.float32)
        )
    ).astype(np.int64)

    cpu_vs_python = (
        cpu_dct - python_fixed_dct
    )

    cpu_vs_opencv = (
        cpu_dct - opencv_dct
    )

    total_cycles = (
        first_cycles
        + second_cycles
    )

    time_ns = total_cycles * 10

    report_lines = [
        "RISC-V CPU 8x8 JPEG DCT BLOCK TEST",
        "",
        format_matrix(
            "Centered input X",
            input_block,
        ),
        "",
        format_matrix(
            "CPU fixed-point DCT",
            cpu_dct,
        ),
        "",
        format_matrix(
            "Python fixed-point DCT",
            python_fixed_dct,
        ),
        "",
        format_matrix(
            "Rounded OpenCV DCT",
            opencv_dct,
        ),
        "",
        (
            "First CPU multiplication cycles: "
            f"{first_cycles}"
        ),
        (
            "Second CPU multiplication cycles: "
            f"{second_cycles}"
        ),
        (
            "Total CPU cycles: "
            f"{total_cycles}"
        ),
        (
            "CPU time at 100 MHz: "
            f"{time_ns} ns "
            f"({time_ns / 1_000_000:.6f} ms)"
        ),
        (
            "First overflow flag: "
            f"{first_overflow}"
        ),
        (
            "Second overflow flag: "
            f"{second_overflow}"
        ),
        (
            "Maximum CPU-vs-Python error: "
            f"{int(np.max(np.abs(cpu_vs_python)))}"
        ),
        (
            "Maximum CPU-vs-OpenCV error: "
            f"{int(np.max(np.abs(cpu_vs_opencv)))}"
        ),
    ]

    passed = (
        first_overflow == 0
        and second_overflow == 0
        and np.array_equal(
            cpu_dct,
            python_fixed_dct,
        )
        and int(
            np.max(
                np.abs(cpu_vs_opencv)
            )
        ) <= 2
    )

    if passed:
        report_lines.append(
            "STATUS: RISC-V CPU JPEG "
            "DCT BLOCK TEST PASSED"
        )
    else:
        report_lines.append(
            "STATUS: RISC-V CPU JPEG "
            "DCT BLOCK TEST FAILED"
        )

    report = (
        "\n".join(report_lines)
        + "\n"
    )

    RESULT_FILE.write_text(
        report,
        encoding="utf-8",
    )

    print()
    print(report)

    print(
        "Detailed result saved to: "
        f"{RESULT_FILE}"
    )

    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())