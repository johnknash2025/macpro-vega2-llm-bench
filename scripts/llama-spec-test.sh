#!/bin/sh
# Compare llama.cpp (Vulkan) speculative decoding modes on Qwen3.8 27B through llama-server.
# Each mode: start the server, send the same chat request 3 times (temperature 0, 512 tokens), print decode tok/s.
BIN=$HOME/engines/llama.cpp/build/bin/llama-server
M=$(readlink -f "$(find -L "$HOME/.magnitude/models" -name 'Qwen3.8-27B-UD-Q4_K_XL.gguf' | head -1)")
DRAFT=$(readlink -f "$(find -L "$HOME/.magnitude/models" -name 'Qwen3.8-27B-DFlash2-Q8_0.gguf' | head -1)")
OUT=$HOME/bench/results/llama-spec
mkdir -p "$OUT"
PROMPT='日本の四季について、それぞれの季節の特徴と代表的な行事を詳しく説明してください。'
run_mode() {
  name=$1; shift
  "$BIN" -m "$M" -ngl 99 -fa on -c 8192 --port 18080 --no-webui "$@" > "$OUT/$name-server.log" 2>&1 &
  pid=$!
  for i in $(seq 1 120); do curl -sf http://127.0.0.1:18080/health >/dev/null && break; sleep 1; done
  if ! curl -sf http://127.0.0.1:18080/health >/dev/null; then
    echo "$name: server did not start"; tail -5 "$OUT/$name-server.log"; kill $pid 2>/dev/null; return
  fi
  for r in 1 2 3; do
    curl -s http://127.0.0.1:18080/v1/chat/completions -H 'Content-Type: application/json' -d "{
      \"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}],
      \"max_tokens\":512,\"temperature\":0,\"chat_template_kwargs\":{\"enable_thinking\":false}}" > "$OUT/$name-$r.json"
    python3 -I -c "
import json,sys
d=json.load(open(sys.argv[1])); t=d.get('timings',{})
print(f\"$name run $r: decode {t.get('predicted_per_second',0):.2f} tok/s ({t.get('predicted_n')} tok), prompt {t.get('prompt_per_second',0):.1f} tok/s, draft accepted {t.get('draft_n_accepted','-')}/{t.get('draft_n','-')}\")
" "$OUT/$name-$r.json"
  done
  kill $pid; wait $pid 2>/dev/null
}
run_mode none
run_mode dflash -md "$DRAFT" -ngld 99 --spec-type draft-dflash
run_mode mtp --spec-type draft-mtp
