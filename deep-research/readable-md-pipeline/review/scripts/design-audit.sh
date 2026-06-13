#!/usr/bin/env bash
#
# design-audit.sh — 生成物が「見た目 human friendly」か、デザイン原則で機械監査する。
#
# ノンデザイナーズ・デザインブックの C.R.A.P. (Contrast / Repetition / Alignment /
# Proximity) + タイポグラフィの、静的に測れる部分を定量化する。デザイン判断の大半は
# theme の CSS トークンに集約されているので、トークンを解析するだけで多くが測れる。
#
# 測るもの (決定論):
#   - Contrast : 文字/背景の WCAG コントラスト比 (画面ダーク & 印刷ライト両方)
#   - Typography: 行長 (1 行の文字数), 行間, 見出しの type scale
#   - Repetition: 生成 HTML のインライン style= 混入 (単一ソース違反)
#   - Palette  : 色トークン数 (パレット規律)
# Alignment / Proximity の視覚評価は design-review スキル (LLM) に委ねる。
#
# 使い方:
#   ./design-audit.sh [--theme <report-theme-head.html>] [<generated.html> ...]
#   theme 省略時はパイプラインの md-to-html テーマを自動で探す。
#   HTML を渡すとインライン style / 色使いも見る。
#
# 終了コード: WCAG AA 未満 (本文 < 4.5) が 1 件でもあれば 1。warn のみなら 0。
#
set -euo pipefail

THEME=""
HTML_FILES=()
expect_theme=0
for arg in "$@"; do
  if [[ $expect_theme -eq 1 ]]; then THEME="$arg"; expect_theme=0; continue; fi
  case "$arg" in
    -t|--theme) expect_theme=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) HTML_FILES+=("$arg") ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$THEME" ]]; then
  for cand in \
    "${script_dir}/../../md-to-html/assets/report-theme-head.html" \
    "${script_dir}/../md-to-html/assets/report-theme-head.html" \
    "$(pwd)/tools/md-to-html/report-theme-head.html"; do
    if [[ -f "$cand" ]]; then THEME="$cand"; break; fi
  done
fi
if [[ -z "$THEME" || ! -f "$THEME" ]]; then
  echo "error: theme (report-theme-head.html) が見つからない。--theme で指定を" >&2
  exit 1
fi

if [[ -t 1 ]]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_OK=""; C_WARN=""; C_ERR=""; C_DIM=""; C_RST=""
fi

echo "=== design-audit (C.R.A.P. + typography) ==="
echo "theme: ${THEME}"
echo ""

# --- theme トークン解析 + コントラスト/タイポ計算 (gawk) -------------------
# AA: 本文 4.5 / 大文字(見出し) 3.0。理由つきで pass/warn/fail を返す。
audit_out="$(awk '
function hexv(s,   n,i,c,d){ s=tolower(s); gsub(/#/,"",s); n=0
  for(i=1;i<=length(s);i++){ c=substr(s,i,1); d=index("0123456789abcdef",c)-1; if(d<0)d=0; n=n*16+d }
  return n }
function lin(v){ v=v/255; return (v<=0.03928)? v/12.92 : ((v+0.055)/1.055)^2.4 }
function lum(h,  r,g,b){ r=hexv(substr(h,1,2)); g=hexv(substr(h,3,2)); b=hexv(substr(h,5,2));
  return 0.2126*lin(r)+0.7152*lin(g)+0.0722*lin(b) }
function ratio(a,b,  l1,l2,t){ gsub(/#/,"",a); gsub(/#/,"",b);
  l1=lum(a)+0.05; l2=lum(b)+0.05; if(l2>l1){t=l1;l1=l2;l2=t} return l1/l2 }
function grade(r,thr){ return (r>=thr)?"PASS":((r>=thr-1.0)?"WARN":"FAIL") }

# トークン収集: @media print の前後で screen[] / print[] に振り分ける。
# 1 行に複数トークン (--a: #x; --b: #y;) があるので while で全部拾う。
/@media[ ]+print/ { inprint=1 }
{
  line=$0
  while (match(line, /--[a-z0-9-]+:[ ]*#[0-9a-fA-F]{3,6}/)) {
    tok=substr(line, RSTART, RLENGTH)
    line=substr(line, RSTART+RLENGTH)
    name=tok; sub(/:.*/,"",name)        # "--text-sub"
    val=tok;  sub(/^[^#]*/,"",val)      # "#5a6070"
    if(inprint) printv[name]=val; else screenv[name]=val
  }
}
# 本文 line-height は screen の body (複数行ルール) から最初の 1 件を採用
inprint==0 && bodylh==0 && /line-height:[ ]*[0-9.]+/ {
  if(match($0,/line-height:[ ]*[0-9.]+/)){ s=substr($0,RSTART,RLENGTH); gsub(/[^0-9.]/,"",s); bodylh=s }
}
# type scale (screen の最初の出現を採用)
/^[ ]*h1[ ]*\{/ && h1sz==0 { if(match($0,/font-size:[ ]*[0-9.]+px/)){ s=substr($0,RSTART,RLENGTH); gsub(/[^0-9.]/,"",s); h1sz=s } }
/^[ ]*h2[ ]*\{/ && h2sz==0 { if(match($0,/font-size:[ ]*[0-9.]+px/)){ s=substr($0,RSTART,RLENGTH); gsub(/[^0-9.]/,"",s); h2sz=s } }
/^[ ]*h3[ ]*\{/ && h3sz==0 { if(match($0,/font-size:[ ]*[0-9.]+px/)){ s=substr($0,RSTART,RLENGTH); gsub(/[^0-9.]/,"",s); h3sz=s } }
/\.container[ ]*\{/ && cmax==0 { if(match($0,/max-width:[ ]*[0-9.]+px/)){ s=substr($0,RSTART,RLENGTH); gsub(/[^0-9.]/,"",s); cmax=s } }

END {
  bodysz = (bodysz>0)?bodysz:16   # body は font-size 未指定なら 16px 既定

  print "## Contrast (C) — WCAG コントラスト比"
  ncol=0; for(k in screenv) ncol++
  # 監査対象ペア: ラベル|fg トークン|bg トークン|閾値
  npair = split("本文 text/bg|--text|--bg|4.5;補助文 text-sub/bg|--text-sub|--bg|4.5;リンク accent/bg|--accent|--bg|4.5;見出し accent2/bg|--accent2|--bg|3.0", pairs, ";")
  for (theme="screen"; ; theme=(theme=="screen"?"print":"done")) {
    if(theme=="done") break
    print "  ["theme"]"
    for(i=1;i<=npair;i++){
      n=split(pairs[i],p,"|"); lbl=p[1]; fg=(theme=="screen")?screenv[p[2]]:printv[p[2]]; bg=(theme=="screen")?screenv[p[3]]:printv[p[3]]; thr=p[4]+0
      if(fg=="" || bg=="") { print "    ? "lbl": トークン未取得"; continue }
      r=ratio(fg,bg); g=grade(r,thr)
      printf "    %-4s %-22s %5.2f:1  (要 %.1f)\n", (g=="PASS"?"OK":(g=="WARN"?"~":"NG")), lbl, r, thr
      if(g=="FAIL") fails++
      else if(g=="WARN") warns++
    }
  }
  print ""
  print "## Typography — 可読性"
  if(cmax>0){
    cpl = cmax / bodysz   # 1 行のおおよその全角文字数 (JP は ~1em/字)
    printf "  行長: container %dpx / body %dpx ≒ %d 文字/行", cmax, bodysz, int(cpl)
    if(cpl>45){ print "  "(("~"))" 広い (JP 快適域 ~30-45。max-width を狭めるか段組み検討)"; warns++ }
    else print "  OK"
  }
  if(bodylh>0){
    printf "  行間: %.2f", bodylh
    if(bodylh>=1.4 && bodylh<=1.9) print "  OK"
    else { print "  ~ 範囲外 (本文は 1.4-1.9 が快適)"; warns++ }
  }
  if(h1sz>0 && h2sz>0 && h3sz>0){
    printf "  type scale: h1 %d / h2 %d / h3 %d / body %d px\n", h1sz,h2sz,h3sz,bodysz
    if(h3sz<=bodysz){ print "    ~ h3 が本文と同サイズ — 見出しのサイズ強弱が弱い (色/太さ頼み)"; warns++ }
    else print "    OK (h1>h2>h3>body)"
  }
  print ""
  print "## Palette — 色の規律"
  printf "  画面テーマの色トークン数: %d", ncol
  if(ncol>12){ print "  ~ 多い (12 以内が管理しやすい)"; warns++ } else print "  OK"

  print ""
  printf "FAILS=%d WARNS=%d\n", fails+0, warns+0
}
' "$THEME")"

# レポート本体を表示 (最終行のサマリは除く)
echo "$audit_out" | sed '$d'

# サマリ行から fails/warns を取り出す
summary="$(echo "$audit_out" | tail -1)"
fails="${summary#FAILS=}"; fails="${fails%% *}"
warns="${summary##*WARNS=}"

total_fail=$((fails))
total_warn=$((warns))

# --- Repetition (R): 生成 HTML のインライン style 監査 ---------------------
if [[ ${#HTML_FILES[@]} -gt 0 ]]; then
  echo ""
  echo "## Repetition (R) — 単一ソース遵守 (生成 HTML)"
  for f in "${HTML_FILES[@]}"; do
    if [[ ! -f "$f" ]]; then echo "  ? ${f}: 無い"; continue; fi
    # <style> ブロック内は除外し、body 要素の inline style= を数える
    inline="$( { grep -oE '<[a-zA-Z][^>]*[[:space:]]style=' "$f" || true; } | wc -l | tr -d ' ')"
    if [[ "$inline" -gt 0 ]]; then
      echo "  ${C_WARN}~ ${f}: インライン style= が ${inline} 箇所 (印刷で壊れる / Repetition 違反)${C_RST}"
      total_warn=$((total_warn + 1))
    else
      echo "  ${C_OK}OK ${f}: インライン style= なし${C_RST}"
    fi
  done
fi

echo ""
echo "## Alignment (A) / Proximity (P)"
echo "  ${C_DIM}静的監査の範囲外。レンダリング結果に design-review スキル (LLM) で C.R.A.P. を当てる。${C_DIM}"
echo "  ${C_DIM}(端揃え・グリッドの乱れ・関連要素のグルーピングは目視/スクショ判定)${C_RST}"

echo ""
echo "${C_DIM}── 集計${C_RST}"
echo "  FAIL: ${total_fail}  /  WARN: ${total_warn}"
if [[ "${total_fail}" -gt 0 ]]; then
  echo "${C_ERR}✗ コントラスト AA 未満あり — theme のトークンを直す${C_RST}"
  exit 1
fi
echo "${C_OK}✓ 致命的なデザイン違反なし (WARN は改善余地)${C_RST}"
exit 0
