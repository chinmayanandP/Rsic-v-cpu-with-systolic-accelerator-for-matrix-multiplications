from pathlib import Path
import shutil
import tempfile
import time
import os
import tkinter as tk
from tkinter import filedialog, messagebox
from tkinter.scrolledtext import ScrolledText

import imageio.v3 as iio
import numpy as np
from PIL import Image, ImageTk

import encoder as encoder_module
from utils.dct import FDCT
from riscv_jpeg_encoder import (
    PaddedRiscVJPEGEncoder,
    normalize_color_image,
)
from riscv_batch_dct_backend import RiscVBatchDCTBackend


APP_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = APP_DIR / "riscv_jpeg_results"

QUALITIES = (95, 90, 85, 80, 75, 70, 65, 60, 55, 50)
MIN_PSNR = 40.0


def psnr(reference, decoded):
    if reference.shape != decoded.shape:
        raise ValueError("Output resolution changed.")

    difference = (
        reference.astype(float)
        - decoded.astype(float)
    )
    mse = np.mean(difference ** 2)

    if mse == 0:
        return float("inf")

    return float(10 * np.log10(255 ** 2 / mse))


def show_result(original, decoded, report, folder):
    window = tk.Tk()
    window.title("JPEG size reduction result")
    window.geometry("1000x750")

    pictures = tk.Frame(window)
    pictures.pack(fill="x")

    for title, array in (
        ("Original", original),
        ("Selected output", decoded),
    ):
        frame = tk.Frame(pictures)
        frame.pack(side="left", expand=True)

        tk.Label(frame, text=title).pack()

        picture = Image.fromarray(array)
        picture.thumbnail(
            (450, 300),
            Image.Resampling.LANCZOS,
        )

        photo = ImageTk.PhotoImage(
            picture,
            master=window,
        )

        label = tk.Label(frame, image=photo)
        label.image = photo
        label.pack()

    box = ScrolledText(
        window,
        wrap="word",
        font=("Consolas", 10),
    )
    box.pack(
        fill="both",
        expand=True,
        padx=12,
        pady=12,
    )

    box.insert("1.0", report)
    box.configure(state="disabled")

    tk.Button(
        window,
        text="Open Output Folder",
        command=lambda: os.startfile(str(folder)),
    ).pack(pady=5)

    tk.Button(
        window,
        text="Exit",
        command=window.destroy,
    ).pack(pady=5)

    window.mainloop()


def compress(input_path, folder):
    original = normalize_color_image(
        iio.imread(input_path)
    )

    input_size = input_path.stat().st_size

    if input_size == 0:
        raise ValueError("The selected file is empty.")

    cache = {}

    def cached_dct(
        image,
        block_size=8,
        color_space="YUV",
    ):
        # DCT does not depend on JPEG quality.
        # Calculate it once and reuse it for all candidates.
        if not cache:
            result = FDCT(
                image,
                block_size=block_size,
                color_space=color_space,
                backend="fixed_python",
            )

            cache["full"] = result

            cache["input"] = np.array(
                image[:32, :32, :],
                copy=True,
            )

            cache["reference"] = np.array(
                result[:32, :32, :],
                copy=True,
            )

            cache["color_space"] = color_space

        return cache["full"].copy()

    rows = []
    best = None

    started = time.perf_counter()
    saved_fdct = encoder_module.FDCT

    print("\nSearching for a smaller JPEG...")
    print(
        f"Original resolution: "
        f"{original.shape[1]}x{original.shape[0]}"
    )
    print(f"Original size: {input_size:,} bytes")
    print(f"Quality screening target: {MIN_PSNR} dB PSNR")
    print("The output resolution will be preserved.\n")

    try:
        encoder_module.FDCT = cached_dct

        # Temporary candidate files are removed automatically.
        with tempfile.TemporaryDirectory(
            dir=folder
        ) as trial_dir:

            for quality in QUALITIES:
                trial = (
                    Path(trial_dir)
                    / f"trial_Q{quality}.jpg"
                )

                enc = PaddedRiscVJPEGEncoder(input_path)

                enc.encode(
                    quality=quality,
                    save_path=trial,
                    to_gray=False,
                    huffman_type="standard",
                )

                decoded = normalize_color_image(
                    iio.imread(trial)
                )

                score = psnr(original, decoded)
                size = trial.stat().st_size

                eligible = (
                    size < input_size
                    and score >= MIN_PSNR
                )

                line = (
                    f"Q={quality}: {size:,} bytes, "
                    f"PSNR={score:.3f} dB, "
                    f"eligible={eligible}"
                )

                print(line, flush=True)
                rows.append(line)

                # Prefer the highest measured fidelity.
                # For equal PSNR, prefer the smaller file.
                if eligible and (
                    best is None
                    or (score, -size) > best[0]
                ):
                    selected = folder / "compressed.jpg"

                    shutil.copyfile(
                        trial,
                        selected,
                    )

                    best = (
                        (score, -size),
                        quality,
                        selected,
                        decoded,
                    )

    finally:
        encoder_module.FDCT = saved_fdct

    host_seconds = time.perf_counter() - started

    if best is None:
        selected = folder / (
            "original_retained" + input_path.suffix
        )

        shutil.copy2(input_path, selected)

        decoded = original
        quality_label = (
            "Original retained; no re-encoding selected"
        )
        size_status = (
            "NO SMALLER FILE MET THE QUALITY TARGET"
        )
        score = float("inf")

    else:
        _, quality, selected, decoded = best
        quality_label = str(quality)
        size_status = "SIZE REDUCTION ACHIEVED"
        score = psnr(original, decoded)

    output_size = selected.stat().st_size

    reduction = (
        100 * (input_size - output_size)
        / input_size
    )

    report = [
        "PHASE-1 HYBRID JPEG RESULT",
        "",
        f"Size status: {size_status}",
        f"Input: {input_path}",
        f"Selected output: {selected}",
        (
            "Resolution: "
            f"{original.shape[1]}x{original.shape[0]} "
            "(preserved)"
        ),
        f"Input size: {input_size:,} bytes",
        f"Output size: {output_size:,} bytes",
        f"Reduction: {reduction:.3f}%",
        f"Selected quality: {quality_label}",
        f"Decoded PSNR versus input: {score:.3f} dB",
        (
            "Quality screening target: "
            f"PSNR >= {MIN_PSNR} dB"
        ),
        (
            "PSNR is a numerical check; "
            "inspect fine details visually too."
        ),
        (
            "Host search/encoding time: "
            f"{host_seconds:.3f} seconds"
        ),
        "",
        "CANDIDATE RESULTS",
        *rows,
        "",
        "Full-image JPEG encoding used the Q12 Python model.",
        (
            "RTL validation below covers only "
            "a top-left crop, up to 32x32."
        ),
    ]

    # Save the software result before starting Vivado.
    (folder / "result.txt").write_text(
        "\n".join(report),
        encoding="utf-8",
    )

    print(f"\n{size_status}")
    print(f"Selected output: {selected}")
    print(f"Reduction: {reduction:.3f}%")

    return original, decoded, report, cache


def main():
    root = tk.Tk()
    root.withdraw()

    filename = filedialog.askopenfilename(
        parent=root,
        title="Select your image",
        filetypes=[
            (
                "Images",
                "*.jpg *.jpeg *.png *.bmp *.tif *.tiff",
            )
        ],
    )

    root.destroy()

    if not filename:
        return

    OUTPUT_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    folder = Path(
        tempfile.mkdtemp(
            prefix="jpeg_run_",
            dir=OUTPUT_DIR,
        )
    )

    original, decoded, report, cache = compress(
        Path(filename),
        folder,
    )

    print(
        "\nStarting RTL crop validation once...",
        flush=True,
    )

    try:
        backend = RiscVBatchDCTBackend()

        actual = backend.fdct(
            cache["input"],
            color_space=cache["color_space"],
        )

        dct = backend.last_report

        if (
            dct is None
            or actual.shape != cache["reference"].shape
        ):
            raise RuntimeError(
                "Invalid RTL result/report."
            )

        error = float(
            np.max(
                np.abs(actual - cache["reference"])
            )
        )

        passed = (
            error == 0
            and dct.overflow_count == 0
        )

        report.extend([
            "",
            (
                "RTL validation: "
                f"{'PASSED' if passed else 'FAILED'}"
            ),
            f"Maximum coefficient error: {error:g}",
            f"Overflow count: {dct.overflow_count}",
            f"Matrix jobs: {dct.matrix_job_count}",
            f"Sample CPU cycles: {dct.total_cycles:,}",
            (
                "Sample CPU time at assumed 100 MHz: "
                f"{dct.total_cycles / 100000:.6f} ms"
            ),
            (
                "XSim wall time: "
                f"{dct.total_elapsed_seconds:.3f} seconds"
            ),
            (
                "Sample CPU timing is not "
                "full-image CPU timing."
            ),
        ])

    except Exception as error:
        report.extend([
            "",
            f"RTL validation FAILED: {error}",
            (
                "The software-selected output "
                "remains available."
            ),
        ])

    text = "\n".join(report)

    (folder / "result.txt").write_text(
        text + "\n",
        encoding="utf-8",
    )

    print(text)

    show_result(
        original,
        decoded,
        text,
        folder,
    )


if __name__ == "__main__":
    try:
        main()

    except Exception as error:
        print(f"ERROR: {error}")

        root = tk.Tk()
        root.withdraw()

        messagebox.showerror(
            "JPEG application error",
            str(error),
            parent=root,
        )

        root.destroy()