from __future__ import annotations

from pathlib import Path

import imageio.v3 as iio
import numpy as np

from riscv_jpeg_encoder import (
    JPEG_QUALITY,
    encode_image_with_riscv,
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
    / "riscv_padding_19x13_input.png"
)

OUTPUT_JPEG = (
    APPLICATION_DIR
    / "riscv_padding_19x13_Q70.jpg"
)

RECONSTRUCTED_IMAGE = (
    APPLICATION_DIR
    / "riscv_padding_19x13_reconstructed.png"
)

RESULT_FILE = (
    APPLICATION_DIR
    / "riscv_jpeg_padding_result.txt"
)

TEST_WIDTH = 19
TEST_HEIGHT = 13

EXPECTED_PADDED_WIDTH = 24
EXPECTED_PADDED_HEIGHT = 16

EXPECTED_PIXEL_BLOCKS = 6
EXPECTED_MATRIX_JOBS = 36


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
        "RISC-V JPEG AUTOMATIC "
        "PADDING TEST"
    )

    print(
        f"Source image: {SOURCE_IMAGE}"
    )

    print(
        f"Test resolution: "
        f"{TEST_WIDTH}x{TEST_HEIGHT}"
    )

    print(
        "Expected internal padded "
        "resolution: "
        f"{EXPECTED_PADDED_WIDTH}x"
        f"{EXPECTED_PADDED_HEIGHT}"
    )

    print(
        "JPEG quality preset: "
        f"{JPEG_QUALITY} (Balanced)"
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
            "smaller than the test "
            "dimensions."
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

    result = encode_image_with_riscv(
        TEST_INPUT,
        OUTPUT_JPEG,
    )

    reconstructed = np.asarray(
        iio.imread(OUTPUT_JPEG),
        dtype=np.uint8,
    )

    if reconstructed.ndim == 2:
        reconstructed = np.stack(
            (
                reconstructed,
                reconstructed,
                reconstructed,
            ),
            axis=2,
        )

    elif (
        reconstructed.ndim == 3
        and reconstructed.shape[2] >= 3
    ):
        reconstructed = reconstructed[
            :,
            :,
            :3,
        ]

    iio.imwrite(
        RECONSTRUCTED_IMAGE,
        reconstructed,
    )

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

    report = result.dct_report

    checks = {
        "Original width detected correctly":
            result.original_width
            == TEST_WIDTH,

        "Original height detected correctly":
            result.original_height
            == TEST_HEIGHT,

        "Width padded automatically to 24":
            result.padded_width
            == EXPECTED_PADDED_WIDTH,

        "Height padded automatically to 16":
            result.padded_height
            == EXPECTED_PADDED_HEIGHT,

        "Decoded JPEG keeps the original 19x13 resolution":
            same_shape,

        "Six padded pixel blocks were processed":
            report.block_count
            == EXPECTED_PIXEL_BLOCKS,

        "Three color components were processed":
            report.component_count == 3,

        "Thirty-six CPU matrix jobs were executed":
            report.matrix_job_count
            == EXPECTED_MATRIX_JOBS,

        "No RISC-V matrix overflow occurred":
            report.overflow_count == 0,

        "Compressed JPEG was created":
            OUTPUT_JPEG.is_file()
            and result.output_file_size > 0,

        "Decoded image quality is valid":
            psnr >= 15.0,
    }

    all_passed = all(
        checks.values()
    )

    reconstructed_size = (
        RECONSTRUCTED_IMAGE.stat().st_size
    )

    report_lines = [
        "RISC-V JPEG AUTOMATIC PADDING RESULT",
        "",
        f"Source image: {SOURCE_IMAGE}",
        f"Test input: {TEST_INPUT}",
        f"Compressed JPEG: {OUTPUT_JPEG}",
        (
            "Reconstructed image: "
            f"{RECONSTRUCTED_IMAGE}"
        ),
        (
            "JPEG quality preset: "
            f"{JPEG_QUALITY} (Balanced)"
        ),
        (
            "Original resolution: "
            f"{result.original_width}x"
            f"{result.original_height}"
        ),
        (
            "Internal padded resolution: "
            f"{result.padded_width}x"
            f"{result.padded_height}"
        ),
        (
            "Decoded output resolution: "
            f"{reconstructed.shape[1]}x"
            f"{reconstructed.shape[0]}"
            if reconstructed.ndim >= 2
            else
            "Decoded output resolution: invalid"
        ),
        (
            "Original input size: "
            f"{result.input_file_size} bytes"
        ),
        (
            "Compressed JPEG size: "
            f"{result.output_file_size} bytes"
        ),
        (
            "Reconstructed PNG size: "
            f"{reconstructed_size} bytes"
        ),
        (
            "Compression ratio: "
            f"{result.compression_ratio:.6f}:1"
        ),
        (
            "Size reduction: "
            f"{result.size_reduction_percent:+.3f}%"
        ),
        f"PSNR: {psnr:.6f} dB",
        (
            "Maximum reconstructed "
            "pixel error: "
            f"{maximum_pixel_error}"
        ),
        (
            "Padded pixel blocks: "
            f"{report.block_count}"
        ),
        (
            "Color components: "
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
        "AUTOMATIC PADDING RESULT"
    )

    print(
        "Original resolution: "
        f"{result.original_width}x"
        f"{result.original_height}"
    )

    print(
        "Internal padded resolution: "
        f"{result.padded_width}x"
        f"{result.padded_height}"
    )

    print(
        "Decoded output resolution: "
        f"{reconstructed.shape[1]}x"
        f"{reconstructed.shape[0]}"
    )

    print(
        "JPEG quality preset: "
        f"{JPEG_QUALITY} (Balanced)"
    )

    print(
        f"PSNR: {psnr:.6f} dB"
    )

    print(
        "Total RTL CPU cycles: "
        f"{report.total_cycles}"
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
            "STATUS: AUTOMATIC JPEG "
            "PADDING TEST PASSED"
        )
    else:
        final_status = (
            "STATUS: AUTOMATIC JPEG "
            "PADDING TEST FAILED"
        )

    print()
    print(final_status)

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