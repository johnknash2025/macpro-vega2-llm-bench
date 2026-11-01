# Mac Pro 2019 Radeon Pro Vega II での Strata と llama.cpp（gfx906、1枚のみ）

[English](README.md) | 日本語

1枚の **Radeon Pro Vega II 32 GB (gfx906, HBM2)** を搭載した Linux (t2linux) 環境の Mac Pro 2019 における、
ローカル LLM エンジンのベンチマークです。主な結果: **Strata の gfx906 ビルドは Qwen3.8-Flash-Next
(GSQ-RCO IQ3_XXS) を 1枚のカードで約 43 tok/s のデコード速度で動作させる**。そこに到達するには 1つの
自明ではない修正が必要で、それは [クロックに関するセクション](#linux-では-vega-ii-が約-1000-mhz-で固定される)
に説明しています。Linux では DPM を解放するまで GPU のクロックが約 1000 MHz に固定されたままになります。

すべての数値は 2026-10-11 に測定されたもので、[`scripts/`](scripts/) のスクリプトで再現可能です。

## ハードウェアとソフトウェア

| | |
|---|---|
| マシン | Mac Pro 2019 (MacPro7,1) |
| CPU | Xeon W-3235、12C/24T (Cascade Lake: AVX-512 F/BW/DQ/VL/VNNI、**VBMI なし**) |
| RAM | 92 GB DDR4-2933、6チャンネル |
| GPU | Radeon Pro Vega II 32 GB HBM2 (約 1 TB/s)、gfx906、PCIe 3.0 x16、1080p モニター2台も駆動 |
| OS | Ubuntu 26.04.1、kernel 7.0.14 (Ubuntu 7.0.0-38 source、t2linux) |
| ROCm | コミュニティの gfx906 ビルド、`mixa3607/rocm-gfx906:7.14-complete`（10.1 でも同じ結果） |
| Strata | `61b3fb5` (2026-10-10)、ggml `3cf0325`、`-DSTRATA_HIP_GFX906=ON -DCMAKE_HIP_ARCHITECTURES=gfx906` でビルド |
| llama.cpp | `23b0202` (2026-10-10)、Vulkan (Mesa RADV 26.0.8) と ROCm ビルド；`mx-llama.cpp` `eefc4e7` |

## 結果

### Qwen3.8-Flash-Next、GSQ-RCO IQ3_XXS（75.8 GB）、Strata gfx906、1枚

`--mmap-experts --expert-cache auto --prefill 512 --spec 4 --spec-min-p 0.5 --kv int8 --pool-workers 11
--adapt-every 0 --vram-reserve-mib 1024`、生成 512 トークン、短い日本語プロンプト。エキスパートキャッシュは
24,576個のうち16,014個（VRAM 26.1 GiB）を保持します。

| 構成 | デコード tok/s | GPU 待ち / ラウンド | CPU プール / ラウンド | MTP / ラウンド |
|---|---:|---:|---:|---:|
| `AMD_HIP.md` の例の引数（`--vram-reserve-mib 3072 --pcie-frac 0`） | 23.4 | 41 ms | 50 ms | 7 ms |
| リザーブ 1 GiB、チューニング済み | 32.0 | 37 ms | 21 ms | 7 ms |
| **+ GPU クロック解放** | **43.4** | **23 ms** | 21 ms | 4 ms |

- MTP の受理率は約65%、1ラウンドあたり約2.2トークン。`--spec 5/6` やより低い `--spec-min-p` は高速化しませんでした。
- `--pcie-frac` 0.2–0.7、CPU の `performance` ガバナー、ROCm 10.1 と 7.14 の違いはいずれも測定可能な差になりませんでした。
- ハイパーサーシング付きのプールワーカ23個は、11個より約2倍遅かった。
- CPU プールは現在1ラウンドの約半分を占めます。この CPU には AVX-512 がありますが VBMI がないため、AVX-512 の
  エキスパートカーネルは使われず AVX2 経路が動きます（`this CPU has no AVX-512: the expert kernels run on AVX-2`）。

### Qwen3.8 27B（dense、unsloth UD-Q4_K_XL、16.3 GiB、VRAM に完全に収まる）

| エンジン | GPU クロック | デコード tg128 | プリフィル pp2048 | プリフィル pp8192 |
|---|---|---:|---:|---:|
| llama.cpp Vulkan | 固定（約1000 MHz） | 20.4 | 127.5 | 122.2 |
| llama.cpp ROCm | 固定 | 17.6 | 171.6 | 167.2 |
| mx-llama.cpp ROCm | 固定 | 18.9 | 154.2 | 149.8 |
| **llama.cpp Vulkan** | **解放（約1700 MHz）** | **27.4** | **207–210** | — |

llama.cpp における推測的デコード（llama-server、512トークン、クロック解放）: none 28.95、MTP 29.97 (+3%)、
DFlash2 ドラフト 22.88 (−21%)。

[Magnitude](https://github.com/magnitudedev/magnitude) 0.2.6 はこのカードでは起動しません: RADV の GFX9 には
Magnitude が要求する `VK_KHR_shader_fma` がないためです。

## Linux では Vega II が約 1000 MHz で固定される

負荷をかけても `amdgpu_pm_info` は `SCLK` 約 1000 MHz、`VDDGFX` 743 mV、約 25–33 W を示しました。
`power_dpm_force_performance_level` を `auto`、`high`、または `manual`（`pp_dpm_sclk` 8 = 1730 MHz）に
設定しても変わりませんでした。SMC の feature mask は `0x0ad8e283` で、メモリクロック、SOCCLK、link DPM は
オフでした（`memclk dpm not enabled!`）。VBIOS は `113-D163A1XT-047`、SMC ファームウェアは 40.60.0。
起動時に `smu_v11_0_i2c_xfer` からの I2C NAK も見えます。

修正は2つの部分からなります:

1. カーネルパラメータ **`amdgpu.ppfeaturemask=0xffffffff`**。再起動後、`auto` と `high` は負荷時に約
   1700 MHz、1.0 V、170–250 W に到達し、温度は約 61 °C です。メモリクロックの DPM はまだオフですが、
   HBM2 はすでに最大の 1000 MHz で動作しています。
2. 以前の t2linux セットアップの名残の udev ルール、`/etc/udev/rules.d/30-amdgpu-pm.rules` が `low` を
   強制していました。`low` は依然として約 1000 MHz に固定するため `auto` に変更しました。

測定された効果（`results/gpu-level-ab/`、llama.cpp Vulkan の 27B）: pp2048 127.9 → 209.6 tok/s (+64%)、tg128
20.2 → 27.4 tok/s (+35%)。Strata: 32.0 → 43.4 tok/s。

これは Linux 環境の他の Vega 20 カード（MI50/MI60、Radeon VII）にも当てはまる可能性がありますが、この
Mac Pro モジュールでのみ確認されています。

## 再現方法

- `config/strata-docker.sh` はホームフォルダを同じパスにマウントした ROCm イメージ内でエンジンを動かします。
  `config/strata-gfx906.json` はこれをサーバーの `exe` として使うため、`serve.server` は変更なしで動きます。
- `scripts/strata-run.sh` は Strata のベンチマークループです。`scripts/gpu-level-ab.sh` はクロックと電源の
   サンプリングを行う DPM の A/B 比較です。`scripts/llama-spec-test.sh` は llama.cpp の推測的デコードモードを
   比較します。
- 生ログは `results/` にあります。

## ライセンス

MIT。スクリプト、設定、測定結果は自由に再利用できます。
