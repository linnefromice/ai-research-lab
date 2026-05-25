#!/usr/bin/env bash
#
# apply-patches.sh — Phase 5 OLV (Open-LLM-VTuber v1.2.1) 拡張 patch を冪等に適用
#
# 適用対象:
#   1. voicevox_tts.py          — 新規ファイル (src/open_llm_vtuber/tts/)
#   2. tts_factory.patch        — factory に voicevox_tts 分岐を追加
#   3. config_manager_tts.patch — Pydantic schema 拡張 (5 箇所)
#
# 使い方:
#   ./apply-patches.sh /path/to/Open-LLM-VTuber
#
# 冪等性:
#   - voicevox_tts.py は内容を比較し、同一なら skip
#   - .patch は git apply --check --reverse で適用済判定し、既に当たっていれば skip
#   - 再実行で意図せず壊さない設計
#
# 前提:
#   - OLV が v1.2.1 tag に checkout 済 (詳細は README.md 参照)
#   - OLV repo は clean (他の変更が混在すると patch 適用が読みにくくなる)

set -euo pipefail

OLV_DIR="${1:-}"
if [[ -z "${OLV_DIR}" ]]; then
  echo "Usage: $0 /path/to/Open-LLM-VTuber" >&2
  exit 1
fi

if [[ ! -f "${OLV_DIR}/run_server.py" ]]; then
  echo "Error: OLV repo が見つかりません: ${OLV_DIR}" >&2
  echo "       run_server.py が存在するディレクトリを指定してください" >&2
  exit 1
fi

PATCHES_DIR="$(cd "$(dirname "$0")" && pwd)"
VOICEVOX_TARGET="${OLV_DIR}/src/open_llm_vtuber/tts/voicevox_tts.py"

log()  { printf '%s\n' "$*"; }

# ─── 1. voicevox_tts.py 新規配置 ───
if [[ -f "${VOICEVOX_TARGET}" ]] && cmp -s "${PATCHES_DIR}/voicevox_tts.py" "${VOICEVOX_TARGET}"; then
  log "[skip] voicevox_tts.py — 既に最新"
else
  cp "${PATCHES_DIR}/voicevox_tts.py" "${VOICEVOX_TARGET}"
  log "[ok]   voicevox_tts.py 配置 → ${VOICEVOX_TARGET#${OLV_DIR}/}"
fi

# ─── 2-3. .patch 冪等適用 ───
apply_patch() {
  local patch_file="$1"
  local name
  name="$(basename "${patch_file}")"

  # 逆向きで apply できる → 既に適用済
  if git -C "${OLV_DIR}" apply --check --reverse "${patch_file}" >/dev/null 2>&1; then
    log "[skip] ${name} — 既に適用済"
    return 0
  fi

  # 順方向で apply できる → 適用
  if git -C "${OLV_DIR}" apply --check "${patch_file}" >/dev/null 2>&1; then
    git -C "${OLV_DIR}" apply "${patch_file}"
    log "[ok]   ${name} 適用"
    return 0
  fi

  echo "[error] ${name} — 適用も検出もできません (conflict / OLV tag mismatch?)" >&2
  echo "        OLV が v1.2.1 tag に checkout されているか確認してください" >&2
  return 1
}

apply_patch "${PATCHES_DIR}/tts_factory.patch"
apply_patch "${PATCHES_DIR}/config_manager_tts.patch"

log ""
log "Done. 次のステップ:"
log "  1. conf.yaml 編集 — ./conf-overrides.md 参照 (yq コマンド一覧)"
log "  2. 起動 — リポジトリ root で:"
log "       OLV_DIR='${OLV_DIR}' /path/to/avatar-start.sh"
