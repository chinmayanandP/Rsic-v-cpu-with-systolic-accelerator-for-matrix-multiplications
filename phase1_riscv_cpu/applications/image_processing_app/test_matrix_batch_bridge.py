from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path


MATRIX_SIZE = 8
MATRIX_ELEMENTS = 64

APPLICATION_DIR = Path(__file__).resolve().parent
PROJECT_DIR = APPLICATION_DIR.parent

INPUT_FILE = PROJECT_DIR / "dct_batch_input.mem"
OUTPUT_FILE = PROJECT_DIR / "dct_batch_output.txt"

RESULT_FILE = (
    APPLICATION_DIR /
    "matrix_batch_bridge_result.txt"
)

TCL_FILE = (
    PROJECT_DIR /
    "run_matrix_batch_sim.tcl"
)

VIVADO_BAT = Path(
    r"D:\vivado\2026.1\Vivado\bin\vivado.bat"
)


@dataclass(frozen=True)
class MatrixJob:
    job_id: int
    matrix_a: list[list[int]]
    matrix_b: list[list[int]]


def identity_matrix() -> list[list[int]]:
    return [
        [
            1 if row == column else 0
            for column in range(MATRIX_SIZE)
        ]
        for row in range(MATRIX_SIZE)
    ]


def matrix_multiply(
    matrix_a: list[list[int]],
    matrix_b: list[list[int]],
) -> list[list[int]]:
    result = []

    for row in range(MATRIX_SIZE):
        result_row = []

        for column in range(MATRIX_SIZE):
            accumulator = 0

            for inner in range(MATRIX_SIZE):
                accumulator += (
                    matrix_a[row][inner]
                    * matrix_b[inner][column]
                )

            result_row.append(accumulator)

        result.append(result_row)

    return result


def signed_word_to_hex(value: int) -> str:
    return f"{value & 0xFFFFFFFF:08x}"


def build_jobs() -> list[MatrixJob]:
    identity = identity_matrix()

    increasing = [
        [
            row * MATRIX_SIZE + column - 32
            for column in range(MATRIX_SIZE)
        ]
        for row in range(MATRIX_SIZE)
    ]

    patterned = [
        [
            ((row * 5 + column * 3) % 17) - 8
            for column in range(MATRIX_SIZE)
        ]
        for row in range(MATRIX_SIZE)
    ]

    signed_transform = [
        [
            (
                (row + 1)
                * (column + 2)
                * (
                    -1
                    if (row + column) % 2
                    else 1
                )
            )
            for column in range(MATRIX_SIZE)
        ]
        for row in range(MATRIX_SIZE)
    ]

    return [
        MatrixJob(
            job_id=100,
            matrix_a=identity,
            matrix_b=increasing,
        ),
        MatrixJob(
            job_id=101,
            matrix_a=patterned,
            matrix_b=identity,
        ),
        MatrixJob(
            job_id=102,
            matrix_a=signed_transform,
            matrix_b=patterned,
        ),
    ]


def validate_matrix(
    job_id: int,
    matrix_name: str,
    matrix: list[list[int]],
) -> None:
    if len(matrix) != MATRIX_SIZE:
        raise ValueError(
            f"Job {job_id} Matrix {matrix_name} "
            "must have exactly 8 rows."
        )

    for row_number, row in enumerate(
        matrix,
        start=1,
    ):
        if len(row) != MATRIX_SIZE:
            raise ValueError(
                f"Job {job_id} Matrix {matrix_name} "
                f"row {row_number} must have exactly "
                "8 columns."
            )

        for value in row:
            if value < -32768 or value > 32767:
                raise ValueError(
                    f"Job {job_id} Matrix "
                    f"{matrix_name} contains "
                    f"out-of-range value {value}."
                )


def write_batch_input(
    jobs: list[MatrixJob],
) -> None:
    lines = [str(len(jobs))]

    for job in jobs:
        validate_matrix(
            job.job_id,
            "A",
            job.matrix_a,
        )

        validate_matrix(
            job.job_id,
            "B",
            job.matrix_b,
        )

        lines.append(str(job.job_id))

        for matrix in (
            job.matrix_a,
            job.matrix_b,
        ):
            for row in matrix:
                for value in row:
                    lines.append(
                        signed_word_to_hex(value)
                    )

    INPUT_FILE.write_text(
        "\n".join(lines) + "\n",
        encoding="ascii",
    )


def run_vivado() -> None:
    if not VIVADO_BAT.is_file():
        raise FileNotFoundError(
            f"Vivado was not found at:\n"
            f"{VIVADO_BAT}"
        )

    if not TCL_FILE.is_file():
        raise FileNotFoundError(
            f"Missing Tcl script:\n"
            f"{TCL_FILE}"
        )

    if OUTPUT_FILE.exists():
        OUTPUT_FILE.unlink()

    print()
    print(
        "Starting one Vivado XSim run "
        "for all matrix jobs..."
    )

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

    if completed.returncode != 0:
        raise RuntimeError(
            "Vivado exited with code "
            f"{completed.returncode}."
        )

    if not OUTPUT_FILE.is_file():
        raise FileNotFoundError(
            "XSim did not create "
            "dct_batch_output.txt."
        )


def parse_batch_output():
    lines = OUTPUT_FILE.read_text(
        encoding="utf-8"
    ).splitlines()

    results = {}
    total_cycles = -1
    final_status = ""

    index = 0

    while index < len(lines):
        line = lines[index].strip()

        if line.startswith("JOB "):
            job_id = int(
                line.split()[1]
            )

            cycles_parts = (
                lines[index + 1].split()
            )

            overflow_parts = (
                lines[index + 2].split()
            )

            if (
                lines[index + 3].strip()
                != "MATRIX_C"
            ):
                raise ValueError(
                    "Missing MATRIX_C marker "
                    f"for job {job_id}."
                )

            matrix_c = []

            for row_offset in range(
                MATRIX_SIZE
            ):
                row_text = lines[
                    index + 4 + row_offset
                ]

                row_values = [
                    int(value, 10)
                    for value in row_text.split()
                ]

                if (
                    len(row_values)
                    != MATRIX_SIZE
                ):
                    raise ValueError(
                        f"Job {job_id} returned "
                        "an invalid Matrix C row."
                    )

                matrix_c.append(row_values)

            job_status = (
                lines[index + 12].strip()
            )

            results[job_id] = {
                "cycles": int(
                    cycles_parts[1]
                ),
                "overflow": int(
                    overflow_parts[1]
                ),
                "matrix_c": matrix_c,
                "status": job_status,
            }

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

    return (
        results,
        total_cycles,
        final_status,
    )


def verify_results(
    jobs: list[MatrixJob],
) -> tuple[str, bool]:
    (
        results,
        total_cycles,
        final_status,
    ) = parse_batch_output()

    report_lines = [
        "RISC-V CPU MATRIX BATCH BRIDGE TEST",
        f"Jobs requested: {len(jobs)}",
        f"Jobs returned: {len(results)}",
    ]

    errors = 0

    for job in jobs:
        result = results.get(job.job_id)

        if result is None:
            report_lines.append(
                f"FAIL: Missing job "
                f"{job.job_id}"
            )

            errors += 1
            continue

        expected = matrix_multiply(
            job.matrix_a,
            job.matrix_b,
        )

        actual = result["matrix_c"]
        cycles = int(result["cycles"])
        overflow = int(result["overflow"])
        status = str(result["status"])

        job_passed = (
            actual == expected
            and cycles > 0
            and overflow == 0
            and status == "JOB_STATUS PASS"
        )

        if job_passed:
            report_lines.append(
                f"PASS: Job {job.job_id}, "
                f"cycles={cycles}, "
                f"overflow={overflow}"
            )
        else:
            report_lines.append(
                f"FAIL: Job {job.job_id}, "
                f"cycles={cycles}, "
                f"overflow={overflow}, "
                f"status={status}"
            )

            errors += 1

    if len(results) != len(jobs):
        report_lines.append(
            "FAIL: Returned job count "
            "does not match requested count."
        )

        errors += 1

    if total_cycles <= 0:
        report_lines.append(
            "FAIL: Invalid total cycle count."
        )

        errors += 1
    else:
        report_lines.append(
            f"Total CPU cycles: "
            f"{total_cycles}"
        )

    if final_status != "PASS":
        report_lines.append(
            "FAIL: XSim batch status is "
            f"{final_status!r}."
        )

        errors += 1

    passed = errors == 0

    if passed:
        report_lines.append(
            "STATUS: ALL MATRIX BATCH "
            "BRIDGE CHECKS PASSED"
        )
    else:
        report_lines.append(
            "STATUS: MATRIX BATCH BRIDGE "
            f"FAILED WITH {errors} ERROR(S)"
        )

    report = (
        "\n".join(report_lines) + "\n"
    )

    RESULT_FILE.write_text(
        report,
        encoding="utf-8",
    )

    return report, passed


def main() -> int:
    print(
        "RISC-V CPU MATRIX "
        "BATCH BRIDGE TEST"
    )

    jobs = build_jobs()

    write_batch_input(jobs)

    print(
        f"Created {INPUT_FILE.name} "
        f"with {len(jobs)} jobs."
    )

    run_vivado()

    report, passed = verify_results(jobs)

    print()
    print(report, end="")

    print(
        f"Detailed result:\n"
        f"{RESULT_FILE}"
    )

    return 0 if passed else 1


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