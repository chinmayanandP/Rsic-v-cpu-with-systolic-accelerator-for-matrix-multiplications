from __future__ import annotations

import argparse
import os
import shutil
import subprocess
from pathlib import Path


MAX_DIMENSION = 32
MIN_ELEMENT = -32768
MAX_ELEMENT = 32767
MEMORY_WORDS = 4096

A_WORD_BASE = 0
B_WORD_BASE = 1024
C_WORD_BASE = 2048

M_WORD = 3072
K_WORD = 3073
N_WORD = 3074
OVERFLOW_WORD = 3075
DONE_WORD = 3076

SCRIPT_FILE = Path(__file__).resolve()
PHASE1_DIR = SCRIPT_FILE.parents[2]
REPO_ROOT = SCRIPT_FILE.parents[3]

RUNTIME_DIR = REPO_ROOT / "build" / "runtime" / "matrix"
INPUT_FILE = RUNTIME_DIR / "matrix_input.mem"
OUTPUT_FILE = RUNTIME_DIR / "matrix_output.txt"

TCL_FILE = (
    PHASE1_DIR
    / "scripts"
    / "vivado"
    / "run_matrix_sim.tcl"
)

PROJECT_FILE = (
    REPO_ROOT
    / "build"
    / "vivado"
    / "phase1_riscv_cpu.xpr"
)


def read_matrix(name: str) -> list[list[int]]:
    print()
    print(f"Enter Matrix {name} one row at a time.")
    print("Separate values using spaces or commas.")
    print("Press Enter on an empty row when complete.")

    matrix: list[list[int]] = []
    expected_columns: int | None = None

    while True:
        row_number = len(matrix) + 1
        line = input(f"{name} row {row_number}: ").strip()

        if not line:
            if matrix:
                break

            print("ERROR: The matrix must contain at least one row.")
            continue

        parts = line.replace(",", " ").split()

        try:
            row = [int(value, 10) for value in parts]
        except ValueError:
            print("ERROR: Enter decimal integers only.")
            print("Please enter this row again.")
            continue

        if not row:
            print("ERROR: The row must contain at least one integer.")
            continue

        if len(row) > MAX_DIMENSION:
            print(
                f"ERROR: A row may contain at most "
                f"{MAX_DIMENSION} values."
            )
            print("Please enter this row again.")
            continue

        if expected_columns is None:
            expected_columns = len(row)

        elif len(row) != expected_columns:
            print(
                f"ERROR: This row contains {len(row)} values, "
                f"but previous rows contain {expected_columns} values."
            )
            print(
                "All rows in a matrix must contain "
                "the same number of values."
            )
            print("Please enter this row again.")
            continue

        invalid_values = [
            value
            for value in row
            if value < MIN_ELEMENT or value > MAX_ELEMENT
        ]

        if invalid_values:
            print(
                "ERROR: Every element must be in the signed "
                "16-bit range."
            )
            print(
                f"Allowed range: {MIN_ELEMENT} to {MAX_ELEMENT}"
            )
            print("Please enter this row again.")
            continue

        if len(matrix) >= MAX_DIMENSION:
            print(
                f"ERROR: A matrix may contain at most "
                f"{MAX_DIMENSION} rows."
            )
            break

        matrix.append(row)

    return matrix


def dimensions(
    matrix: list[list[int]],
) -> tuple[int, int]:

    return len(matrix), len(matrix[0])


def validate_multiplication(
    matrix_a: list[list[int]],
    matrix_b: list[list[int]],
) -> tuple[int, int, int]:

    a_rows, a_columns = dimensions(matrix_a)
    b_rows, b_columns = dimensions(matrix_b)

    if a_columns != b_rows:
        raise ValueError(
            "Matrix multiplication is not possible.\n"
            f"Matrix A is {a_rows}x{a_columns}.\n"
            f"Matrix B is {b_rows}x{b_columns}.\n"
            f"Matrix A has {a_columns} columns, "
            f"but Matrix B has {b_rows} rows.\n"
            f"Matrix B must contain exactly {a_columns} rows."
        )

    m = a_rows
    k = a_columns
    n = b_columns

    return m, k, n


def unsigned_word(value: int) -> int:
    return value & 0xFFFFFFFF


def write_memory_file(
    matrix_a: list[list[int]],
    matrix_b: list[list[int]],
    m: int,
    k: int,
    n: int,
) -> None:

    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    memory = [0] * MEMORY_WORDS

    flat_a = [
        value
        for row in matrix_a
        for value in row
    ]

    flat_b = [
        value
        for row in matrix_b
        for value in row
    ]

    for index, value in enumerate(flat_a):
        memory[
            A_WORD_BASE + index
        ] = unsigned_word(value)

    for index, value in enumerate(flat_b):
        memory[
            B_WORD_BASE + index
        ] = unsigned_word(value)

    memory[M_WORD] = m
    memory[K_WORD] = k
    memory[N_WORD] = n
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


def find_vivado() -> Path | None:
    candidates: list[Path] = []

    xilinx_vivado = os.environ.get("XILINX_VIVADO")
    if xilinx_vivado:
        candidates.append(
            Path(xilinx_vivado) / "bin" / "vivado.bat"
        )

    path_vivado = shutil.which("vivado.bat")
    if path_vivado:
        candidates.append(Path(path_vivado))

    candidates.append(
        Path(r"D:\vivado\2026.1\Vivado\bin\vivado.bat")
    )

    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()

    return None


def run_vivado() -> int:
    vivado_bat = find_vivado()

    if vivado_bat is None:
        print()
        print("ERROR: Vivado was not found.")
        print(
            "Set XILINX_VIVADO, add Vivado to PATH, "
            "or install it at the detected fallback path."
        )
        return 1

    if not PROJECT_FILE.is_file():
        print()
        print("ERROR: Portable Vivado project was not found:")
        print(PROJECT_FILE)
        print(
            "Run phase1_riscv_cpu\\scripts\\windows"
            "\\create_vivado_project.bat first."
        )
        return 1

    if not TCL_FILE.is_file():
        print()
        print("ERROR: Missing Vivado Tcl script:")
        print(TCL_FILE)
        return 1

    if OUTPUT_FILE.exists():
        OUTPUT_FILE.unlink()

    print()
    print("Starting Vivado XSim...")
    print("Large matrices can take several minutes.")
    print(f"Vivado: {vivado_bat}")
    print(f"Input: {INPUT_FILE}")
    print(f"Output: {OUTPUT_FILE}")

    completed = subprocess.run(
        [
            str(vivado_bat),
            "-mode",
            "batch",
            "-source",
            str(TCL_FILE),
            "-notrace",
            "-tclargs",
            str(INPUT_FILE),
            str(OUTPUT_FILE),
        ],
        cwd=REPO_ROOT,
        check=False,
    )

    if completed.returncode != 0:
        print()
        print(
            f"ERROR: Vivado exited with code "
            f"{completed.returncode}."
        )
        return completed.returncode

    if not OUTPUT_FILE.is_file():
        print()
        print(
            "ERROR: XSim did not create matrix_output.txt."
        )
        return 1

    print()
    print(
        OUTPUT_FILE.read_text(
            encoding="utf-8"
        )
    )

    return 0

def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Enter matrices and run the RTL "
            "RISC-V CPU simulation."
        )
    )

    parser.add_argument(
        "--prepare-only",
        action="store_true",
        help=(
            "Generate matrix_input.mem "
            "without starting Vivado."
        ),
    )

    arguments = parser.parse_args()

    print("RISC-V CPU MATRIX MULTIPLICATION")
    print("Allowed size: 1 to 32 rows/columns")
    print(
        f"Allowed element range: "
        f"{MIN_ELEMENT} to {MAX_ELEMENT}"
    )

    while True:
        matrix_a = read_matrix("A")
        matrix_b = read_matrix("B")

        try:
            m, k, n = validate_multiplication(
                matrix_a,
                matrix_b,
            )

        except ValueError as error:
            print()
            print("ERROR:")
            print(error)
            print()
            print(
                "Both matrices must be entered again."
            )

            input(
                "Press Enter to restart matrix entry..."
            )

            continue

        break

    print()
    print(f"Detected Matrix A: {m}x{k}")
    print(f"Detected Matrix B: {k}x{n}")
    print(f"Expected Matrix C: {m}x{n}")

    write_memory_file(
        matrix_a,
        matrix_b,
        m,
        k,
        n,
    )

    print(f"Created: {INPUT_FILE}")

    if arguments.prepare_only:
        print(
            "Prepare-only mode: Vivado was not started."
        )
        return 0

    return run_vivado()


if __name__ == "__main__":
    try:
        raise SystemExit(main())

    except KeyboardInterrupt:
        print()
        print("Operation cancelled.")
        raise SystemExit(130)