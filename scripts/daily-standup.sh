#!/usr/bin/env bash
# 日次定例: 親リポの最新 daily-report を一覧し、実験候補のハイライトを出す
# 依存: 隣接 clone ../ai-research-pipeline。Read のみ (生成・commit・deploy はしない)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PIPELINE_ROOT=""
if [[ -d "${LAB_ROOT}/../ai-research-pipeline/features" ]]; then
  PIPELINE_ROOT="$(cd "${LAB_ROOT}/../ai-research-pipeline" && pwd)"
fi
TODAY="$(TZ=Asia/Tokyo date +%Y-%m-%d)"

# いま実際に日次レポートが落ちてくる feature (2026-09 時点の実ファイル)
DAILY_FEATURES=(tech-trends finance-markets tech-trends-global)

if [[ -z "${PIPELINE_ROOT}" ]]; then
  echo "Error: 親リポ ../ai-research-pipeline が見つかりません" >&2
  echo "       clone して隣接配置するか、パスを確認してください" >&2
  exit 1
fi

echo "=== 日次定例 ${TODAY} JST ==="
echo "pipeline: ${PIPELINE_ROOT}"
echo "lab:      ${LAB_ROOT}"
echo

# --- 最新レポート一覧 -------------------------------------------------------
echo "## 最新レポート (各 feature の reports/ 最終ファイル)"
printf '%-28s %s\n' "feature" "latest"
printf '%-28s %s\n' "-------" "------"

missing_today=()
shopt -s nullglob
for reports_dir in "${PIPELINE_ROOT}"/features/*/reports; do
  feat="$(basename "$(dirname "${reports_dir}")")"
  [[ "${feat}" == "deep-research" ]] && continue
  latest=""
  for f in "${reports_dir}"/*.md; do
    latest="$(basename "${f}")"
  done
  if [[ -z "${latest}" ]]; then
    continue
  fi
  printf '%-28s %s\n' "${feat}" "${latest}"

  for d in "${DAILY_FEATURES[@]+"${DAILY_FEATURES[@]}"}"; do
    if [[ "${feat}" == "${d}" ]]; then
      if [[ "${latest}" != "${TODAY}"* ]]; then
        missing_today+=("${feat}")
      fi
    fi
  done
done
shopt -u nullglob
echo

if [[ ${#missing_today[@]} -gt 0 ]]; then
  echo "⚠ 本日 (${TODAY}) の daily がまだ無い: ${missing_today[*]}"
  echo "  lab からは親リポを生成しない。pipeline 側の「定型日次」は"
  echo "  ../ai-research-pipeline/scripts/ops-phrase-daily.sh"
  echo
fi

print_highlights() {
  local file="$1"
  local title="$2"
  if [[ ! -f "${file}" ]]; then
    echo "## ${title}"
    echo "(ファイルなし)"
    echo
    return 0
  fi
  echo "## ${title}  —  $(basename "${file}")"
  awk '
    /^## Today'\''s Highlights/ {p=1; next}
    p && /^## / {exit}
    p {print}
  ' "${file}"
  echo
}

latest_in() {
  local dir="$1"
  local glob="$2"
  local last=""
  local f
  shopt -s nullglob
  for f in "${dir}"/${glob}; do
    last="${f}"
  done
  shopt -u nullglob
  printf '%s' "${last}"
}

pick_report() {
  local dir="$1"
  local today_name="$2"
  local glob="$3"
  if [[ -f "${dir}/${today_name}" ]]; then
    printf '%s' "${dir}/${today_name}"
    return 0
  fi
  latest_in "${dir}" "${glob}"
}

tt_dir="${PIPELINE_ROOT}/features/tech-trends/reports"
fm_dir="${PIPELINE_ROOT}/features/finance-markets/reports"
tg_dir="${PIPELINE_ROOT}/features/tech-trends-global/reports"

print_highlights "$(pick_report "${tt_dir}" "${TODAY}.md" "*.md")" "tech-trends"
print_highlights "$(pick_report "${fm_dir}" "${TODAY}.md" "*.md")" "finance-markets"
print_highlights "$(pick_report "${tg_dir}" "${TODAY}.ja.md" "*.ja.md")" "tech-trends-global (JA)"

echo "## 次の一手"
echo "- 試すなら daily-report/<feature>/<date>/<slug>/ を切って README に起点を書く"
echo "- 親リポの定型日次 (生成) は pipeline 側。このスクリプトは Read のみ"
echo "=== 日次定例 END ==="
