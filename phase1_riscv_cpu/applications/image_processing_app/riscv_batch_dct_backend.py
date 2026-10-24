from __future__ import annotations

import math
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path

import numpy as np


BLOCK_SIZE = 8
Q_BITS = 12
Q_SCALE = 1 << Q_BITS

APPLICATION_DIR = Path(__file__).resolve().parent
PROJECT_DIR = APPLICATION_DIR.parent

INPUT_FILE = (
    PROJECT_DIR /
    "dct_batch_input.mem"
)

OUTPUT_FILE = (
    PROJECT_DIR /
    "dct_batch_output.txt"
)

TCL_FILE = (
    PROJECT_DIR /
    "run_matrix_batch_sim.tcl"
)

VIVADO_BAT = Path(
    r"D:\vivado\2026.1\Vivado\bin\vivado.bat"
)


@dataclass
class BatchRunResult:
    matrices: list[np.ndarray]
    job_cycles: list[int]
    total_cycles: int
    overflow_count: int
    elapsed_seconds: float


@dataclass
class DCTRunReport:
    block_count: int
    component_count: int
    matrix_job_count: int
    first_stage_cycles: int
    second_stage_cycles: int
    total_cycles: int
    overflow_count: int
    first_stage_elapsed_seconds: float
    second_stage_elapsed_seconds: float

    @property
    def total_elapsed_seconds(self) -> float:
        return (
            self.first_stage_elapsed_seconds
            + self.second_stage_elapsed_seconds
        )

    @property
    def cpu_time_seconds_at_100_mhz(self) -> float:
        return (
            self.total_cycles /
            100_000_000.0
        )


def build_q12_dct_matrix() -> np.ndarray:
    matrix = np.zeros(
        (BLOCK_SIZE, BLOCK_SIZE),
        dtype=np.int64,
    )

    for frequency in range(BLOCK_SIZE):
        if frequency == 0:
            alpha = math.sqrt(
                1.0 / BLOCK_SIZE
            )
        else:
            alpha = math.sqrt(
                2.0 / BLOCK_SIZE
            )

        for sample in range(BLOCK_SIZE):
            coefficient = (
                alpha
                * math.cos(
                    (
                        (2 * sample + 1)
                        * frequency
                        * math.pi
                    )
                    / (2 * BLOCK_SIZE)
                )
            )

            matrix[frequency, sample] = int(
                round(
                    coefficient
                    * Q_SCALE
                )
            )

    return matrix


def round_shift_q12(
    values: np.ndarray,
) -> np.ndarray:
    values = np.asarray(
        values,
        dtype=np.int64,
    )

    magnitude = np.abs(values)

    rounded = (
        magnitude
        + (Q_SCALE // 2)
    ) >> Q_BITS

    return np.where(
        values < 0,
        -rounded,
        rounded,
    ).astype(np.int64)


def unsigned_hex_word(
    value: int,
) -> str:
    return (
        f"{int(value) & 0xFFFFFFFF:08x}"
    )


def validate_matrix(
    matrix: np.ndarray,
    name: str,
) -> np.ndarray:
    converted = np.asarray(
        matrix,
        dtype=np.int64,
    )

    if converted.shape != (
        BLOCK_SIZE,
        BLOCK_SIZE,
    ):
        raise ValueError(
            f"{name} must be 8x8, but "
            f"its shape is {converted.shape}."
        )

    minimum = int(converted.min())
    maximum = int(converted.max())

    if (
        minimum < -32768
        or maximum > 32767
    ):
        raise ValueError(
            f"{name} values must be within "
            "the signed 16-bit range. "
            f"Observed range: "
            f"{minimum} to {maximum}."
        )

    return converted


def write_batch_input(
    jobs: list[
        tuple[np.ndarray, np.ndarray]
    ],
) -> None:
    if not jobs:
        raise ValueError(
            "At least one matrix job "
            "is required."
        )

    lines = [str(len(jobs))]

    for job_id, job in enumerate(jobs):
        matrix_a, matrix_b = job

        matrix_a = validate_matrix(
            matrix_a,
            f"Job {job_id} Matrix A",
        )

        matrix_b = validate_matrix(
            matrix_b,
            f"Job {job_id} Matrix B",
        )

        lines.append(str(job_id))

        for matrix in (
            matrix_a,
            matrix_b,
        ):
            for value in matrix.reshape(-1):
                lines.append(
                    unsigned_hex_word(
                        int(value)
                    )
                )

    INPUT_FILE.write_text(
        "\n".join(lines) + "\n",
        encoding="ascii",
    )


def parse_batch_output(
    expected_jobs: int,
) -> tuple[
    list[np.ndarray],
    list[int],
    int,
    int,
]:
    if not OUTPUT_FILE.is_file():
        raise FileNotFoundError(
            "XSim did not create "
            "dct_batch_output.txt."
        )

    lines = OUTPUT_FILE.read_text(
        encoding="utf-8"
    ).splitlines()

    matrices_by_id = {}
    cycles_by_id = {}
    overflow_by_id = {}
    status_by_id = {}

    total_cycles = -1
    final_status = ""
    index = 0

    while index < len(lines):
        line = lines[index].strip()

        if line.startswith("JOB "):
            job_id = int(
                line.split()[1]
            )

            cycles_by_id[job_id] = int(
                lines[index + 1].split()[1]
            )

            overflow_by_id[job_id] = int(
                lines[index + 2].split()[1]
            )

            if (
                lines[index + 3].strip()
                != "MATRIX_C"
            ):
                raise ValueError(
                    "Missing MATRIX_C for "
                    f"job {job_id}."
                )

            rows = []

            for row_offset in range(
                BLOCK_SIZE
            ):
                row = [
                    int(value, 10)
                    for value in lines[
                        index + 4 + row_offset
                    ].split()
                ]

                if (
                    len(row)
                    != BLOCK_SIZE
                ):
                    raise ValueError(
                        "Invalid result row "
                        f"for job {job_id}."
                    )

                rows.append(row)

            matrices_by_id[job_id] = (
                np.asarray(
                    rows,
                    dtype=np.int64,
                )
            )

            status_by_id[job_id] = (
                lines[index + 12].strip()
            )

            index += 14
            continue

        if line.startswith(
            "TOTAL_CYCLES "
        ):
            total_cycles = int(
                line.split()[1]
            )

        elif line.startswith(
            "STATUS "
        ):
            final_status = (
                line.split()[1]
            )

        index += 1

    expected_ids = list(
        range(expected_jobs)
    )

    if (
        sorted(matrices_by_id)
        != expected_ids
    ):
        raise ValueError(
            "Returned job IDs do not match "
            "the requested batch job IDs."
        )

    failed_jobs = [
        job_id
        for job_id in expected_ids
        if (
            status_by_id.get(job_id)
            != "JOB_STATUS PASS"
        )
    ]

    if failed_jobs:
        raise RuntimeError(
            "XSim reported failed jobs: "
            f"{failed_jobs}"
        )

    if final_status != "PASS":
        raise RuntimeError(
            "XSim batch status is "
            f"{final_status!r}."
        )

    if total_cycles < 1:
        raise ValueError(
            "XSim returned an invalid "
            "total cycle count."
        )

    matrices = [
        matrices_by_id[job_id]
        for job_id in expected_ids
    ]

    job_cycles = [
        cycles_by_id[job_id]
        for job_id in expected_ids
    ]

    overflow_count = sum(
        1
        for job_id in expected_ids
        if overflow_by_id[job_id] != 0
    )

    return (
        matrices,
        job_cycles,
        total_cycles,
        overflow_count,
    )


def run_matrix_batch(
    jobs: list[
        tuple[np.ndarray, np.ndarray]
    ],
    stage_name: str,
) -> BatchRunResult:
    if not VIVADO_BAT.is_file():
        raise FileNotFoundError(
            f"Vivado was not found at: "
            f"{VIVADO_BAT}"
        )

    if not TCL_FILE.is_file():
        raise FileNotFoundError(
            f"Missing Tcl script: "
            f"{TCL_FILE}"
        )

    write_batch_input(jobs)

    if OUTPUT_FILE.exists():
        OUTPUT_FILE.unlink()

    print()
    print(
        f"Starting {stage_name}: "
        f"{len(jobs)} matrix jobs"
    )

    start_time = time.perf_counter()

    completed = subprocess.run(
        [
            str(VIVADO_BAT),
            "-mode",
            "batch",
            "-source",
            str(TCL_FILE),
            "-notrace",
        ],
        cwd=PROJECT_DIR,
        check=False,
    )

    elapsed_seconds = (
        time.perf_counter()
        - start_time
    )

    if completed.returncode != 0:
        raise RuntimeError(
            f"Vivado failed during "
            f"{stage_name} with exit code "
            f"{completed.returncode}."
        )

    (
        matrices,
        job_cycles,
        total_cycles,
        overflow_count,
    ) = parse_batch_output(
        len(jobs)
    )

    print(
        f"Completed {stage_name}: "
        f"cycles={total_cycles}, "
        f"overflow jobs={overflow_count}, "
        f"elapsed={elapsed_seconds:.3f} seconds"
    )

    return BatchRunResult(
        matrices=matrices,
        job_cycles=job_cycles,
        total_cycles=total_cycles,
        overflow_count=overflow_count,
        elapsed_seconds=elapsed_seconds,
    )


class RiscVBatchDCTBackend:
    def __init__(self) -> None:
        self.dct_matrix_q12 = (
            build_q12_dct_matrix()
        )

        self.last_report = None

    def fdct(
        self,
        image: np.ndarray,
        block_size: int = BLOCK_SIZE,
        color_space: str = "YUV",
    ) -> np.ndarray:
        if block_size != BLOCK_SIZE:
            raise ValueError(
                "The RISC-V DCT backend "
                "supports only 8x8 blocks."
            )

        working = np.asarray(
            image,
            dtype=np.float64,
        ).copy()

        if working.ndim != 3:
            raise ValueError(
                "The JPEG DCT input must "
                "have three dimensions."
            )

        (
            height,
            width,
            component_count,
        ) = working.shape

        if (
            height % BLOCK_SIZE != 0
            or width % BLOCK_SIZE != 0
        ):
            raise ValueError(
                "The DCT input must be padded "
                "to multiples of 8 before "
                "calling the RISC-V backend."
            )

        if color_space == "YUV":
            working[:, :, 0] -= 128.0

        integer_samples = np.rint(
            working
        ).astype(np.int64)

        locations = []
        first_stage_jobs = []

        for block_row in range(
            0,
            height,
            BLOCK_SIZE,
        ):
            for block_column in range(
                0,
                width,
                BLOCK_SIZE,
            ):
                for component in range(
                    component_count
                ):
                    block = integer_samples[
                        block_row:
                        block_row + BLOCK_SIZE,
                        block_column:
                        block_column + BLOCK_SIZE,
                        component,
                    ]

                    locations.append(
                        (
                            block_row,
                            block_column,
                            component,
                        )
                    )

                    first_stage_jobs.append(
                        (
                            self.dct_matrix_q12,
                            block,
                        )
                    )

        first_stage = run_matrix_batch(
            first_stage_jobs,
            "DCT stage 1 (D x X)",
        )

        intermediate_matrices = [
            round_shift_q12(matrix)
            for matrix
            in first_stage.matrices
        ]

        second_stage_jobs = [
            (
                matrix,
                self.dct_matrix_q12.T,
            )
            for matrix
            in intermediate_matrices
        ]

        second_stage = run_matrix_batch(
            second_stage_jobs,
            "DCT stage 2 "
            "(T x D-transpose)",
        )

        output = np.zeros(
            working.shape,
            dtype=np.float64,
        )

        for location, matrix in zip(
            locations,
            second_stage.matrices,
        ):
            (
                block_row,
                block_column,
                component,
            ) = location

            output[
                block_row:
                block_row + BLOCK_SIZE,
                block_column:
                block_column + BLOCK_SIZE,
                component,
            ] = round_shift_q12(matrix)

        block_count = (
            height // BLOCK_SIZE
        ) * (
            width // BLOCK_SIZE
        )

        self.last_report = DCTRunReport(
            block_count=block_count,
            component_count=component_count,
            matrix_job_count=(
                len(locations) * 2
            ),
            first_stage_cycles=(
                first_stage.total_cycles
            ),
            second_stage_cycles=(
                second_stage.total_cycles
            ),
            total_cycles=(
                first_stage.total_cycles
                + second_stage.total_cycles
            ),
            overflow_count=(
                first_stage.overflow_count
                + second_stage.overflow_count
            ),
            first_stage_elapsed_seconds=(
                first_stage.elapsed_seconds
            ),
            second_stage_elapsed_seconds=(
                second_stage.elapsed_seconds
            ),
        )

        return output