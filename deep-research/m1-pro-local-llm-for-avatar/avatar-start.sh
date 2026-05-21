#!/usr/bin/env bash
#
# avatar-start.sh — Live2D アバター「ナオ」のワンコマンド起動
#
# Phase 5 (PR #8) で達成した 3 サービス構成を、正しい順番で立ち上げる:
#
#   [1] VOICEVOX  (TTS, :50021)  — Docker コンテナ。docker start で再開
#   [2] LM Studio (LLM, :1234)   — GUI アプリ。自動起動不可 → 検知して警告のみ
#   [3] OLV       (ASR+統合, :12393) — Open-LLM-VTuber v1.2.1。フォアグラウンド起動
#
# 起動後、ブラウザで http://localhost:12393 を開くとアバターが表示される。
#
# 使い方:
#   ./avatar-start.sh
#
# OLV の clone 先が標準と違う場合は OLV_DIR で上書き:
#   OLV_DIR=/path/to/Open-LLM-VTuber ./avatar-start.sh
#
# 停止:
#   OLV     — このスクリプトを動かしている端末で Ctrl-C
#   VOICEVOX — docker stop voicevox
#
# 注意: OLV は v1.2.1 に pin している (Phase 6「踏まないリスト」)。
#       このスクリプトは git pull を一切行わない。

set -euo pipefail

# ─── 設定 ───
OLV_DIR="${OLV_DIR:-/Users/linnefromice/repository/github.com/_linnefromice/Open-LLM-VTuber/Open-LLM-VTuber}"
VOICEVOX_CONTAINER="voicevox"
VOICEVOX_PORT=50021
LMSTUDIO_PORT=1234
OLV_PORT=12393
OLV_URL="http://localhost:${OLV_PORT}"
BROWSER_OPEN_DELAY=8   # OLV 起動後ブラウザを開くまでの待ち秒数

# ─── ヘルパ ───
log()  { printf '%s\n' "$*"; }
warn() { printf '⚠ %s\n' "$*" >&2; }
die()  { printf '✗ %s\n' "$*" >&2; exit 1; }

# port が listen 中かどうか (該当なしでも set -e で落とさない)
port_in_use() {
  local p="$1"
  if lsof -ti:"${p}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# ─── [1/3] VOICEVOX (TTS) ───
log "[1/3] VOICEVOX (TTS, :${VOICEVOX_PORT})"

if [[ "$(docker ps --filter "name=^${VOICEVOX_CONTAINER}$" --format '{{.Names}}' 2>/dev/null)" == "${VOICEVOX_CONTAINER}" ]]; then
  log "  既に起動中 — skip"
elif [[ "$(docker ps -a --filter "name=^${VOICEVOX_CONTAINER}$" --format '{{.Names}}' 2>/dev/null)" == "${VOICEVOX_CONTAINER}" ]]; then
  log "  コンテナ停止中 — docker start ${VOICEVOX_CONTAINER}"
  if ! docker start "${VOICEVOX_CONTAINER}" >/dev/null; then
    die "VOICEVOX コンテナの起動に失敗"
  fi
else
  warn "VOICEVOX コンテナ '${VOICEVOX_CONTAINER}' が存在しません。初回は次で作成してください:"
  warn "  docker run -d --name ${VOICEVOX_CONTAINER} -p ${VOICEVOX_PORT}:${VOICEVOX_PORT} \\"
  warn "    voicevox/voicevox_engine:cpu-arm64-latest"
  die "VOICEVOX を用意してから再実行してください"
fi

# /version をポーリングして応答確認 (起動直後は初期化中)
log "  エンジン応答を確認中..."
voicevox_ready=false
for _ in $(seq 1 10); do
  if curl -s --max-time 2 "http://localhost:${VOICEVOX_PORT}/version" >/dev/null 2>&1; then
    voicevox_ready=true
    break
  fi
  sleep 1
done
if [[ "${voicevox_ready}" == "true" ]]; then
  log "  OK"
else
  warn "VOICEVOX が応答しません (初期化に時間がかかっている可能性)。続行します"
fi

# ─── [2/3] LM Studio (LLM) — 検知して警告のみ ───
log "[2/3] LM Studio (LLM, :${LMSTUDIO_PORT})"

if curl -s --max-time 2 "http://localhost:${LMSTUDIO_PORT}/v1/models" >/dev/null 2>&1; then
  log "  OK — Local Server 応答あり"
else
  warn "LM Studio が応答しません (port ${LMSTUDIO_PORT})"
  warn "  LM Studio.app を起動 → 'llama-3.1-swallow-8b-instruct-v0.5' を Load"
  warn "  → Local Server を ON にしてください (後からでも OLV は接続を再試行します)"
fi

# ─── [3/3] Open-LLM-VTuber (ASR + 統合) ───
log "[3/3] Open-LLM-VTuber (ASR+統合, :${OLV_PORT})"

if [[ ! -f "${OLV_DIR}/run_server.py" ]]; then
  die "OLV が見つかりません: ${OLV_DIR}/run_server.py (OLV_DIR を確認してください)"
fi

if port_in_use "${OLV_PORT}"; then
  warn "port ${OLV_PORT} は既に使用中です。OLV が二重起動している可能性があります"
  warn "  既存サーバを使う場合はブラウザで ${OLV_URL} を開いてください"
  die "OLV を多重起動しないため終了します"
fi

# OLV はフォアグラウンドで起動するため、ブラウザは別プロセスで遅延オープン
log "  ${BROWSER_OPEN_DELAY}秒後にブラウザで ${OLV_URL} を開きます"
( sleep "${BROWSER_OPEN_DELAY}"; open "${OLV_URL}" >/dev/null 2>&1 || true ) &

log "  OLV を起動します (停止は Ctrl-C)"
cd "${OLV_DIR}"
exec uv run run_server.py
