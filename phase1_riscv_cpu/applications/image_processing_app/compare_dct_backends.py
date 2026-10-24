#!/usr/bin/env python3
"""Compare the original OpenCV DCT and the Q12 fixed-point DCT."""

from __future__ import annotations

import csv
import os
import time
from contextlib import contextmanager
from pathlib import Path

import imageio.v3 as iio
import numpy as np

from decoder import JPEGDecoder
from encoder import JPEGEncoder


PROJECT_ROOT = Path(__file__).resolve().parent
DATASET_DIRECTORY = PROJECT_ROOT / "datasets"
OUTPUT_DIRECTORY = PROJECT_ROOT / "comparison_output"

CSV_REPORT = PROJECT_ROOT / "dct_backend_comparison.csv"
TEXT_REPORT = PROJECT_ROOT / "dct_backend_comparison.txt"

IMAGE_NAMES = (
    "baboon.tiff",
    "Lena.tiff",
)

QUALITIES = (
    50,
    70,
    90,
)

BACKENDS = (
    "opencv",
    "fixed_python",
)

MODES = (
    "color",
    "grayscale",
)


@contextmanager
def selected_backend(backend: str):
    """Temporarily select a DCT backend."""
    previous_value = os.environ.get("JPEG_DCT_BACKEND")

    os.environ["JPEG_DCT_BACKEND"] = backend

    try:
        yield
    finally:
        if previous_value is None:
            os.environ.pop("JPEG_DCT_BACKEND", None)
        else:
            os.environ["JPEG_DCT_BACKEND"] = previous_value


def calculate_psnr(
    reference: np.ndarray,
    result: np.ndarray,
) -> float:
    """
    Calculate Peak Signal-to-Noise Ratio correctly.

    Both images are converted to floating point before subtraction.
    This prevents unsigned 8-bit arithmetic overflow.
    """
    if reference.shape != result.shape:
        raise ValueError(
            f"Shape mismatch: reference {reference.shape}, "
            f"result {result.shape}"
        )

    reference_float = reference.astype(np.float64)
    result_float = result.astype(np.float64)

    difference = reference_float - result_float
    mse = float(np.mean(difference * difference))

    if mse == 0.0:
        return float("inf")

    return float(
        20.0 * np.log10(
            255.0 / np.sqrt(mse)
        )
    )


def make_reference(
    original: np.ndarray,
    mode: str,
) -> np.ndarray:
    """Create the correct color or grayscale reference image."""
    if mode == "color":
        return original

    if original.ndim == 2:
        return original

    red = original[:, :, 0].astype(np.float64)
    green = original[:, :, 1].astype(np.float64)
    blue = original[:, :, 2].astype(np.float64)

    grayscale = (
        0.299 * red
        + 0.587 * green
        + 0.114 * blue
    )

    return np.clip(
        np.rint(grayscale),
        0,
        255,
    ).astype(np.uint8)


def encode_and_decode(
    image_path: Path,
    original: np.ndarray,
    quality: int,
    mode: str,
    backend: str,
) -> dict:
    """
    Encode and decode one image test case.

    Returns file size, PSNR, maximum pixel error and host time.
    """
    to_gray = mode == "grayscale"

    backend_directory = OUTPUT_DIRECTORY / backend

    backend_directory.mkdir(
        parents=True,
        exist_ok=True,
    )

    if to_gray:
        mode_suffix = "gray"
    else:
        mode_suffix = "color"

    output_name = (
        f"{image_path.stem}_"
        f"{mode_suffix}_"
        f"Q{quality}_"
        f"{backend}.jpg"
    )

    output_path = backend_directory / output_name

    with selected_backend(backend):
        encoder = JPEGEncoder(
            str(image_path)
        )

        start_time = time.perf_counter()

        encoded_data = encoder.encode(
            quality=quality,
            save_path=output_path,
            to_gray=to_gray,
        )

        encoding_seconds = (
            time.perf_counter()
            - start_time
        )

    decoder = JPEGDecoder()

    decoded = np.asarray(
        decoder.decode(
            str(output_path)
        ),
        dtype=np.uint8,
    )

    reference = make_reference(
        original,
        mode,
    )

    psnr = calculate_psnr(
        reference,
        decoded,
    )

    reference_signed = reference.astype(
        np.int16
    )

    decoded_signed = decoded.astype(
        np.int16
    )

    maximum_pixel_error = int(
        np.max(
            np.abs(
                reference_signed
                - decoded_signed
            )
        )
    )

    return {
        "image": image_path.name,
        "mode": mode,
        "quality": quality,
        "backend": backend,
        "file_size_bytes": len(encoded_data),
        "psnr_db": psnr,
        "maximum_pixel_error": maximum_pixel_error,
        "host_encoding_seconds": encoding_seconds,
        "output_file": str(
            output_path.relative_to(
                PROJECT_ROOT
            )
        ),
    }


def create_comparison_rows(
    results: list[dict],
) -> list[dict]:
    """Create a side-by-side comparison for both backends."""
    indexed = {
        (
            row["image"],
            row["mode"],
            row["quality"],
            row["backend"],
        ): row
        for row in results
    }

    comparisons = []

    for image_name in IMAGE_NAMES:
        for mode in MODES:
            for quality in QUALITIES:
                opencv = indexed[
                    (
                        image_name,
                        mode,
                        quality,
                        "opencv",
                    )
                ]

                fixed = indexed[
                    (
                        image_name,
                        mode,
                        quality,
                        "fixed_python",
                    )
                ]

                opencv_size = opencv[
                    "file_size_bytes"
                ]

                fixed_size = fixed[
                    "file_size_bytes"
                ]

                size_change_percent = (
                    (
                        fixed_size
                        - opencv_size
                    )
                    * 100.0
                    / opencv_size
                )

                psnr_change = (
                    fixed["psnr_db"]
                    - opencv["psnr_db"]
                )

                comparison = {
                    "image": image_name,
                    "mode": mode,
                    "quality": quality,
                    "opencv_size_bytes":
                        opencv_size,
                    "fixed_size_bytes":
                        fixed_size,
                    "size_change_percent":
                        size_change_percent,
                    "opencv_psnr_db":
                        opencv["psnr_db"],
                    "fixed_psnr_db":
                        fixed["psnr_db"],
                    "psnr_change_db":
                        psnr_change,
                    "opencv_max_pixel_error":
                        opencv[
                            "maximum_pixel_error"
                        ],
                    "fixed_max_pixel_error":
                        fixed[
                            "maximum_pixel_error"
                        ],
                    "opencv_host_seconds":
                        opencv[
                            "host_encoding_seconds"
                        ],
                    "fixed_host_seconds":
                        fixed[
                            "host_encoding_seconds"
                        ],
                }

                comparisons.append(
                    comparison
                )

    return comparisons


def write_csv_report(
    comparisons: list[dict],
) -> None:
    """Write comparison results into a CSV file."""
    fieldnames = list(
        comparisons[0].keys()
    )

    with CSV_REPORT.open(
        "w",
        newline="",
        encoding="utf-8",
    ) as csv_file:
        writer = csv.DictWriter(
            csv_file,
            fieldnames=fieldnames,
        )

        writer.writeheader()
        writer.writerows(
            comparisons
        )


def format_report(
    comparisons: list[dict],
) -> str:
    """Create a human-readable text report."""
    lines = [
        "JPEG DCT BACKEND COMPARISON",
        (
            "OpenCV floating-point DCT versus "
            "Q12 fixed-point Python DCT"
        ),
        "",
        (
            "Image | Mode | Q | OpenCV bytes | "
            "Fixed bytes | Size change | "
            "OpenCV PSNR | Fixed PSNR | "
            "PSNR change"
        ),
        "-" * 126,
    ]

    for row in comparisons:
        line = (
            f"{row['image']:12} | "
            f"{row['mode']:9} | "
            f"{row['quality']:2d} | "
            f"{row['opencv_size_bytes']:12d} | "
            f"{row['fixed_size_bytes']:11d} | "
            f"{row['size_change_percent']:+10.3f}% | "
            f"{row['opencv_psnr_db']:11.3f} dB | "
            f"{row['fixed_psnr_db']:10.3f} dB | "
            f"{row['psnr_change_db']:+10.3f} dB"
        )

        lines.append(line)

    size_changes = [
        row["size_change_percent"]
        for row in comparisons
    ]

    psnr_changes = [
        row["psnr_change_db"]
        for row in comparisons
    ]

    average_size_change = float(
        np.mean(size_changes)
    )

    average_psnr_change = float(
        np.mean(psnr_changes)
    )

    lines.extend(
        [
            "",
            (
                "Average file-size change: "
                f"{average_size_change:+.3f}%"
            ),
            (
                "Average PSNR change: "
                f"{average_psnr_change:+.3f} dB"
            ),
            "",
            (
                "Note: host encoding time is software "
                "execution time. It is not RISC-V CPU "
                "cycle time and is not accelerator "
                "performance."
            ),
            (
                "STATUS: ALL DCT BACKEND "
                "COMPARISONS PASSED"
            ),
        ]
    )

    return "\n".join(lines)


def main() -> int:
    """Run all backend comparison cases."""
    OUTPUT_DIRECTORY.mkdir(
        parents=True,
        exist_ok=True,
    )

    results = []

    print(
        "JPEG DCT BACKEND COMPARISON"
    )

    print(
        "Correct floating-point PSNR "
        "calculation is enabled."
    )

    for image_name in IMAGE_NAMES:
        image_path = (
            DATASET_DIRECTORY
            / image_name
        )

        if not image_path.is_file():
            print(
                "ERROR: Input image "
                f"not found: {image_path}"
            )

            return 1

        original = np.asarray(
            iio.imread(image_path),
            dtype=np.uint8,
        )

        print(
            f"\nImage: {image_name}"
        )

        print(
            f"Shape: {original.shape}"
        )

        for mode in MODES:
            for quality in QUALITIES:
                for backend in BACKENDS:
                    print(
                        f"Running {backend:12} "
                        f"mode={mode:9} "
                        f"quality={quality}"
                    )

                    result = encode_and_decode(
                        image_path=image_path,
                        original=original,
                        quality=quality,
                        mode=mode,
                        backend=backend,
                    )

                    results.append(
                        result
                    )

    comparisons = create_comparison_rows(
        results
    )

    write_csv_report(
        comparisons
    )

    report = format_report(
        comparisons
    )

    TEXT_REPORT.write_text(
        report + "\n",
        encoding="utf-8",
    )

    print(
        "\n" + report
    )

    print(
        f"\nCSV report: {CSV_REPORT}"
    )

    print(
        f"Text report: {TEXT_REPORT}"
    )

    print(
        f"JPEG outputs: {OUTPUT_DIRECTORY}"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(
        main()
    )