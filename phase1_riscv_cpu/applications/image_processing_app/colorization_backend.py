from pathlib import Path

import cv2
import numpy as np


MODEL_DIR = Path(__file__).resolve().parent / "models"


def colorize_grayscale(gray):
    """Estimate RGB colours from an 8-bit grayscale image."""
    gray = np.asarray(gray)

    if gray.ndim != 2 or gray.dtype != np.uint8:
        raise ValueError("Expected a two-dimensional uint8 grayscale image.")

    proto = MODEL_DIR / "colorization_deploy_v2.prototxt"
    weights = MODEL_DIR / "colorization_release_v2.caffemodel"
    points_file = MODEL_DIR / "pts_in_hull.npy"

    for path in (proto, weights, points_file):
        if not path.is_file():
            raise FileNotFoundError(f"Missing model file: {path}")

    points = np.load(points_file, allow_pickle=False)

    if points.shape != (313, 2):
        raise ValueError(f"Unexpected colour-cluster shape: {points.shape}")

    net = cv2.dnn.readNetFromCaffe(
        str(proto),
        str(weights),
    )

    net.setPreferableBackend(cv2.dnn.DNN_BACKEND_OPENCV)
    net.setPreferableTarget(cv2.dnn.DNN_TARGET_CPU)

    cluster_layer = net.getLayerId("class8_ab")
    rebalance_layer = net.getLayerId("conv8_313_rh")

    if cluster_layer <= 0 or rebalance_layer <= 0:
        raise RuntimeError("The model does not contain the expected layers.")

    net.getLayer(cluster_layer).blobs = [
        points.T.reshape(2, 313, 1, 1).astype(np.float32)
    ]

    net.getLayer(rebalance_layer).blobs = [
        np.full((1, 313), 2.606, dtype=np.float32)
    ]

    # Convert grayscale brightness into the Lab colour space.
    rgb_gray = cv2.cvtColor(gray, cv2.COLOR_GRAY2RGB)
    rgb_float = rgb_gray.astype(np.float32) / 255.0
    lab = cv2.cvtColor(rgb_float, cv2.COLOR_RGB2Lab)
    original_l = lab[:, :, 0]

    model_l = cv2.resize(
        original_l,
        (224, 224),
        interpolation=cv2.INTER_AREA,
    )
    model_l = model_l - 50.0

    net.setInput(cv2.dnn.blobFromImage(model_l))
    prediction = net.forward()

    if (
        prediction.ndim != 4
        or prediction.shape[0] != 1
        or prediction.shape[1] != 2
    ):
        raise RuntimeError(
            f"Unexpected model output shape: {prediction.shape}"
        )

    if not np.all(np.isfinite(prediction)):
        raise RuntimeError("The model returned invalid numerical values.")

    predicted_ab = prediction[0].transpose(1, 2, 0)

    height, width = gray.shape
    predicted_ab = cv2.resize(
        predicted_ab,
        (width, height),
        interpolation=cv2.INTER_LINEAR,
    )

    output_lab = np.concatenate(
        (original_l[:, :, None], predicted_ab),
        axis=2,
    ).astype(np.float32)

    output_rgb = cv2.cvtColor(
        output_lab,
        cv2.COLOR_Lab2RGB,
    )

    return np.clip(
        np.rint(output_rgb * 255.0),
        0,
        255,
    ).astype(np.uint8)