#!/usr/bin/env bash
# Avatar local-LLM shell helpers (M1 Pro / WhisperKit / LM Studio)
#
# Usage:  source path/to/avatar-helpers.sh
#         avatar_help    # list available functions
#
# Goal:   features/deep-research/goals/m1-pro-local-llm-for-avatar.md
# Phase 3 (PR #428): asr_serve_start, asr_serve_stop, asr_record, warmup_llm
# Phase 4 (WIP):     voice_to_llm (VAD-based), asr_latency (--prompt)
#
# Designed to be sourced from zsh or bash. Do NOT add `set -e` — that would
# leak `errexit` into the caller's interactive shell.

# ─── Defaults (existing env wins via `:=`) ───
: "${WHISPERKIT_PORT:=50060}"
: "${WHISPERKIT_MODEL:=large-v3-v20240930_turbo}"
: "${LLM_MODEL:=llama-3.1-swallow-8b-instruct-v0.5:2}"
export WHISPERKIT_PORT WHISPERKIT_MODEL LLM_MODEL

# Resolve this file's directory (bash uses BASH_SOURCE, zsh uses $0 in sourced files).
# Used by voice_to_avatar to locate phase4b-llm-stream-chunker/chunker.py.
__avatar_helpers_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

avatar_help() {
  cat <<'EOF'
Avatar helpers loaded. Available functions:

  LLM TTFT benchmarks (Phase 1-2)
    ttft [prompt] [model]        curl + jq quick TTFT (no system prompt)
                                   needs: gdate jq
    ttft_sys [user_prompt] [model]  Python TTFT with system prompt
                                   uses $SYSTEM_PROMPT
    ttft_multiturn [turns]       N-turn conversation TTFT decay measurement
                                   default 10 turns

  WhisperKit (Phase 3)
    asr_serve_start              Start whisperkit-cli serve (idempotent)
    asr_serve_stop               Stop the serve process

  ASR utilities (Phase 4 updated)
    asr_record [duration] [out]  Record from mic and run ASR (default 5s)
    asr_latency <wav> [prompt]   Latency benchmark for a canned WAV
                                   prompt is optional bias text
    asr_debug   <wav> [prompt]   Dump raw verbose_json (debug)

  Pipeline
    warmup_llm                   Warm LM Studio KV cache (~3s)
    voice_to_llm [max_seconds]   VAD-recorded speech → ASR → LLM stream (no TTS)
                                   max_seconds = hard cap (default 10)
    voice_to_avatar [max_sec]    VAD-recorded speech → ASR → chunker → VOICEVOX TTS
                                   (Phase 4b: full avatar pipeline, requires
                                    VOICEVOX engine on port 50021 + chunker.py)

  Tunables (env vars)
    WHISPERKIT_PORT              default 50060
    WHISPERKIT_MODEL             default large-v3-v20240930_turbo
    LLM_MODEL                    default llama-3.1-swallow-8b-instruct-v0.5:2
    SYSTEM_PROMPT                 (set this before voice_to_llm / ttft_sys / voice_to_avatar)
    ASR_PROMPT                   default ""  (Phase 4: WhisperKit prompt is broken, disabled)
    VAD_MAX_SEC                  default 10                  (Phase 4)
    VAD_SILENCE_SEC              default 0.8                 (Phase 4)
    VAD_THRESHOLD                default 1   (sox %)         (Phase 4)
    MAX_SENTENCES                default 2   (Phase 4b iv)   voice_to_avatar の N 文 cap (0 で無効)
EOF
}

# ─── Phase 1-2: LLM TTFT benchmarks ───
# Keep both `ttft` (curl) and `ttft_sys` (python). curl version is for quick
# bare-prompt cost; python version handles system prompt & has no extra deps.
ttft() {
  local prompt="${1:-こんにちは}"
  local model="${2:-${LLM_MODEL}}"
  local payload
  payload=$(jq -nc \
    --arg m "$model" \
    --arg p "$prompt" \
    '{model:$m, messages:[{role:"user", content:$p}], stream:true, max_tokens:30}')
  local start
  start=$(gdate +%s.%N)
  curl -sN http://localhost:1234/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "$payload" | while IFS= read -r line; do
      [[ "$line" == data:*'"content"'* ]] || continue
      local now
      now=$(gdate +%s.%N)
      awk -v s="$start" -v n="$now" -v p="$prompt" \
        'BEGIN { printf "TTFT=%.3fs (prompt: %s)\n", n-s, p }'
      break
    done
}

ttft_sys() {
  local user_prompt="${1:-こんにちは}"
  USER_PROMPT="$user_prompt" \
  SYS_PROMPT="${SYSTEM_PROMPT:-}" \
  MODEL="${2:-${LLM_MODEL}}" \
  python3 <<'PYEOF'
import os, json, time, urllib.request
req = urllib.request.Request(
    "http://localhost:1234/v1/chat/completions",
    headers={"Content-Type": "application/json"},
    data=json.dumps({
        "model": os.environ["MODEL"],
        "messages": [
            {"role": "system", "content": os.environ["SYS_PROMPT"]},
            {"role": "user", "content": os.environ["USER_PROMPT"]}
        ],
        "stream": True, "max_tokens": 120
    }).encode()
)
start = time.time(); first = True
with urllib.request.urlopen(req) as r:
    for line in r:
        s = line.decode().strip()
        if not s.startswith("data:") or s == "data: [DONE]": continue
        try:
            obj = json.loads(s[5:].strip())
            content = obj["choices"][0].get("delta", {}).get("content", "")
            if not content: continue
            if first:
                print(f"TTFT={time.time()-start:.3f}s", flush=True); first = False
            print(content, end="", flush=True)
        except Exception: pass
print()
PYEOF
}

# Multi-turn TTFT — detect KV cache decay / sliding-window switch points
ttft_multiturn() {
  TURNS="${1:-10}" \
  MODEL="${LLM_MODEL}" \
  SYS_PROMPT="${SYSTEM_PROMPT:-}" \
  python3 <<'PYEOF'
import os, sys, json, time, urllib.request
turns = int(os.environ["TURNS"]); model = os.environ["MODEL"]
history = [{"role": "system", "content": os.environ["SYS_PROMPT"]}]
for i in range(1, turns + 1):
    history.append({"role": "user", "content": f"ターン{i}: 何か面白い話して"})
    req = urllib.request.Request(
        "http://localhost:1234/v1/chat/completions",
        headers={"Content-Type": "application/json"},
        data=json.dumps({"model": model, "messages": history, "stream": True, "max_tokens": 80}).encode()
    )
    start = time.time(); first = True; response = ""
    with urllib.request.urlopen(req) as r:
        for line in r:
            s = line.decode().strip()
            if not s.startswith("data:") or s == "data: [DONE]": continue
            try:
                obj = json.loads(s[5:].strip())
                content = obj["choices"][0].get("delta", {}).get("content", "")
                if not content: continue
                if first:
                    sys.stdout.write(f"Turn {i}: TTFT={time.time()-start:.3f}s ")
                    sys.stdout.flush(); first = False
                response += content
            except Exception: pass
    snippet = response[:60].replace("\n", "\\n")
    print(f"→ {snippet}...")
    history.append({"role": "assistant", "content": response})
PYEOF
}

# ─── Phase 3: WhisperKit serve management ───
asr_serve_start() {
  if curl -sf "http://localhost:${WHISPERKIT_PORT}/health" >/dev/null 2>&1; then
    echo "WhisperKit already running on :${WHISPERKIT_PORT}"
    return 0
  fi
  echo "Starting WhisperKit serve (model: $WHISPERKIT_MODEL)..."
  nohup whisperkit-cli serve \
    --model "$WHISPERKIT_MODEL" \
    --language ja \
    --use-prefill-cache \
    --skip-special-tokens \
    --without-timestamps \
    >/tmp/whisperkit-serve.log 2>&1 &
  disown
  local i
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
    sleep 1
    if curl -sf "http://localhost:${WHISPERKIT_PORT}/health" >/dev/null 2>&1; then
      echo "Ready on :${WHISPERKIT_PORT}"
      return 0
    fi
  done
  echo "Timeout waiting for WhisperKit (see /tmp/whisperkit-serve.log)"
  return 1
}

asr_serve_stop() {
  pkill -f "whisperkit-cli serve" 2>/dev/null && echo "Stopped" || echo "Not running"
}

# ─── Phase 4: ASR latency benchmark with optional prompt priming ───
# Usage:
#   asr_latency <wav>                  → no prompt
#   asr_latency <wav> "ナオと話す会話。"  → with prompt (note: WhisperKit serve's
#                                          prompt field is broken; see Phase 4 log)
asr_latency() {
  local wav="${1:-/tmp/avatar-asr-test/sample.wav}"
  local prompt="${2:-}"
  if [[ ! -f "$wav" ]]; then
    echo "Usage: asr_latency <wav-file> [prompt]" >&2
    return 1
  fi
  WAV_PATH="$wav" \
  WK_PORT="$WHISPERKIT_PORT" \
  WK_MODEL="$WHISPERKIT_MODEL" \
  ASR_PROMPT="$prompt" \
  python3 <<'PYEOF'
import os, time, json, urllib.request, urllib.error
boundary = "----WhisperBoundary"
fields = {"model": os.environ["WK_MODEL"], "language": "ja", "response_format": "verbose_json"}
prompt = os.environ.get("ASR_PROMPT", "")
if prompt:
    fields["prompt"] = prompt
with open(os.environ["WAV_PATH"], "rb") as f:
    audio = f.read()
body = b""
for k, v in fields.items():
    body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode()
body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.wav\"\r\nContent-Type: audio/wav\r\n\r\n".encode()
body += audio + f"\r\n--{boundary}--\r\n".encode()
req = urllib.request.Request(
    f"http://localhost:{os.environ['WK_PORT']}/v1/audio/transcriptions",
    data=body, method="POST",
    headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
)
start = time.time()
try:
    with urllib.request.urlopen(req) as r:
        result = json.loads(r.read())
    elapsed = time.time() - start
    segs = result.get("segments") or []
    text = (segs[0].get("text") if segs else result.get("text", "?")).strip()
    nsp = segs[0].get("no_speech_prob") if segs else None
    print(f"ASR latency: {elapsed:.3f}s ({result.get('duration', 0):.2f}s audio) [prompt={'on' if prompt else 'off'}]")
    suffix = f"  (no_speech_prob={nsp:.3f})" if isinstance(nsp, (int, float)) else ""
    print(f"Text: {text}{suffix}")
except urllib.error.HTTPError as e:
    print(f"Error: {e.read().decode()}")
PYEOF
}

# ─── Phase 4 debug: dump raw WhisperKit response (verbose_json) ───
# Usage: asr_debug <wav> [prompt]
# Prints the full JSON so we can see segments[] / text / behavior of the prompt field.
asr_debug() {
  local wav="${1:-/tmp/avatar-asr-test/sample.wav}"
  local prompt="${2:-}"
  if [[ ! -f "$wav" ]]; then
    echo "Usage: asr_debug <wav-file> [prompt]" >&2
    return 1
  fi
  WAV_PATH="$wav" \
  WK_PORT="$WHISPERKIT_PORT" \
  WK_MODEL="$WHISPERKIT_MODEL" \
  ASR_PROMPT="$prompt" \
  python3 <<'PYEOF'
import os, json, urllib.request, urllib.error
boundary = "----DebugBoundary"
fields = {"model": os.environ["WK_MODEL"], "language": "ja", "response_format": "verbose_json"}
prompt = os.environ.get("ASR_PROMPT", "")
if prompt:
    fields["prompt"] = prompt
with open(os.environ["WAV_PATH"], "rb") as f:
    audio = f.read()
body = b""
for k, v in fields.items():
    body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode()
body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.wav\"\r\nContent-Type: audio/wav\r\n\r\n".encode()
body += audio + f"\r\n--{boundary}--\r\n".encode()
req = urllib.request.Request(
    f"http://localhost:{os.environ['WK_PORT']}/v1/audio/transcriptions",
    data=body, method="POST",
    headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
)
print(f"--- Request: prompt={'<set>' if prompt else '<none>'} ({prompt!r}) ---")
try:
    with urllib.request.urlopen(req) as r:
        result = json.loads(r.read())
    print("--- Response ---")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    print("--- Summary ---")
    print(f"  result.text     = {result.get('text', None)!r}")
    print(f"  segment count   = {len(result.get('segments') or [])}")
    for i, seg in enumerate(result.get("segments") or []):
        print(f"  segments[{i}].text = {seg.get('text')!r}  start={seg.get('start')} end={seg.get('end')} no_speech={seg.get('no_speech_prob')}")
except urllib.error.HTTPError as e:
    print(f"HTTP {e.code}: {e.read().decode()}")
PYEOF
}

# ─── Phase 3: Mic record → ASR (fixed duration) ───
asr_record() {
  local duration="${1:-5}"
  local out="${2:-/tmp/avatar-asr-test/rec.wav}"
  mkdir -p "$(dirname "$out")"
  echo "🎤 Recording ${duration}s to $out (speak now)..."
  rec -q -r 16000 -c 1 -b 16 "$out" trim 0 "$duration" 2>/dev/null
  echo "Done. Running ASR..."
  asr_latency "$out"
}

# ─── Phase 4 (D): VAD recording ───
# Differences from Phase 3 voice_to_llm:
#   1. Recording auto-stops on trailing silence (sox `silence` effect)
#      → typical utterances finish in 1-3s instead of always 5s
#   2. ASR `prompt` field is wired but disabled by default (Phase 4 §1 found
#      WhisperKit serve's prompt handling broken — long Japanese prompts cause
#      empty output, short ones have no effect). Avatar renamed ミナ → ナオ to
#      avoid the underlying ASR collision (ミナ → 皆さん) at the source.
voice_to_llm() {
  local max_duration="${VAD_MAX_SEC:-${1:-10}}"
  local silence_sec="${VAD_SILENCE_SEC:-0.8}"
  local thresh="${VAD_THRESHOLD:-1}"
  local wav="/tmp/avatar-asr-test/voice-input.wav"
  mkdir -p "$(dirname "$wav")"

  echo "🎤 Listening (max ${max_duration}s, auto-stop after ${silence_sec}s silence)..."
  # silence: <abv_periods> <abv_dur> <abv_thresh> <blw_periods> <blw_dur> <blw_thresh>
  #   first trigger drops leading silence (waits for speech to begin)
  #   second trigger ends recording on trailing silence
  # trim after silence acts as a hard wall-clock cap
  rec -q -r 16000 -c 1 -b 16 "$wav" \
      silence 1 0.3 "${thresh}%" 1 "${silence_sec}" "${thresh}%" \
      trim 0 "$max_duration" 2>/dev/null

  if [[ ! -s "$wav" ]]; then
    echo "(無音検出 — 録音されず)"
    return 0
  fi

  local actual
  actual=$(soxi -D "$wav" 2>/dev/null || echo "?")
  echo "✅ Recorded ${actual}s. Running pipeline..."

  WAV_PATH="$wav" \
  WK_PORT="$WHISPERKIT_PORT" \
  WK_MODEL="$WHISPERKIT_MODEL" \
  ASR_PROMPT="${ASR_PROMPT:-}" \
  LLM="$LLM_MODEL" \
  SYS_PROMPT="${SYSTEM_PROMPT:-}" \
  python3 <<'PYEOF'
import os, time, json, urllib.request, urllib.error

# --- Stage 1: ASR (with optional prompt priming) ---
boundary = "----B"
fields = {"model": os.environ["WK_MODEL"], "language": "ja", "response_format": "verbose_json"}
prompt = os.environ.get("ASR_PROMPT", "")
if prompt:
    fields["prompt"] = prompt
with open(os.environ["WAV_PATH"], "rb") as f:
    audio = f.read()
body = b""
for k, v in fields.items():
    body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode()
body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.wav\"\r\nContent-Type: audio/wav\r\n\r\n".encode()
body += audio + f"\r\n--{boundary}--\r\n".encode()
req = urllib.request.Request(
    f"http://localhost:{os.environ['WK_PORT']}/v1/audio/transcriptions",
    data=body, method="POST",
    headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
)
asr_start = time.time()
try:
    with urllib.request.urlopen(req) as r:
        result = json.loads(r.read())
except urllib.error.HTTPError as e:
    print(f"ASR error: {e.read().decode()}"); raise SystemExit(1)
asr_elapsed = time.time() - asr_start
segs = result.get("segments") or []
text = (segs[0].get("text") if segs else result.get("text", "")).strip()
nsp = segs[0].get("no_speech_prob") if segs else None
if not text:
    print(f"(無音 — 何も認識されず, no_speech_prob={nsp})"); raise SystemExit(0)
nsp_str = f", no_speech={nsp:.2f}" if isinstance(nsp, (int, float)) else ""
print(f"📝 ASR ({asr_elapsed:.3f}s{nsp_str}) [prompt={'on' if prompt else 'off'}]: {text}")

# --- Stage 2: LLM stream ---
llm_req = urllib.request.Request(
    "http://localhost:1234/v1/chat/completions",
    headers={"Content-Type": "application/json"},
    data=json.dumps({
        "model": os.environ["LLM"],
        "messages": [
            {"role": "system", "content": os.environ["SYS_PROMPT"]},
            {"role": "user", "content": text},
        ],
        "stream": True, "max_tokens": 100,
    }).encode(),
)
llm_start = time.time(); first = True; ttft = 0.0; response = ""
print("💬 ナオ ", end="", flush=True)
with urllib.request.urlopen(llm_req) as r:
    for line in r:
        s = line.decode().strip()
        if not s.startswith("data:") or s == "data: [DONE]":
            continue
        try:
            obj = json.loads(s[5:].strip())
            content = obj["choices"][0].get("delta", {}).get("content", "")
            if not content: continue
            if first:
                ttft = time.time() - llm_start
                print(f"(TTFT={ttft:.3f}s): ", end="", flush=True)
                first = False
            response += content
            print(content, end="", flush=True)
        except Exception: pass
print()
e2e = asr_elapsed + ttft
flag = "✅" if e2e < 2.5 else "⚠️"
print(f"⏱️  ASR ({asr_elapsed:.3f}s) + LLM TTFT ({ttft:.3f}s) = {e2e:.3f}s {flag} (target < 2.5s)")
PYEOF
}

# ─── Phase 4b (A integration): full avatar pipeline ───
# voice_to_llm の "stream + print" を chunker.py 経由の "stream + split + speak"
# に置き換えた版。VOICEVOX engine (port 50021) + phase4b-llm-stream-chunker/chunker.py
# が前提。
voice_to_avatar() {
  local max_duration="${VAD_MAX_SEC:-${1:-10}}"
  local silence_sec="${VAD_SILENCE_SEC:-0.8}"
  local thresh="${VAD_THRESHOLD:-1}"
  local wav="/tmp/avatar-asr-test/voice-input.wav"
  local chunker="${__avatar_helpers_dir}/phase4b-llm-stream-chunker/chunker.py"

  if [[ ! -f "$chunker" ]]; then
    echo "ERROR: chunker not found at $chunker" >&2
    return 1
  fi

  mkdir -p "$(dirname "$wav")"

  echo "🎤 Listening (max ${max_duration}s, auto-stop after ${silence_sec}s silence)..."
  rec -q -r 16000 -c 1 -b 16 "$wav" \
      silence 1 0.3 "${thresh}%" 1 "${silence_sec}" "${thresh}%" \
      trim 0 "$max_duration" 2>/dev/null

  if [[ ! -s "$wav" ]]; then
    echo "(無音検出 — 録音されず)"
    return 0
  fi

  local actual
  actual=$(soxi -D "$wav" 2>/dev/null || echo "?")
  echo "✅ Recorded ${actual}s. Running ASR..."

  # Stage 1: ASR (transcript のみ stdout に出力、shell 側で capture)
  local transcript
  transcript=$(WAV_PATH="$wav" \
    WK_PORT="$WHISPERKIT_PORT" \
    WK_MODEL="$WHISPERKIT_MODEL" \
    python3 <<'PYEOF'
import os, json, sys, urllib.request, urllib.error
boundary = "----B"
fields = {"model": os.environ["WK_MODEL"], "language": "ja", "response_format": "verbose_json"}
with open(os.environ["WAV_PATH"], "rb") as f:
    audio = f.read()
body = b""
for k, v in fields.items():
    body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode()
body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.wav\"\r\nContent-Type: audio/wav\r\n\r\n".encode()
body += audio + f"\r\n--{boundary}--\r\n".encode()
req = urllib.request.Request(
    f"http://localhost:{os.environ['WK_PORT']}/v1/audio/transcriptions",
    data=body, method="POST",
    headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
)
try:
    with urllib.request.urlopen(req) as r:
        result = json.loads(r.read())
except urllib.error.HTTPError as e:
    print(f"ASR HTTP error: {e.read().decode()}", file=sys.stderr)
    raise SystemExit(1)
segs = result.get("segments") or []
text = (segs[0].get("text") if segs else result.get("text", "")).strip()
print(text)
PYEOF
)

  if [[ -z "$transcript" ]]; then
    echo "(無音 — 何も認識されず)"
    return 0
  fi
  echo "📝 ASR: ${transcript}"
  echo "💬 ナオ:"

  # Stage 2: chunker.py で LLM stream + 句読点 split + VOICEVOX TTS
  # MAX_SENTENCES default 2 (Phase 4a 「3 文以上 NG」を表示側で隠蔽)、0 で無効
  local max_sent="${MAX_SENTENCES:-2}"
  SYSTEM_PROMPT="${SYSTEM_PROMPT:-}" \
  python3 "$chunker" "$transcript" --tts --bench --max-sentences "$max_sent"
}

# ─── Phase 3: KV cache pre-warmer ───
warmup_llm() {
  echo "🔥 Warming up LLM KV cache..."
  SYS_PROMPT="${SYSTEM_PROMPT:-}" \
  LLM="${LLM_MODEL:-llama-3.1-swallow-8b-instruct-v0.5:2}" \
  python3 <<'PYEOF'
import os, time, json, urllib.request
req = urllib.request.Request(
    "http://localhost:1234/v1/chat/completions",
    headers={"Content-Type": "application/json"},
    data=json.dumps({
        "model": os.environ["LLM"],
        "messages": [
            {"role": "system", "content": os.environ["SYS_PROMPT"]},
            {"role": "user", "content": "おはよう"},
        ],
        "stream": False, "max_tokens": 8,
    }).encode(),
)
start = time.time()
with urllib.request.urlopen(req) as r:
    json.loads(r.read())
print(f"✅ LLM warm ({time.time()-start:.2f}s)")
PYEOF
}

# Print loaded banner the first time this file is sourced in a shell
if [[ -z "${_AVATAR_HELPERS_LOADED:-}" ]]; then
  export _AVATAR_HELPERS_LOADED=1
  echo "✓ avatar-helpers.sh loaded — run 'avatar_help' to list commands"
fi
