#!/usr/bin/env bash
# VOICEVOX TTS 初音 latency bench
#
# 計測対象: /audio_query (text → query JSON) + /synthesis (query → WAV) の合計時間。
# VOICEVOX は /synthesis を非ストリームで返すため "初音 latency" ≒ "synthesis 完了時刻"。
# warmup 1 回 + 計測 N 回 (default 5)。
#
# 環境変数:
#   ENGINE_URL  default http://127.0.0.1:50021
#   SPEAKER_ID  default 3 (ずんだもん:ノーマル)
#   TEXT        default "んー、おはようございます。" (Phase 4a で実際に出た発話)
#   TRIALS      default 5
#
# 例:
#   ./bench-voicevox.sh                         # default
#   SPEAKER_ID=2 ./bench-voicevox.sh            # 四国めたん:ノーマル
#   TRIALS=3 TEXT="元気だよ〜!" ./bench-voicevox.sh

set -euo pipefail

ENGINE_URL="${ENGINE_URL:-http://127.0.0.1:50021}"
SPEAKER_ID="${SPEAKER_ID:-3}"
TEXT="${TEXT:-んー、おはようございます。}"
TRIALS="${TRIALS:-5}"

OUT_DIR="$(cd "$(dirname "$0")" && pwd)/audio"
mkdir -p "${OUT_DIR}"

QUERY_TMP="$(mktemp)"
RESULTS_TMP="$(mktemp)"
trap 'rm -f "${QUERY_TMP}" "${RESULTS_TMP}"' EXIT

# ms 単位タイムスタンプ (gdate 必須)
ms() { gdate +%s%3N; }

# URL encode (jq の @uri を流用、日本語安全)
url_encode() { printf '%s' "$1" | jq -sRr @uri; }

readiness_check() {
  if ! curl -sSf "${ENGINE_URL}/version" >/dev/null 2>&1; then
    echo "ERROR: VOICEVOX engine not ready at ${ENGINE_URL}" >&2
    echo "  起動: docker run -d --name voicevox -p 50021:50021 voicevox/voicevox_engine:cpu-arm64-latest" >&2
    exit 1
  fi
}

bench_one() {
  local trial=$1
  local out_wav="${OUT_DIR}/voicevox-spk${SPEAKER_ID}-trial${trial}.wav"
  local text_enc
  text_enc="$(url_encode "${TEXT}")"

  local t0 t1 t2
  t0=$(ms)

  # /audio_query (POST, body 空)
  curl -sSf -X POST \
    "${ENGINE_URL}/audio_query?text=${text_enc}&speaker=${SPEAKER_ID}" \
    -o "${QUERY_TMP}"
  t1=$(ms)

  # /synthesis (POST, body は audio_query JSON)
  curl -sSf -X POST \
    "${ENGINE_URL}/synthesis?speaker=${SPEAKER_ID}" \
    -H "Content-Type: application/json" \
    --data-binary @"${QUERY_TMP}" \
    -o "${out_wav}"
  t2=$(ms)

  printf '%s\t%s\t%s\t%s\n' "${trial}" "$((t1-t0))" "$((t2-t1))" "$((t2-t0))"
}

main() {
  readiness_check

  local version
  version=$(curl -sS "${ENGINE_URL}/version")
  echo "# VOICEVOX engine: ${version}"
  echo "# speaker_id=${SPEAKER_ID}, text=\"${TEXT}\", trials=${TRIALS}"
  echo

  echo "## warmup"
  bench_one 0 >/dev/null
  echo "  done"
  echo

  echo "## measured"
  printf 'trial\tquery_ms\tsynth_ms\ttotal_ms\n'
  : > "${RESULTS_TMP}"

  local i
  for i in $(seq 1 "${TRIALS}"); do
    bench_one "${i}" | tee -a "${RESULTS_TMP}"
  done

  echo
  echo "## median (across ${TRIALS} trials)"
  # BSD awk に asort が無いので sort -n + sed で中央値抽出
  local mid=$(( (TRIALS + 1) / 2 ))
  local med_q med_s med_t
  med_q=$(awk '{print $2}' "${RESULTS_TMP}" | sort -n | sed -n "${mid}p")
  med_s=$(awk '{print $3}' "${RESULTS_TMP}" | sort -n | sed -n "${mid}p")
  med_t=$(awk '{print $4}' "${RESULTS_TMP}" | sort -n | sed -n "${mid}p")
  printf 'query_ms=%s  synth_ms=%s  total_ms=%s\n' "${med_q}" "${med_s}" "${med_t}"
}

main "$@"
