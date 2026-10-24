from pathlib import Path
import subprocess
import time


APPLICATION_DIR = Path(__file__).resolve().parent
PROJECT_DIR = APPLICATION_DIR.parent

VIVADO_BAT = Path(r"D:\vivado\2026.1\Vivado\bin\vivado.bat")
TCL_FILE = PROJECT_DIR / "run_matrix_sim.tcl"
PROJECT_FILE = PROJECT_DIR / "Project Final riscv.xpr"

INPUT_FILE = PROJECT_DIR / "matrix_input.mem"
OUTPUT_FILE = PROJECT_DIR / "matrix_output.txt"
REPORT_FILE = APPLICATION_DIR / "riscv_grayscale_test_result.txt"

CLOCK_HZ = 100_000_000

# Existing CPU matrix-program memory layout, in 32-bit words.
MEMORY_WORDS = 4096
A_BASE = 0
B_BASE = 1024
M_WORD = 3072
K_WORD = 3073
N_WORD = 3074

WEIGHTS = (77, 150, 29)


def build_test_pixels():
    pixels = [
        (0, 0, 0),
        (255, 255, 255),
        (255, 0, 0),
        (0, 255, 0),
        (0, 0, 255),
        (128, 128, 128),
        (255, 255, 0),
        (0, 255, 255),
        (255, 0, 255),
        (1, 1, 1),
        (254, 254, 254),
        (100, 150, 200),
    ]

    for i in range(20):
        pixels.append(
            (
                (i * 37) % 256,
                (i * 73 + 19) % 256,
                (i * 109 + 41) % 256,
            )
        )

    return pixels


def write_input(pixels):
    memory = [0] * MEMORY_WORDS

    # Matrix A: 32 rows, each containing R, G, B.
    for row, pixel in enumerate(pixels):
        for column, value in enumerate(pixel):
            memory[A_BASE + row * 3 + column] = value

    # Matrix B: three rows and one column.
    for row, weight in enumerate(WEIGHTS):
        memory[B_BASE + row] = weight

    memory[M_WORD] = len(pixels)
    memory[K_WORD] = 3
    memory[N_WORD] = 1

    INPUT_FILE.write_text(
        "".join(f"{word & 0xFFFFFFFF:08x}\n" for word in memory),
        encoding="ascii",
    )


def read_result(pixel_count):
    if not OUTPUT_FILE.is_file():
        raise RuntimeError("Vivado did not create matrix_output.txt.")

    lines = [
        line.strip()
        for line in OUTPUT_FILE.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]

    required_lines = [
        f"A dimensions: {pixel_count}x3",
        "B dimensions: 3x1",
        f"C dimensions: {pixel_count}x1",
        "Overflow flag: 0",
        "STATUS: MANUAL CPU MATRIX MULTIPLICATION PASSED",
    ]

    for expected in required_lines:
        if expected not in lines:
            raise RuntimeError(
                f"Missing successful result field: {expected}\n"
                f"Inspect: {OUTPUT_FILE}"
            )

    cycle_lines = [
        line for line in lines if line.startswith("CPU cycles:")
    ]

    if len(cycle_lines) != 1:
        raise RuntimeError("Missing or ambiguous CPU cycle count.")

    cycles = int(cycle_lines[0].split(":", 1)[1].strip())
    if cycles <= 0:
        raise RuntimeError("CPU cycle count must be positive.")

    start = lines.index("Matrix C:") + 1
    result_rows = lines[start:start + pixel_count]

    if len(result_rows) != pixel_count:
        raise RuntimeError("Incomplete result matrix.")

    sums = []
    for row in result_rows:
        fields = row.split()
        if len(fields) != 1:
            raise RuntimeError(f"Expected one result per row: {row}")
        sums.append(int(fields[0]))

    return sums, cycles


def main():
    for required_file in (VIVADO_BAT, TCL_FILE, PROJECT_FILE):
        if not required_file.is_file():
            raise FileNotFoundError(f"Required file not found: {required_file}")

    pixels = build_test_pixels()

    # Python computes a reference only for checking the RTL results.
    expected_sums = [
        sum(value * weight for value, weight in zip(pixel, WEIGHTS))
        for pixel in pixels
    ]

    print("RISC-V CPU RGB TO GRAYSCALE VERIFICATION")
    print("Pixels tested: 32")
    print("Matrix A: 32x3")
    print("Matrix B: 3x1")
    print("Matrix C: 32x1")
    print("Weights: 77, 150, 29")
    print("Python scales the returned sums using (sum + 128) // 256.")
    print()
    print("Do not run another matrix or JPEG simulation simultaneously.")
    print("Starting Vivado...")
    print(flush=True)

    # These are the existing manual simulation's exchange files.
    write_input(pixels)
    OUTPUT_FILE.unlink(missing_ok=True)
    REPORT_FILE.unlink(missing_ok=True)

    started = time.perf_counter()

    completed = subprocess.run(
        [
            str(VIVADO_BAT),
            "-mode", "batch",
            "-source", str(TCL_FILE),
            "-notrace",
        ],
        cwd=str(PROJECT_DIR),
        check=False,
    )

    host_seconds = time.perf_counter() - started

    if completed.returncode != 0:
        raise RuntimeError(
            f"Vivado exited with code {completed.returncode}."
        )

    actual_sums, cycles = read_result(len(pixels))

    errors = 0
    report = [
        "RISC-V CPU RGB TO GRAYSCALE VERIFICATION",
        "",
        "Matrix dimensions: 32x3 multiplied by 3x1",
        "Matrix multiplications executed: 1",
        "Pixels tested: 32",
        "",
        "Pixel | R G B | CPU sum | Gray | Check",
    ]

    for index, (pixel, actual, expected) in enumerate(
        zip(pixels, actual_sums, expected_sums), start=1
    ):
        # Output comes from the CPU result, not the Python reference.
        gray = (actual + 128) // 256

        passed = actual == expected and 0 <= gray <= 255
        if not passed:
            errors += 1

        red, green, blue = pixel
        report.append(
            f"{index:2d} | {red:3d} {green:3d} {blue:3d} | "
            f"{actual:5d} | {gray:3d} | "
            f"{'PASS' if passed else 'FAIL'}"
        )

    maximum_error = max(
        abs(actual - expected)
        for actual, expected in zip(actual_sums, expected_sums)
    )

    report.extend([
        "",
        f"CPU cycles: {cycles}",
        f"Estimated CPU time at 100 MHz: {cycles / CLOCK_HZ * 1000:.6f} ms",
        f"Host/Vivado elapsed time: {host_seconds:.3f} seconds",
        f"Maximum CPU sum error: {maximum_error}",
        "Overflow flag: 0",
        f"Failed pixels: {errors}",
        "",
        "Cycle count covers the matrix program measured by the testbench.",
        "It excludes Python preparation, scaling, and file transfers.",
        "100 MHz is the assumed clock for the CPU-time conversion.",
        "",
        (
            "STATUS: ALL RISC-V GRAYSCALE CHECKS PASSED"
            if errors == 0
            else "STATUS: RISC-V GRAYSCALE CHECKS FAILED"
        ),
    ])

    report_text = "\n".join(report) + "\n"
    REPORT_FILE.write_text(report_text, encoding="utf-8")

    print()
    print(report_text)
    print(f"Report saved to: {REPORT_FILE}")

    return 0 if errors == 0 else 1


if __name__ == "__main__":
    try:
        exit_code = main()
    except Exception as error:
        print(f"\nERROR: {error}")
        exit_code = 1

    raise SystemExit(exit_code)