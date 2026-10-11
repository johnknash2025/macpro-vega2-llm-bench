# Strata and llama.cpp on a Mac Pro 2019 Radeon Pro Vega II (gfx906, single card)

Benchmarks of local LLM engines on one **Radeon Pro Vega II 32 GB (gfx906, HBM2)** in a Mac Pro 2019 running
Linux (t2linux). The main result: **Strata's gfx906 build runs Qwen3.8-Flash-Next (GSQ-RCO IQ3_XXS) at about
43 tok/s decode on a single card**. Getting there needed one non-obvious fix, described in
[the clock section](#the-vega-ii-is-stuck-at-1000-mhz-on-linux): the GPU's clock is stuck at about 1000 MHz under
Linux until DPM is unlocked.

All numbers were measured on 2026-10-11 and are reproducible with the scripts in [`scripts/`](scripts/).

## Hardware and software

| | |
|---|---|
| Machine | Mac Pro 2019 (MacPro7,1) |
| CPU | Xeon W-3235, 12C/24T (Cascade Lake: AVX-512 F/BW/DQ/VL/VNNI, **no VBMI**) |
| RAM | 92 GB DDR4-2933, 6 channels |
| GPU | Radeon Pro Vega II 32 GB HBM2 (~1 TB/s), gfx906, PCIe 3.0 x16, also drives two 1080p monitors |
| OS | Ubuntu 26.04.1, kernel 7.0.14 (Ubuntu 7.0.0-38 source, t2linux) |
| ROCm | community gfx906 build, `mixa3607/rocm-gfx906:7.14-complete` (10.1 gave the same results) |
| Strata | `61b3fb5` (2026-10-10), ggml `3cf0325`, built with `-DSTRATA_HIP_GFX906=ON -DCMAKE_HIP_ARCHITECTURES=gfx906` |
| llama.cpp | `23b0202` (2026-10-10), Vulkan (Mesa RADV 26.0.8) and ROCm builds; `mx-llama.cpp` `eefc4e7` |

## Results

### Qwen3.8-Flash-Next, GSQ-RCO IQ3_XXS (75.8 GB), Strata gfx906, one card

`--mmap-experts --expert-cache auto --prefill 512 --spec 4 --spec-min-p 0.5 --kv int8 --pool-workers 11
--adapt-every 0 --vram-reserve-mib 1024`, 512 generated tokens, short Japanese prompt. The expert cache holds
16,014 of 24,576 experts (26.1 GiB of VRAM).

| Step | Decode tok/s | GPU wait / round | CPU pool / round | MTP / round |
|---|---:|---:|---:|---:|
| `AMD_HIP.md` example args (`--vram-reserve-mib 3072 --pcie-frac 0`) | 23.4 | 41 ms | 50 ms | 7 ms |
| reserve 1 GiB, tuned | 32.0 | 37 ms | 21 ms | 7 ms |
| **+ GPU clock unlocked** | **43.4** | **23 ms** | 21 ms | 4 ms |

- MTP acceptance about 65%, about 2.2 tokens per round. `--spec 5/6` and a lower `--spec-min-p` were not faster.
- `--pcie-frac` 0.2–0.7, the CPU `performance` governor and ROCm 10.1 vs 7.14 made no measurable difference.
- 23 hyper-threaded pool workers were about 2x slower than 11.
- The CPU pool is now about half of each round. This CPU has AVX-512 but no VBMI, so the AVX-512 expert kernel
  is not used and the AVX2 path runs (`this CPU has no AVX-512: the expert kernels run on AVX-2`).

### Qwen3.8 27B (dense, unsloth UD-Q4_K_XL, 16.3 GiB, fully in VRAM)

| Engine | GPU clock | Decode tg128 | Prefill pp2048 | Prefill pp8192 |
|---|---|---:|---:|---:|
| llama.cpp Vulkan | locked (~1000 MHz) | 20.4 | 127.5 | 122.2 |
| llama.cpp ROCm | locked | 17.6 | 171.6 | 167.2 |
| mx-llama.cpp ROCm | locked | 18.9 | 154.2 | 149.8 |
| **llama.cpp Vulkan** | **unlocked (~1700 MHz)** | **27.4** | **207–210** | — |

Speculative decoding in llama.cpp (llama-server, 512 tokens, unlocked clock): none 28.95, MTP 29.97 (+3%),
DFlash2 draft 22.88 (−21%).

[Magnitude](https://github.com/magnitudedev/magnitude) 0.2.6 does not start on this card: RADV on GFX9 has no
`VK_KHR_shader_fma`, which Magnitude requires.

## The Vega II is stuck at ~1000 MHz on Linux

Under load, `amdgpu_pm_info` showed `SCLK` about 1000 MHz, `VDDGFX` 743 mV and about 25–33 W, whatever
`power_dpm_force_performance_level` was set to (`auto`, `high`, or `manual` with `pp_dpm_sclk` 8 = 1730 MHz).
The SMC feature mask was `0x0ad8e283`, so memory clock, SOCCLK and link DPM were off (`memclk dpm not enabled!`).
VBIOS `113-D163A1XT-047`, SMC firmware 40.60.0. An I2C NAK from `smu_v11_0_i2c_xfer` also shows at boot.

Fix, two parts:

1. Kernel parameter **`amdgpu.ppfeaturemask=0xffffffff`**. After a reboot, `auto` and `high` reach about
   1700 MHz, 1.0 V and 170–250 W under load, at about 61 °C. Memory clock DPM is still off, but HBM2 already runs
   at its maximum 1000 MHz.
2. A udev rule from an earlier t2linux setup, `/etc/udev/rules.d/30-amdgpu-pm.rules`, forced `low`. `low` still
   pins about 1000 MHz, so it was changed to `auto`.

Measured effect (`results/gpu-level-ab/`, 27B on llama.cpp Vulkan): pp2048 127.9 → 209.6 tok/s (+64%), tg128
20.2 → 27.4 tok/s (+35%). Strata: 32.0 → 43.4 tok/s.

This may apply to other Vega 20 cards (MI50/MI60, Radeon VII) under Linux; it has only been checked on this Mac Pro
module.

## Reproducing

- `config/strata-docker.sh` runs the engine inside the ROCm image with the home folder mounted at the same path.
  `config/strata-gfx906.json` uses it as the server's `exe`, so `serve.server` works unchanged.
- `scripts/strata-run.sh` is the Strata benchmark loop. `scripts/gpu-level-ab.sh` is the DPM A/B with clock and
  power sampling. `scripts/llama-spec-test.sh` compares llama.cpp's speculative modes.
- Raw logs are in `results/`.
