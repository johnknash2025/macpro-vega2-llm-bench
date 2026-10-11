#!/bin/sh
# Runs the gfx906 Strata engine inside the community ROCm image, with the home folder mounted at the same
# path so every argument the server passes works unchanged. stdin/stdout stay attached (the --serve protocol).
exec docker run --rm -i --init \
  --device=/dev/kfd --device=/dev/dri --group-add video --ipc=host --ulimit memlock=-1 \
  -e HSA_OVERRIDE_GFX_VERSION=9.0.6 \
  -v /home/johnkahppy:/home/johnkahppy -w "$PWD" \
  mixa3607/rocm-gfx906:7.14-complete /home/johnkahppy/Strata/build-906/strata "$@"
