ggml_cuda_init: found 1 ROCm devices (Total VRAM: 32752 MiB):
  Device 0: AMD Radeon Graphics, gfx906:sramecc-:xnack- (0x906), VMM: no, Wave Size: 64, VRAM: 32752 MiB
| model                          |       size |     params | backend    | ngl |  fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | --: | --------------: | -------------------: |
| qwen35 27B Q4_K - Medium       |  16.34 GiB |    27.32 B | ROCm       |  99 |   1 |           pp512 |        168.76 ± 3.15 |
| qwen35 27B Q4_K - Medium       |  16.34 GiB |    27.32 B | ROCm       |  99 |   1 |          pp2048 |        171.57 ± 0.53 |
| qwen35 27B Q4_K - Medium       |  16.34 GiB |    27.32 B | ROCm       |  99 |   1 |          pp8192 |        167.22 ± 0.02 |
| qwen35 27B Q4_K - Medium       |  16.34 GiB |    27.32 B | ROCm       |  99 |   1 |           tg128 |         17.59 ± 0.02 |
| qwen35 27B Q4_K - Medium       |  16.34 GiB |    27.32 B | ROCm       |  99 |   1 |           tg256 |         17.67 ± 0.00 |

build: unknown (0)
