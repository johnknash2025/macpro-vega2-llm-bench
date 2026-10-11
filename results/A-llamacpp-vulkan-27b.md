ggml_vulkan: Found 1 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon Graphics (RADV VEGA20) (radv) | uma: 0 | fp16: 1 | bf16: 0 | fp4: 0 | warp size: 64 | shared memory: 65536 | int dot: 1 | matrix cores: none
| model                          |       size |     params | backend    | ngl |  fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | --: | --------------: | -------------------: |
| qwen35 27B Q4_K - Medium       |  16.34 GiB |    27.32 B | Vulkan     |  99 |   1 |           pp512 |        128.48 ± 0.04 |
| qwen35 27B Q4_K - Medium       |  16.34 GiB |    27.32 B | Vulkan     |  99 |   1 |          pp2048 |        127.48 ± 0.05 |
| qwen35 27B Q4_K - Medium       |  16.34 GiB |    27.32 B | Vulkan     |  99 |   1 |          pp8192 |        122.22 ± 0.04 |
| qwen35 27B Q4_K - Medium       |  16.34 GiB |    27.32 B | Vulkan     |  99 |   1 |           tg128 |         20.38 ± 0.03 |
| qwen35 27B Q4_K - Medium       |  16.34 GiB |    27.32 B | Vulkan     |  99 |   1 |           tg256 |         20.47 ± 0.01 |

build: 23b0202 (1)
