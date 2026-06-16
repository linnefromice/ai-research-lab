#!/usr/bin/env bash
#
# install.sh — readable-md バンドルを任意プロジェクトへ持ち込む (冪等)。
#
# このバンドル (skill / .markdownlint.jsonc / scripts / templates) を、
# 指定プロジェクトの所定位置にコピーする。Stage 1「読みやすい md を作る」を
# どのリポでもすぐ使えるようにするための薄いインストーラ。
#
# 使い方:
#   ./install.sh <target-project-dir>      # コピー実行
#   ./install.sh --dry-run <target-dir>    # 何をコピーするか表示のみ
#
# コピー先 (target 配下):
#   .claude/skills/readable-md/SKILL.md     スキル本体
#   .markdownlint.jsonc                     lint 設定 (drift gate) ※既存があれば skip
#   tools/readable-md/check-readable-md.sh  構造チェッカ
#   tools/readable-md/research-skeleton.md  骨子テンプレ
#
set -euo pipefail

DRY=0
TARGET=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) TARGET="$arg" ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "usage: $0 [--dry-run] <target-project-dir>" >&2
  exit 2
fi
if [[ ! -d "$TARGET" ]]; then
  echo "error: target dir not found: $TARGET" >&2
  exit 1
fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(cd "$TARGET" && pwd)"

# src::dst::overwrite(1)/skip-if-exists(0)
MAPPINGS=(
  "${SRC}/skill/readable-md/SKILL.md::${TARGET}/.claude/skills/readable-md/SKILL.md::1"
  "${SRC}/.markdownlint.jsonc::${TARGET}/.markdownlint.jsonc::0"
  "${SRC}/scripts/check-readable-md.sh::${TARGET}/tools/readable-md/check-readable-md.sh::1"
  "${SRC}/templates/research-skeleton.md::${TARGET}/tools/readable-md/research-skeleton.md::1"
)

copied=0 skipped=0
for m in "${MAPPINGS[@]}"; do
  src="${m%%::*}"; rest="${m#*::}"; dst="${rest%%::*}"; ow="${rest##*::}"
  rel="${dst#"$TARGET"/}"

  if [[ "$ow" -eq 0 && -e "$dst" ]]; then
    echo "skip (既存):      ${rel}"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ $DRY -eq 1 ]]; then
    echo "would copy:       ${rel}"
    continue
  fi

  if ! mkdir -p "$(dirname "$dst")"; then
    echo "error: mkdir failed for $(dirname "$dst")" >&2
    exit 1
  fi
  if ! cp "$src" "$dst"; then
    echo "error: copy failed: $src -> $dst" >&2
    exit 1
  fi
  [[ "$dst" == *.sh ]] && chmod +x "$dst" || true
  echo "copied:           ${rel}"
  copied=$((copied + 1))
done

echo ""
if [[ $DRY -eq 1 ]]; then
  echo "(dry-run) 上記をコピーします。実行: $0 ${TARGET}"
  exit 0
fi
echo "完了: copied=${copied} skipped=${skipped}"
echo ""
echo "次の一歩:"
echo "  1) cd ${TARGET}"
echo "  2) tools/readable-md/check-readable-md.sh <your.md>   # 構造チェック"
echo "  3) Claude で /readable-md <your.md>                    # 執筆/整形"
