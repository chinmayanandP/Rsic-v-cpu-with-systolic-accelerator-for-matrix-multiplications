from __future__ import annotations

from pathlib import Path

import imageio.v3 as iio
import numpy as np

import encoder as encoder_module

from decoder import JPEGDecoder
from encoder import JPEGEncoder

from riscv_batch_dct_backend import (
    RiscVBatchDCTBackend,
)


APPLICATION_DIR = (
    Path(__file__).resolve().parent
)

SOURCE_IMAGE = (
    APPLICATION_DIR
    / "datasets"
    / "baboon.tiff"
)

TEST_INPUT = (
    APPLICATION_DIR
    / "riscv_jpeg_16x16_input.png"
)

OUTPUT_JPEG = (
    APPLICATION_DIR
    / "riscv_cpu_color_test_Q70.jpg"
)

RECONSTRUCTED_IMAGE = (
    APPLICATION_DIR
    / "riscv_cpu_color_test_reconstructed.png"
)

RESULT_FILE = (
    APPLICATION_DIR
    / "riscv_jpeg_batch_result.txt"
)

QUALITY = 70
TEST_WIDTH = 16
TEST_HEIGHT = 16


def calculate_psnr(
    original: np.ndarray,
    reconstructed: np.ndarray,
) -> float:
    original_float = np.asarray(
        original,
        dtype=np.float64,
    )

    reconstructed_float = np.asarray(
        reconstructed,
        dtype=np.float64,
    )

    mse = float(
        np.mean(
            (
                original_float
                - reconstructed_float
            ) ** 2
        )
    )

    if mse == 0.0:
        return float("inf")

    return float(
        20.0
        * np.log10(
            255.0 / np.sqrt(mse)
        )
    )


def remove_old_outputs() -> None:
    paths = (
        TEST_INPUT,
        OUTPUT_JPEG,
        RECONSTRUCTED_IMAGE,
        RESULT_FILE,
    )

    for path in paths:
        if path.exists():
            path.unlink()


def main() -> int:
    print(
        "RISC-V CPU COLOR "
        "JPEG BATCH TEST"
    )

    print(
        f"Source image: {SOURCE_IMAGE}"
    )

    print(
        f"JPEG quality: {QUALITY}"
    )

    if not SOURCE_IMAGE.is_file():
        print(
            "ERROR: Source image "
            "was not found."
        )
        return 1

    remove_old_outputs()

    source = np.asarray(
        iio.imread(SOURCE_IMAGE),
        dtype=np.uint8,
    )

    if (
        source.ndim != 3
        or source.shape[2] < 3
    ):
        print(
            "ERROR: Source image "
            "must be a color image."
        )
        return 1

    if (
        source.shape[0] < TEST_HEIGHT
        or source.shape[1] < TEST_WIDTH
    ):
        print(
            "ERROR: Source image is "
            "smaller than the requested "
            "test area."
        )
        return 1

    original = source[
        :TEST_HEIGHT,
        :TEST_WIDTH,
        :3,
    ]

    iio.imwrite(
        TEST_INPUT,
        original,
    )

    backend = (
        RiscVBatchDCTBackend()
    )

    original_fdct = (
        encoder_module.FDCT
    )

    encoder_module.FDCT = (
        backend.fdct
    )

    try:
        jpeg_encoder = JPEGEncoder(
            TEST_INPUT
        )

        jpeg_data = jpeg_encoder.encode(
            quality=QUALITY,
            save_path=OUTPUT_JPEG,
            to_gray=False,
            huffman_type="standard",
        )

    finally:
        encoder_module.FDCT = (
            original_fdct
        )

    report = backend.last_report

    if report is None:
        print(
            "ERROR: RISC-V DCT execution "
            "report was not produced."
        )
        return 1

    if not OUTPUT_JPEG.is_file():
        print(
            "ERROR: JPEG encoder did not "
            "create the output JPEG file."
        )
        return 1

    decoder = JPEGDecoder()

    reconstructed = np.asarray(
        decoder.decode(OUTPUT_JPEG),
        dtype=np.uint8,
    )

    iio.imwrite(
        RECONSTRUCTED_IMAGE,
        reconstructed,
    )

    input_size = (
        TEST_INPUT.stat().st_size
    )

    compressed_size = (
        OUTPUT_JPEG.stat().st_size
    )

    reconstructed_size = (
        RECONSTRUCTED_IMAGE.stat().st_size
    )

    if compressed_size > 0:
        compression_ratio = (
            input_size / compressed_size
        )

        size_change_percent = (
            (
                compressed_size
                - input_size
            )
            / input_size
        ) * 100.0

    else:
        compression_ratio = 0.0
        size_change_percent = 0.0

    same_shape = (
        reconstructed.shape
        == original.shape
    )

    if same_shape:
        psnr = calculate_psnr(
            original,
            reconstructed,
        )

        maximum_pixel_error = int(
            np.max(
                np.abs(
                    original.astype(
                        np.int16
                    )
                    - reconstructed.astype(
                        np.int16
                    )
                )
            )
        )

    else:
        psnr = 0.0
        maximum_pixel_error = -1

    checks = {
        "Compressed JPEG file exists":
            OUTPUT_JPEG.is_file(),

        "Compressed JPEG is not empty":
            compressed_size > 0,

        "JPEG byte data was returned":
            len(jpeg_data)
            == compressed_size,

        "Decoded image resolution is unchanged":
            same_shape,

        "RISC-V processed four pixel blocks":
            report.block_count == 4,

        "RISC-V processed three color components":
            report.component_count == 3,

        "RISC-V executed 24 matrix jobs":
            report.matrix_job_count == 24,

        "No RISC-V matrix overflow":
            report.overflow_count == 0,

        "CPU cycle count is valid":
            report.total_cycles > 0,

        "Decoded image quality is valid":
            psnr >= 15.0,
    }

    all_passed = all(
        checks.values()
    )

    report_lines = [
        "RISC-V CPU COLOR JPEG BATCH RESULT",
        "",
        f"Source image: {SOURCE_IMAGE}",
        f"Test input: {TEST_INPUT}",
        f"Compressed JPEG: {OUTPUT_JPEG}",
        (
            "Reconstructed image: "
            f"{RECONSTRUCTED_IMAGE}"
        ),
        f"JPEG quality: {QUALITY}",
        (
            "Input resolution: "
            f"{original.shape[1]}x"
            f"{original.shape[0]}"
        ),
        (
            "Output resolution: "
            f"{reconstructed.shape[1]}x"
            f"{reconstructed.shape[0]}"
            if reconstructed.ndim >= 2
            else
            "Output resolution: invalid"
        ),
        (
            f"Input PNG size: "
            f"{input_size} bytes"
        ),
        (
            "Compressed JPEG size: "
            f"{compressed_size} bytes"
        ),
        (
            "Reconstructed PNG size: "
            f"{reconstructed_size} bytes"
        ),
        (
            "Input-to-JPEG size ratio: "
            f"{compression_ratio:.6f}:1"
        ),
        (
            "JPEG size change: "
            f"{size_change_percent:+.3f}%"
        ),
        f"PSNR: {psnr:.6f} dB",
        (
            "Maximum reconstructed "
            "pixel error: "
            f"{maximum_pixel_error}"
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
            "RISC-V matrix jobs: "
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
            "Total RTL CPU cycles: "
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
        "",
    ]

    print()
    print(
        "RISC-V CPU COLOR JPEG RESULT"
    )

    print(
        "Input resolution: "
        f"{original.shape[1]}x"
        f"{original.shape[0]}"
    )

    if reconstructed.ndim >= 2:
        print(
            "Output resolution: "
            f"{reconstructed.shape[1]}x"
            f"{reconstructed.shape[0]}"
        )

    print(
        f"Input PNG size: "
        f"{input_size} bytes"
    )

    print(
        "Compressed JPEG size: "
        f"{compressed_size} bytes"
    )

    print(
        "Input-to-JPEG size ratio: "
        f"{compression_ratio:.6f}:1"
    )

    print(
        f"PSNR: {psnr:.6f} dB"
    )

    print(
        "Total RTL CPU cycles: "
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

    for description, passed in checks.items():
        if passed:
            line = (
                f"PASS: {description}"
            )
        else:
            line = (
                f"FAIL: {description}"
            )

        print(line)
        report_lines.append(line)

    report_lines.append("")

    if all_passed:
        final_status = (
            "STATUS: RISC-V COLOR JPEG "
            "BATCH TEST PASSED"
        )
    else:
        final_status = (
            "STATUS: RISC-V COLOR JPEG "
            "BATCH TEST FAILED"
        )

    print()
    print(final_status)

    print(
        f"Detailed result: "
        f"{RESULT_FILE}"
    )

    print(
        f"Compressed JPEG: "
        f"{OUTPUT_JPEG}"
    )

    print(
        "Reconstructed image: "
        f"{RECONSTRUCTED_IMAGE}"
    )

    report_lines.append(
        final_status
    )

    RESULT_FILE.write_text(
        "\n".join(report_lines) + "\n",
        encoding="utf-8",
    )

    return (
        0 if all_passed else 1
    )


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