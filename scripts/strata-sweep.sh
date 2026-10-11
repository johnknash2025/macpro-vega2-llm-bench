#!/bin/sh
# Strata gfx906 tuning sweep: each line is "name|extra args"
M=/home/johnkahppy/models/flash-next-iq3xxs
OUT=/home/johnkahppy/bench/results/sweep
mkdir -p "$OUT"
while IFS='|' read -r name extra; do
  [ -z "$name" ] && continue
  docker run --rm --device=/dev/kfd --device=/dev/dri --group-add video --ipc=host --ulimit memlock=-1 \
    -e HSA_OVERRIDE_GFX_VERSION=9.0.6 -v /home/johnkahppy/Strata:/src -v $M:/models -v /home/johnkahppy/bench:/bench \
    -w /src mixa3607/rocm-gfx906:7.14-complete ./build-906/strata \
    --pack data/packs/iq3_xxs --tokens-file /bench/prompt-short.ids \
    --native /models/Qwen3.8-Flash-Next-GSQ-RCO-IQ3_XXS-00001-of-00002.gguf \
    --ple-gguf /models/Qwen3.8-Flash-Next-GSQ-RCO-IQ3_XXS-00002-of-00002.gguf \
    --mmap-experts --expert-profile data/expert-profile.bin --expert-cache auto \
    --prefill 512 --spec 4 --spec-min-p 0.5 --mtp data/mtp/rt \
    --max-context 4096 --kv int8 --max-new 512 $extra > "$OUT/$name.log" 2>&1
  printf '%-28s %s | %s\n' "$name" "$(grep -E '^decode ' "$OUT/$name.log" | sed 's/  */ /g')" \
    "$(grep -E '^verify window' "$OUT/$name.log" | sed 's/  */ /g' | cut -c1-120)"
done <<'EOF'
r1024-pcie0|--vram-reserve-mib 1024 --pcie-frac 0 --adapt-every 0 --pool-workers 11
r1024-pcie0.3|--vram-reserve-mib 1024 --pcie-frac 0.3 --adapt-every 0 --pool-workers 11
r1024-pcie0.5|--vram-reserve-mib 1024 --pcie-frac 0.5 --adapt-every 0 --pool-workers 11
r1024-pcie0.7|--vram-reserve-mib 1024 --pcie-frac 0.7 --adapt-every 0 --pool-workers 11
r1024-pcie0.5-adapt|--vram-reserve-mib 1024 --pcie-frac 0.5 --pool-workers 11
r1024-pcie0.5-w23|--vram-reserve-mib 1024 --pcie-frac 0.5 --adapt-every 0 --pool-workers 23
EOF
