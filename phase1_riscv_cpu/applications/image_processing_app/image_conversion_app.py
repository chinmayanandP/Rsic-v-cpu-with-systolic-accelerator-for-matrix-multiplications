import argparse
import os
import tempfile
import time
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps, ImageTk

import tkinter as tk
from tkinter import filedialog, messagebox
from tkinter.scrolledtext import ScrolledText

from grayscale_backend import rgb_to_grayscale


APP_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = APP_DIR / "image_conversion_results"


def select_image():
    root = tk.Tk()
    root.withdraw()

    try:
        filename = filedialog.askopenfilename(
            parent=root,
            title="Select an image",
            filetypes=[
                (
                    "Image files",
                    "*.jpg *.jpeg *.png *.bmp *.tif *.tiff",
                ),
                ("All files", "*.*"),
            ],
        )
    finally:
        root.destroy()

    return Path(filename) if filename else None


def load_rgb(path):
    with Image.open(path) as source:
        # Respect the orientation recorded by cameras.
        oriented = ImageOps.exif_transpose(source)

        # Composite transparent images onto white.
        if (
            "A" in oriented.getbands()
            or "transparency" in oriented.info
        ):
            rgba = oriented.convert("RGBA")
            background = Image.new(
                "RGBA", rgba.size, (255, 255, 255, 255)
            )
            rgb = Image.alpha_composite(
                background, rgba
            ).convert("RGB")
        else:
            rgb = oriented.convert("RGB")

        return np.array(rgb, dtype=np.uint8)


def show_result(before, after, report, folder, output_path):
    window = tk.Tk()
    window.title("Image conversion result")
    window.geometry("1000x740")

    previews = tk.Frame(window)
    previews.pack(fill="x", padx=12, pady=12)

    for heading, array in (
        ("Input", before),
        ("Output", after),
    ):
        frame = tk.Frame(previews)
        frame.pack(side="left", expand=True)

        tk.Label(
            frame,
            text=heading,
            font=("Segoe UI", 12, "bold"),
        ).pack()

        preview = Image.fromarray(array)
        preview.thumbnail(
            (440, 320),
            Image.Resampling.LANCZOS,
        )

        photo = ImageTk.PhotoImage(
            preview, master=window
        )
        label = tk.Label(frame, image=photo)
        label.image = photo
        label.pack(pady=6)

    text = ScrolledText(
        window,
        font=("Consolas", 10),
        wrap="word",
        height=12,
    )
    text.pack(
        fill="both", expand=True,
        padx=16, pady=8,
    )
    text.insert("1.0", report)
    text.configure(state="disabled")

    buttons = tk.Frame(window)
    buttons.pack(pady=12)

    tk.Button(
        buttons,
        text="Open Output Image",
        command=lambda: os.startfile(str(output_path)),
    ).pack(side="left", padx=6)

    tk.Button(
        buttons,
        text="Open Output Folder",
        command=lambda: os.startfile(str(folder)),
    ).pack(side="left", padx=6)

    tk.Button(
        buttons,
        text="Close Results",
        command=window.destroy,
    ).pack(side="left", padx=6)

    window.mainloop()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--mode",
        required=True,
        choices=("gray", "color"),
    )
    args = parser.parse_args()

    input_path = select_image()

    if input_path is None:
        print("Image selection cancelled.")
        return 0

    started = time.perf_counter()
    original = load_rgb(input_path)
    gray = rgb_to_grayscale(original)

    process_started = time.perf_counter()

    if args.mode == "gray":
        operation = "RGB to grayscale"
        output = gray
        display_input = original
        filename = "grayscale.png"
        note = "Output is an 8-bit, single-channel grayscale PNG."

    else:
        from colorization_backend import colorize_grayscale

        operation = "AI grayscale to colour"
        print(
            "Loading model and estimating colours...",
            flush=True,
        )

        output = colorize_grayscale(gray)
        display_input = gray
        filename = "colorized.png"

        note = (
            "Colours are AI estimates, not recovered original colours. "
            "If a colour image was selected, its colours were removed "
            "before inference."
        )

    processing_seconds = (
        time.perf_counter() - process_started
    )

    if output.shape[:2] != original.shape[:2]:
        raise RuntimeError("Output dimensions do not match the input.")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    folder = Path(
        tempfile.mkdtemp(
            prefix=f"{args.mode}_",
            dir=str(OUTPUT_DIR),
        )
    )

    output_path = folder / filename
    Image.fromarray(output).save(output_path)

    total_seconds = time.perf_counter() - started

    height, width = original.shape[:2]
    channels = 1 if output.ndim == 2 else output.shape[2]

    report = "\n".join([
        "IMAGE CONVERSION RESULT",
        "",
        f"Operation: {operation}",
        f"Input: {input_path}",
        f"Output: {output_path}",
        f"Resolution after orientation: {width}x{height}",
        f"Output resolution: {width}x{height}",
        f"Output channels: {channels}",
        f"Original file size: {input_path.stat().st_size:,} bytes",
        f"Output file size: {output_path.stat().st_size:,} bytes",
        f"Processing time: {processing_seconds:.3f} seconds",
        f"Total load/process/save time: {total_seconds:.3f} seconds",
        "",
        note,
        "PNG conversion does not guarantee a smaller file.",
        "Execution: laptop software; no RTL CPU cycles are measured.",
        "The original file was preserved.",
    ])

    (folder / "result.txt").write_text(
        report + "\n",
        encoding="utf-8",
    )

    print("\n" + report)

    show_result(
        display_input,
        output,
        report,
        folder,
        output_path,
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())

    except Exception as error:
        print(f"ERROR: {error}")

        root = tk.Tk()
        root.withdraw()
        messagebox.showerror(
            "Image conversion error",
            str(error),
            parent=root,
        )
        root.destroy()
        raise SystemExit(1)