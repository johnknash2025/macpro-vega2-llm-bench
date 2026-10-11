#!/bin/sh
# A/B the Vega II DPM levels: for each level, run llama-bench (pp2048 + tg128) while sampling
# the real clock, voltage, power and temperature every 3 s from amdgpu_pm_info.
D=/sys/class/drm/card1/device
M=$(find -L "$HOME/.magnitude/models" -name 'Qwen3.8-27B-UD-Q4_K_XL.gguf' | head -1)
OUT=$HOME/bench/results/gpu-level-ab
mkdir -p "$OUT"
sudo -v || exit 1
for lvl in low auto high; do
  echo "$lvl" | sudo tee $D/power_dpm_force_performance_level >/dev/null
  sleep 3
  ( while :; do
      printf '%s %s %s %s %sC\n' "$(date +%T)" \
        "$(sudo grep -m1 'SCLK' /sys/kernel/debug/dri/1/amdgpu_pm_info | awk '{print $1}')MHz" \
        "$(sudo grep 'VDDGFX' /sys/kernel/debug/dri/1/amdgpu_pm_info | awk '{print $1}')mV" \
        "$(sudo grep 'SoC' /sys/kernel/debug/dri/1/amdgpu_pm_info | awk '{print $1}')W" \
        "$(( $(cat $D/hwmon/hwmon*/temp1_input) / 1000 ))"
      sleep 3
    done ) > "$OUT/$lvl-samples.log" 2>&1 &
  SAMPLER=$!
  "$HOME/engines/llama.cpp/build/bin/llama-bench" -m "$M" -ngl 99 -fa 1 -p 2048 -n 128 -r 3 -o md 2>&1 \
    | grep -E '^\| qwen' > "$OUT/$lvl-bench.md"
  kill $SAMPLER
  echo "== $lvl"
  cut -d'|' -f8,9 "$OUT/$lvl-bench.md"
  echo "   samples (sclk / voltage / power / temp), max:"
  sort -k2 -n "$OUT/$lvl-samples.log" | tail -1
  echo "   median sample:"
  sort -k2 -n "$OUT/$lvl-samples.log" | awk '{a[NR]=$0} END {print a[int((NR+1)/2)]}'
done
echo auto | sudo tee $D/power_dpm_force_performance_level >/dev/null
