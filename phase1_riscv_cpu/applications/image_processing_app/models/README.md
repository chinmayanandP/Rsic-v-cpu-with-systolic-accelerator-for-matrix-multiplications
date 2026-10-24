# AI colourization model

The AI colourization option requires this large pretrained model file:

```text
colorization_release_v2.caffemodel
```

Place it in this directory so the final path is:

```text
phase1_riscv_cpu/applications/image_processing_app/models/colorization_release_v2.caffemodel
```

The repository intentionally excludes `*.caffemodel` files because they are large downloaded dependencies. The model architecture and colour-cluster data retained here are:

- `colorization_deploy_v2.prototxt`
- `pts_in_hull.npy`

Do not rename the model file. Option 3 in `run_image_tools.bat` checks and loads this exact filename.
