ggml_cuda_init: found 1 ROCm devices (Total VRAM: 32752 MiB):
  Device 0: AMD Radeon Graphics, gfx906:sramecc-:xnack- (0x906), VMM: no, Wave Size: 64, VRAM: 32752 MiB
| model                          |       size |     params | backend    | ngl |  fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | --: | --------------: | -------------------: |
| qwen35 27B Q4_K - Medium       |  16.34 GiB |    27.32 B | ROCm       |  99 |   1 |           pp512 |        154.94 ± 0.29 |
| qwen35 27B Q4_K - Medium       |  16.34 GiB |    27.32 B | ROCm       |  99 |   1 |          pp2048 |        154.20 ± 0.03 |
| qwen35 27B Q4_K - Medium       |  16.34 GiB |    27.32 B | ROCm       |  99 |   1 |          pp8192 |        149.78 ± 0.25 |
| qwen35 27B Q4_K - Medium       |  16.34 GiB |    27.32 B | ROCm       |  99 |   1 |           tg128 |         18.64 ± 0.36 |
| qwen35 27B Q4_K - Medium       |  16.34 GiB |    27.32 B | ROCm       |  99 |   1 |           tg256 |         18.94 ± 0.03 |

build: unknown (0)
