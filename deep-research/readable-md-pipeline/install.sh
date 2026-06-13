#!/usr/bin/env bash
#
# install.sh — readable-md パイプライン (Stage 1-3) を任意プロジェクトへ一括で持ち込む。
#
# 3 つの Stage バンドル (readable-md / md-to-html / md-to-slide) の install.sh を
# まとめて実行する親インストーラ。個別に入れたい場合は各 Stage の install.sh を直接使う。
#
# 使い方:
#   ./install.sh <target-project-dir>            # 全 Stage を入れる
#   ./install.sh --dry-run <target-dir>          # 何が入るか表示のみ
#   ./install.sh --only 1,2 <target-dir>         # Stage を選んで入れる (1=readable-md 2=html 3=slide)
#
# 入るもの (target 配下):
#   .claude/skills/{readable-md,md-to-html,md-to-slide}/SKILL.md
#   .markdownlint.jsonc                          (既存なら skip)
#   tools/readable-md/{check-readable-md.sh,research-skeleton.md}
#   tools/md-to-html/{render-html.sh,report-theme-head.html}
#   tools/md-to-slide/{build-slides.sh,slides-marp.md}
#
set -euo pipefail

DRY=0
ONLY=""
TARGET=""
expect_only=0
for arg in "$@"; do
  if [[ $expect_only -eq 1 ]]; then ONLY="$arg"; expect_only=0; continue; fi
  case "$arg" in
    --dry-run) DRY=1 ;;
    --only) expect_only=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) TARGET="$arg" ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "usage: $0 [--dry-run] [--only 1,2,3] <target-project-dir>" >&2
  exit 2
fi
if [[ ! -d "$TARGET" ]]; then
  echo "error: target dir not found: $TARGET" >&2
  exit 1
fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(cd "$TARGET" && pwd)"

# Stage 定義: key:dir:label
STAGES=(
  "1:readable-md:Stage 1 (読みやすい md を作る)"
  "2:md-to-html:Stage 2 (md → HTML)"
  "3:md-to-slide:Stage 3 (md → slide)"
)

# --only が指定されたら、そのキーだけ通す判定関数
want_stage() {
  local key="$1"
  [[ -z "$ONLY" ]] && return 0
  case ",${ONLY}," in
    *",${key},"*) return 0 ;;
    *) return 1 ;;
  esac
}

passthru=()
[[ $DRY -eq 1 ]] && passthru+=(--dry-run) || true

echo "=== readable-md パイプライン統合インストール ==="
echo "  target: ${TARGET}"
[[ -n "$ONLY" ]] && echo "  only:   ${ONLY}" || true
[[ $DRY -eq 1 ]] && echo "  mode:   dry-run" || true
echo ""

ran=0
for s in "${STAGES[@]}"; do
  key="${s%%:*}"; rest="${s#*:}"; dir="${rest%%:*}"; label="${rest#*:}"
  want_stage "$key" || continue
  installer="${SRC}/${dir}/install.sh"
  if [[ ! -x "$installer" ]]; then
    echo "── ${label}: install.sh が無い/実行不可 (${installer}) — skip" >&2
    continue
  fi
  echo "── ${label}"
  if ! "$installer" ${passthru[@]+"${passthru[@]}"} "$TARGET"; then
    echo "error: ${label} のインストールに失敗" >&2
    exit 1
  fi
  ran=$((ran + 1))
  echo ""
done

if [[ $ran -eq 0 ]]; then
  echo "対象 Stage がありませんでした (--only の指定を確認)" >&2
  exit 1
fi

if [[ $DRY -eq 1 ]]; then
  echo "(dry-run) 上記を入れます。実行: $0 ${ONLY:+--only ${ONLY} }${TARGET}"
  exit 0
fi

echo "=== 完了: ${ran} Stage を ${TARGET} に導入 ==="
echo ""
echo "次の一歩:"
echo "  cd ${TARGET}"
echo "  tools/readable-md/check-readable-md.sh <your.md>    # 1) 構造チェック"
echo "  tools/md-to-html/render-html.sh <your.md>           # 2) md → HTML"
echo "  tools/md-to-slide/build-slides.sh <slides.md>       # 3) slides.md → HTML"
echo "  Claude: /readable-md /md-to-html /md-to-slide       # 各 Stage のスキル"
