from pathlib import Path
import argparse
import os
import shutil
import subprocess
import tempfile
import time
import tkinter as tk
from tkinter import filedialog

import numpy as np
from PIL import Image, ImageOps


SCRIPT_FILE = Path(__file__).resolve()
APPLICATION_DIR = SCRIPT_FILE.parent
PHASE1_DIR = SCRIPT_FILE.parents[2]
REPO_ROOT = SCRIPT_FILE.parents[3]

RUNTIME_DIR = REPO_ROOT / "build" / "runtime" / "grayscale"
INPUT_FILE = RUNTIME_DIR / "grayscale_input.txt"
OUTPUT_FILE = RUNTIME_DIR / "grayscale_output.txt"
RESULTS_DIR = RUNTIME_DIR / "results"

TCL_FILE = PHASE1_DIR / "scripts" / "vivado" / "run_grayscale_sim.tcl"
TESTBENCH_FILE = (
    PHASE1_DIR
    / "testbenches"
    / "matrix_applications"
    / "tb_cpu_grayscale_batch.sv"
)
PROJECT_FILE = REPO_ROOT / "build" / "vivado" / "phase1_riscv_cpu.xpr"

BATCH_PIXELS = 32
CLOCK_HZ = 100_000_000


def find_vivado():
    candidates = []

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


def select_image():
    root = tk.Tk()
    root.withdraw()

    try:
        filename = filedialog.askopenfilename(
            title="Select an image for RISC-V grayscale conversion",
            filetypes=[
                ("Image files", "*.jpg *.jpeg *.png *.bmp *.tif *.tiff"),
                ("All files", "*.*"),
            ],
        )
    finally:
        root.destroy()

    return Path(filename) if filename else None


def load_rgb(path):
    with Image.open(path) as source:
        oriented = ImageOps.exif_transpose(source)

        # Composite transparent pixels onto a white background.
        rgba = oriented.convert("RGBA")
        background = Image.new(
            "RGBA", rgba.size, (255, 255, 255, 255)
        )
        rgb = Image.alpha_composite(
            background, rgba
        ).convert("RGB")

        return np.array(rgb, dtype=np.uint8)


def make_self_test():
    # 33 pixels: a full 32-pixel job plus a final 1-pixel job.
    pixels = np.array(
        [
            (
                (i * 37) % 256,
                (i * 73 + 19) % 256,
                (i * 109 + 41) % 256,
            )
            for i in range(33)
        ],
        dtype=np.uint8,
    )

    pixels[:5] = [
        [0, 0, 0],
        [255, 255, 255],
        [255, 0, 0],
        [0, 255, 0],
        [0, 0, 255],
    ]

    return pixels.reshape(3, 11, 3)


def write_jobs(pixels):
    job_count = (
        len(pixels) + BATCH_PIXELS - 1
    ) // BATCH_PIXELS

    with INPUT_FILE.open("w", encoding="ascii") as handle:
        handle.write(f"{job_count}\n")

        for start in range(0, len(pixels), BATCH_PIXELS):
            batch = pixels[start:start + BATCH_PIXELS]
            handle.write(f"{len(batch)}\n")

            for red, green, blue in batch:
                handle.write(
                    f"{int(red)} {int(green)} {int(blue)}\n"
                )

    return job_count


def read_results(pixel_count, job_count):
    if not OUTPUT_FILE.is_file():
        raise RuntimeError(
            "Vivado did not create grayscale_output.txt."
        )

    sums = np.empty(pixel_count, dtype=np.int64)
    cycle_sum = 0
    offset = 0

    with OUTPUT_FILE.open("r", encoding="ascii") as handle:

        def next_line():
            line = handle.readline()
            if not line:
                raise RuntimeError(
                    "Incomplete grayscale results."
                )
            return line.strip()

        if next_line() != f"GRAYSCALE_RESULTS {job_count}":
            raise RuntimeError(
                "Unexpected grayscale result header."
            )

        for expected_job in range(job_count):
            fields = next_line().split()

            if len(fields) != 4 or fields[0] != "JOB":
                raise RuntimeError("Invalid JOB record.")

            job_id, rows, cycles = map(int, fields[1:])
            expected_rows = min(
                BATCH_PIXELS, pixel_count - offset
            )

            if job_id != expected_job or rows != expected_rows:
                raise RuntimeError(
                    "Incorrect job order or pixel count."
                )

            if cycles <= 0:
                raise RuntimeError(
                    "Invalid CPU cycle count."
                )

            for row in range(rows):
                value = int(next_line())

                if not 0 <= value <= 65280:
                    raise RuntimeError(
                        "CPU sum outside the valid range."
                    )

                sums[offset + row] = value

            offset += rows
            cycle_sum += cycles

        if next_line() != f"TOTAL_PIXELS {pixel_count}":
            raise RuntimeError(
                "Total pixel count mismatch."
            )

        if next_line() != f"TOTAL_CYCLES {cycle_sum}":
            raise RuntimeError(
                "Total cycle count mismatch."
            )

        if next_line() != "STATUS PASS":
            raise RuntimeError(
                "RTL grayscale checks did not pass."
            )

        if handle.read().strip():
            raise RuntimeError(
                "Unexpected trailing result data."
            )

    return sums, cycle_sum


def main():
    parser = argparse.ArgumentParser(
        description="Convert an image using RTL RISC-V matrix calculations."
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Test 33 generated pixels without selecting an image.",
    )
    arguments = parser.parse_args()

    vivado_bat = find_vivado()

    if vivado_bat is None:
        raise FileNotFoundError(
            "Vivado was not found. Set XILINX_VIVADO, add Vivado "
            "to PATH, or install it at the detected fallback path."
        )

    for required in (
        TCL_FILE,
        TESTBENCH_FILE,
        PROJECT_FILE,
    ):
        if not required.is_file():
            raise FileNotFoundError(
                f"Required file not found: {required}"
            )

    if arguments.self_test:
        source_path = None
        rgb = make_self_test()
        source_description = "Generated 33-pixel batch-boundary test"
    else:
        source_path = select_image()

        if source_path is None:
            print("Image selection cancelled.")
            return 0

        rgb = load_rgb(source_path)
        source_description = str(source_path)

    height, width = rgb.shape[:2]
    pixels = rgb.reshape(-1, 3)
    pixel_count = len(pixels)
    job_count = (
        pixel_count + BATCH_PIXELS - 1
    ) // BATCH_PIXELS

    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    run_dir = Path(
        tempfile.mkdtemp(
            prefix="gray_run_",
            dir=RESULTS_DIR,
        )
    )

    print("\nRISC-V CPU FULL-IMAGE GRAYSCALE")
    print(f"Input: {source_description}")
    print(f"Resolution: {width}x{height}")
    print(f"Pixels processed by RTL CPU: {pixel_count:,}")
    print(f"Matrix jobs: {job_count:,}")
    print("Each job: up to 32x3 multiplied by 3x1")
    print("Vivado launches: 1")
    print(f"Vivado: {vivado_bat}")
    print("No resizing or cropping.")
    print(f"Output folder: {run_dir}")
    print()
    print("Large images can take a long time in RTL simulation.")
    print("Do not run another Vivado matrix application simultaneously.")
    print(flush=True)

    Image.fromarray(rgb).save(run_dir / "input_rgb.png")

    started = time.perf_counter()
    write_jobs(pixels)
    OUTPUT_FILE.unlink(missing_ok=True)

    simulation_started = time.perf_counter()

    completed = subprocess.run(
        [
            str(vivado_bat),
            "-mode", "batch",
            "-source", str(TCL_FILE),
            "-notrace",
            "-tclargs",
            str(INPUT_FILE),
            str(OUTPUT_FILE),
        ],
        cwd=str(REPO_ROOT),
        check=False,
    )

    simulation_seconds = (
        time.perf_counter() - simulation_started
    )

    if completed.returncode != 0:
        raise RuntimeError(
            f"Vivado exited with code {completed.returncode}."
        )

    cpu_sums, total_cycles = read_results(
        pixel_count, job_count
    )

    # Software reference is used only to verify CPU results.
    reference_sums = (
        pixels.astype(np.int64)
        @ np.array([77, 150, 29], dtype=np.int64)
    )

    errors = np.abs(cpu_sums - reference_sums)
    mismatch_count = int(np.count_nonzero(errors))
    maximum_error = int(errors.max())

    if mismatch_count:
        failure = (
            f"FAIL: {mismatch_count} incorrect pixels.\n"
            f"Maximum CPU sum error: {maximum_error}\n"
        )
        (run_dir / "result.txt").write_text(
            failure, encoding="utf-8"
        )
        raise RuntimeError(failure)

    # Produce the image from returned RTL CPU results.
    gray = ((cpu_sums + 128) // 256).astype(np.uint8)
    gray = gray.reshape(height, width)

    output_image = run_dir / "grayscale.png"
    Image.fromarray(gray).save(output_image)

    shutil.copy2(
        INPUT_FILE, run_dir / INPUT_FILE.name
    )
    shutil.copy2(
        OUTPUT_FILE, run_dir / OUTPUT_FILE.name
    )

    total_host_seconds = time.perf_counter() - started

    report = [
        "RISC-V CPU FULL-IMAGE GRAYSCALE RESULT",
        "",
        f"Input: {source_description}",
        f"Input/output resolution: {width}x{height}",
        f"Pixels processed by RTL CPU: {pixel_count:,}",
        f"Matrix multiplications: {job_count:,}",
        f"Final job pixels: {pixel_count - (job_count - 1) * 32}",
        f"Total CPU cycles: {total_cycles:,}",
        (
            "Estimated CPU time at 100 MHz: "
            f"{total_cycles / CLOCK_HZ * 1000:.6f} ms"
        ),
        f"Host/Vivado elapsed time: {simulation_seconds:.3f} seconds",
        f"Host processing time: {total_host_seconds:.3f} seconds",
        f"Maximum CPU sum error: {maximum_error}",
        f"Failed pixels: {mismatch_count}",
        "Overflow: 0",
        "",
        "RTL CPU: matrix products and accumulation for every pixel.",
        "Python: image preparation, reference checking, rounding and saving.",
        "CPU cycles include the per-job matrix program overhead.",
        "Reset intervals and host work are excluded from CPU cycles.",
        "100 MHz is the assumed frequency for the time conversion.",
        "Host processing time excludes image loading and result viewing.",
        "PNG output is not guaranteed to be smaller than the input file.",
        "",
        f"Output image: {output_image}",
        "STATUS: ALL FULL-IMAGE GRAYSCALE CHECKS PASSED",
    ]

    if source_path is not None:
        report.insert(
            4,
            f"Original file bytes: {source_path.stat().st_size}",
        )
        report.insert(
            5,
            f"Grayscale PNG bytes: {output_image.stat().st_size}",
        )

    report_text = "\n".join(report) + "\n"
    report_file = run_dir / "result.txt"
    report_file.write_text(
        report_text, encoding="utf-8"
    )

    print()
    print(report_text)
    print(f"Report saved to: {report_file}")

    if not arguments.self_test:
        try:
            os.startfile(str(output_image))
        except OSError as error:
            print(
                "Image saved, but automatic opening failed: "
                f"{error}"
            )

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nInterrupted. No successful result is claimed.")
        raise SystemExit(130)
    except Exception as error:
        print(f"\nERROR: {error}")
        raise SystemExit(1)