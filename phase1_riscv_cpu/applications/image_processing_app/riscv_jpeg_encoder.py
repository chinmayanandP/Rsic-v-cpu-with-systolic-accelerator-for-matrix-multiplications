from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import imageio.v3 as iio
import numpy as np

import encoder as encoder_module

from encoder import JPEGEncoder

from riscv_batch_dct_backend import (
    DCTRunReport,
    RiscVBatchDCTBackend,
)


JPEG_QUALITY = 70
BLOCK_SIZE = 8


@dataclass
class RiscVJPEGResult:
    input_path: Path
    output_path: Path
    original_image: np.ndarray

    original_width: int
    original_height: int

    padded_width: int
    padded_height: int

    input_file_size: int
    output_file_size: int

    jpeg_data: bytes
    dct_report: DCTRunReport

    @property
    def compression_ratio(self) -> float:
        if self.output_file_size == 0:
            return 0.0

        return (
            self.input_file_size
            / self.output_file_size
        )

    @property
    def size_reduction_percent(self) -> float:
        if self.input_file_size == 0:
            return 0.0

        return (
            (
                self.input_file_size
                - self.output_file_size
            )
            / self.input_file_size
        ) * 100.0


def normalize_color_image(
    image: np.ndarray,
) -> np.ndarray:
    converted = np.asarray(image)

    if converted.ndim == 2:
        converted = np.stack(
            (
                converted,
                converted,
                converted,
            ),
            axis=2,
        )

    elif (
        converted.ndim == 3
        and converted.shape[2] == 1
    ):
        converted = np.repeat(
            converted,
            3,
            axis=2,
        )

    elif (
        converted.ndim == 3
        and converted.shape[2] >= 3
    ):
        converted = converted[
            :,
            :,
            :3,
        ]

    else:
        raise ValueError(
            "Unsupported image structure. "
            "Select a normal JPG, JPEG, PNG, "
            "BMP or TIFF image."
        )

    if converted.dtype == np.uint8:
        return converted.copy()

    converted_float = converted.astype(
        np.float64
    )

    minimum = float(
        np.min(converted_float)
    )

    maximum = float(
        np.max(converted_float)
    )

    if (
        minimum >= 0.0
        and maximum <= 1.0
    ):
        converted_float *= 255.0

    return np.clip(
        np.rint(converted_float),
        0,
        255,
    ).astype(np.uint8)


class PaddedRiscVJPEGEncoder(
    JPEGEncoder
):
    def load_image(
        self,
        image_path,
    ) -> None:
        loaded = iio.imread(
            image_path
        )

        original = normalize_color_image(
            loaded
        )

        self.original_image = original

        self.image_height = int(
            original.shape[0]
        )

        self.image_width = int(
            original.shape[1]
        )

        pad_height = (
            -self.image_height
        ) % BLOCK_SIZE

        pad_width = (
            -self.image_width
        ) % BLOCK_SIZE

        self.padded_height = (
            self.image_height
            + pad_height
        )

        self.padded_width = (
            self.image_width
            + pad_width
        )

        self.image = np.pad(
            original,
            (
                (0, pad_height),
                (0, pad_width),
                (0, 0),
            ),
            mode="edge",
        )


def encode_image_with_riscv(
    input_path: str | Path,
    output_path: str | Path,
) -> RiscVJPEGResult:
    input_path = Path(
        input_path
    ).resolve()

    output_path = Path(
        output_path
    ).resolve()

    if not input_path.is_file():
        raise FileNotFoundError(
            "Input image does not exist: "
            f"{input_path}"
        )

    output_path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    backend = (
        RiscVBatchDCTBackend()
    )

    jpeg_encoder = (
        PaddedRiscVJPEGEncoder(
            input_path
        )
    )

    original_fdct = (
        encoder_module.FDCT
    )

    encoder_module.FDCT = (
        backend.fdct
    )

    try:
        jpeg_data = jpeg_encoder.encode(
            quality=JPEG_QUALITY,
            save_path=output_path,
            to_gray=False,
            huffman_type="standard",
        )

    finally:
        encoder_module.FDCT = (
            original_fdct
        )

    dct_report = (
        backend.last_report
    )

    if dct_report is None:
        raise RuntimeError(
            "The RISC-V DCT backend "
            "did not return a report."
        )

    if not output_path.is_file():
        raise RuntimeError(
            "The JPEG encoder did not "
            "create the output file."
        )

    return RiscVJPEGResult(
        input_path=input_path,
        output_path=output_path,

        original_image=(
            jpeg_encoder.original_image
        ),

        original_width=(
            jpeg_encoder.image_width
        ),

        original_height=(
            jpeg_encoder.image_height
        ),

        padded_width=(
            jpeg_encoder.padded_width
        ),

        padded_height=(
            jpeg_encoder.padded_height
        ),

        input_file_size=(
            input_path.stat().st_size
        ),

        output_file_size=(
            output_path.stat().st_size
        ),

        jpeg_data=jpeg_data,
        dct_report=dct_report,
    )