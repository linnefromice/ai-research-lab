#!/usr/bin/env bash
#
# check-readable-md.sh — 「読みやすい = 変換しやすい」md の構造を機械チェックする。
#
# 起点レポート §A (読みやすい Markdown 構造原則) / §F-4 (昇華しやすい md かチェックリスト)
# の自動化可能な項目を pure-bash で検証する。node / markdownlint なしでも動く。
#
# 使い方:
#   ./check-readable-md.sh <file.md> [<file.md> ...]
#   ./check-readable-md.sh --lint <file.md>   # 末尾で markdownlint-cli2 も実行 (要 npx, 取得あり)
#
# 終了コード: error が 1 件でもあれば 1 (CI の drift gate 用)。warn のみなら 0。
#
set -euo pipefail

RUN_LINT=0
FILES=()
for arg in "$@"; do
  case "$arg" in
    --lint) RUN_LINT=1 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) FILES+=("$arg") ;;
  esac
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "usage: $0 [--lint] <file.md> [...]" >&2
  exit 2
fi

# 色 (TTY のときだけ)
if [[ -t 1 ]]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_OK=""; C_WARN=""; C_ERR=""; C_DIM=""; C_RST=""
fi

total_errors=0
total_warns=0

# 1 ファイルをチェックして、error 数を標準出力の最終行ではなくグローバルに加算する。
check_file() {
  local file="$1"
  local errors=0 warns=0

  if [[ ! -f "$file" ]]; then
    echo "${C_ERR}✗${C_RST} ${file}: ファイルが存在しない"
    total_errors=$((total_errors + 1))
    return
  fi

  echo "── ${file}"

  # --- frontmatter (title / date) -----------------------------------------
  local has_fm=0 fm_title=0 fm_date=0 fm_marp=0
  local lineno=0 in_fm=0 fm_seen_open=0
  # 見出し / コードフェンス解析用の状態
  local in_fence=0 fence_marker="" h1_count=0 prev_level=0 fence_open_line=0
  local missing_lang_lines="" skip_lines="" style_lines=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))

    # frontmatter: 1 行目が --- なら開始、次の --- で終了
    if [[ $lineno -eq 1 && "$line" == "---" ]]; then
      in_fm=1; fm_seen_open=1; has_fm=1
      continue
    fi
    if [[ $in_fm -eq 1 ]]; then
      if [[ "$line" == "---" ]]; then
        in_fm=0
        continue
      fi
      [[ "$line" =~ ^title： ]] && fm_title=1 || true
      [[ "$line" =~ ^title: ]] && fm_title=1 || true
      [[ "$line" =~ ^date: ]] && fm_date=1 || true
      [[ "$line" =~ ^marp:[[:space:]]*true ]] && fm_marp=1 || true
      continue
    fi

    # コードフェンス開閉 (``` または ~~~)。fence 内では見出しを数えない。
    if [[ "$line" =~ ^[[:space:]]*(\`\`\`+|~~~+)(.*)$ ]]; then
      local marker="${BASH_REMATCH[1]}" rest="${BASH_REMATCH[2]}"
      if [[ $in_fence -eq 0 ]]; then
        in_fence=1; fence_marker="${marker:0:3}"; fence_open_line=$lineno
        # 言語指定 (info string) の有無 — MD040
        local lang="${rest#"${rest%%[![:space:]]*}"}"   # trim leading
        if [[ -z "$lang" ]]; then
          missing_lang_lines+="${lineno} "
        fi
      else
        # 閉じフェンスは同種マーカーで始まる行
        if [[ "${marker:0:3}" == "$fence_marker" ]]; then
          in_fence=0; fence_marker=""
        fi
      fi
      continue
    fi

    [[ $in_fence -eq 1 ]] && continue

    # インラインスタイル (印刷で壊れる) — warn。§C-2 の教訓
    if [[ "$line" == *"style="* ]]; then
      style_lines+="${lineno} "
    fi

    # 見出し: ^#{1,6} + 空白
    if [[ "$line" =~ ^(#{1,6})[[:space:]] ]]; then
      local hashes="${BASH_REMATCH[1]}"
      local level=${#hashes}
      [[ $level -eq 1 ]] && h1_count=$((h1_count + 1)) || true
      if [[ $prev_level -ne 0 && $level -gt $((prev_level + 1)) ]]; then
        skip_lines+="${lineno}(H${prev_level}->H${level}) "
      fi
      prev_level=$level
    fi
  done < "$file"

  # 未閉鎖フェンス
  if [[ $in_fence -eq 1 ]]; then
    echo "  ${C_ERR}✗ MD: コードフェンスが閉じていない (開始 行${fence_open_line})${C_RST}"
    errors=$((errors + 1))
  fi

  # frontmatter 判定
  if [[ $has_fm -eq 0 ]]; then
    echo "  ${C_WARN}⚠ frontmatter なし (title/date/tags 推奨 §A-1#8)${C_RST}"
    warns=$((warns + 1))
  elif [[ $fm_marp -eq 1 ]]; then
    # Marp スライド md は marp/theme/paginate 等が frontmatter。title/date は不要
    # (表紙スライドの # 見出しがタイトルを兼ねる)。
    echo "  ${C_OK}✓ Marp スライド md (title/date は不要)${C_RST}"
  else
    if [[ $fm_title -eq 0 ]]; then
      echo "  ${C_ERR}✗ frontmatter に title がない${C_RST}"; errors=$((errors + 1))
    fi
    if [[ $fm_date -eq 0 ]]; then
      echo "  ${C_WARN}⚠ frontmatter に date がない${C_RST}"; warns=$((warns + 1))
    fi
  fi

  # H1 単一 (MD025)
  if [[ $h1_count -eq 1 ]]; then
    echo "  ${C_OK}✓ H1 は 1 つ (MD025)${C_RST}"
  elif [[ $h1_count -eq 0 ]]; then
    echo "  ${C_ERR}✗ H1 (# タイトル) がない (MD025)${C_RST}"; errors=$((errors + 1))
  else
    echo "  ${C_ERR}✗ H1 が ${h1_count} 個ある — 1 つにする (MD025)${C_RST}"; errors=$((errors + 1))
  fi

  # 見出しスキップ (MD001)
  if [[ -n "$skip_lines" ]]; then
    echo "  ${C_ERR}✗ 見出しレベルを飛ばしている (MD001): 行 ${skip_lines}${C_RST}"
    errors=$((errors + 1))
  else
    echo "  ${C_OK}✓ 見出しを飛ばしていない (MD001)${C_RST}"
  fi

  # コードフェンス言語指定 (MD040)
  if [[ -n "$missing_lang_lines" ]]; then
    echo "  ${C_ERR}✗ 言語指定なしのコードフェンス (MD040): 行 ${missing_lang_lines}${C_RST}"
    errors=$((errors + 1))
  else
    echo "  ${C_OK}✓ 全コードフェンスに言語指定あり (MD040)${C_RST}"
  fi

  # インラインスタイル (warn)
  if [[ -n "$style_lines" ]]; then
    echo "  ${C_WARN}⚠ インライン style= を検出 (印刷で壊れる §C-2): 行 ${style_lines}${C_RST}"
    warns=$((warns + 1))
  fi

  total_errors=$((total_errors + errors))
  total_warns=$((total_warns + warns))
}

for f in "${FILES[@]}"; do
  check_file "$f"
  echo ""
done

# --- 任意: markdownlint-cli2 (npx 取得あり) -------------------------------
if [[ $RUN_LINT -eq 1 ]]; then
  echo "── markdownlint-cli2 (npx)"
  # .markdownlint.jsonc の場所はレイアウトで変わる:
  #   バンドル時:   scripts/check-readable-md.sh  → ../.markdownlint.jsonc
  #   install 後:   tools/readable-md/...         → プロジェクト root の .markdownlint.jsonc
  # 候補を順に探し、無ければ cli2 の自動探索に委ねる (--config 省略)。
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  config_arg=()
  for cand in "${script_dir}/../.markdownlint.jsonc" "${script_dir}/../../.markdownlint.jsonc" "$(pwd)/.markdownlint.jsonc"; do
    if [[ -f "$cand" ]]; then
      config_arg=(--config "$cand")
      break
    fi
  done
  if command -v npx >/dev/null 2>&1; then
    if npx --yes markdownlint-cli2 ${config_arg[@]+"${config_arg[@]}"} ${FILES[@]+"${FILES[@]}"}; then
      echo "  ${C_OK}✓ markdownlint 通過${C_RST}"
    else
      echo "  ${C_ERR}✗ markdownlint 違反あり (上記参照)${C_RST}"
      total_errors=$((total_errors + 1))
    fi
  else
    echo "  ${C_WARN}⚠ npx が無いため markdownlint をスキップ${C_RST}"
  fi
  echo ""
fi

echo "${C_DIM}── 集計${C_RST}"
echo "  error: ${total_errors}  /  warn: ${total_warns}"
if [[ $total_errors -gt 0 ]]; then
  echo "${C_ERR}✗ NG — error を直してから昇華 (HTML/slide 化) へ${C_RST}"
  exit 1
fi
echo "${C_OK}✓ OK — 昇華しやすい md です${C_RST}"
exit 0
