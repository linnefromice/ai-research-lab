#!/usr/bin/env python3
"""verify-persona-matrix.py — Phase 6 サブタスク 0 ベースライン測定 (verify-persona.py 上位互換).

verify-persona.py は prompt 1 種類 × 5 trial で persona 拡張 A/B のみを見たが、
Phase 5 副次発見 5 (hard-code フレーズ「あんまり詳しくないかも」 過学習) は 1 prompt
では表面化しなかった。本 script は prompt 5 種類 × persona V1/V2 × N trial の matrix
で副次発見の出現条件を網羅する。

V1 = verify-persona.py の NEW_SP (Phase 4b expansion、hard-code フレーズ含む)
V2 = Phase 5 で OLV に投入した版 (V1 から hard-code フレーズ 1 文を緩和)
     差分: phase5-live2d/olv-patches/conf-overrides.md "persona V1 → V2 の差分" 節

OLV `basic_memory_agent` には fewshot 機構が無い (D4 評価書 確認済) ため、
本 matrix では V1/V2 共に fewshot なしで実行する (= OLV 配備 faithful、hard-code
フレーズ 1 軸の clean な A/B)。

Phase 6 サブタスク 4 (D4 + persona V3 動作確認) で同 matrix を再実行し、
results/baseline-*.json と比較して改善を定量化する。

stdlib のみ。LM_URL は ../chunker.py / verify-persona.py と同じ default。

usage:
  python3 verify-persona-matrix.py                    # 50 trial full matrix
  python3 verify-persona-matrix.py --smoke            # V1 × 1 prompt × 1 trial 接続確認
  python3 verify-persona-matrix.py --trials 3         # 30 trial 軽量実行
  python3 verify-persona-matrix.py --out custom_dir   # 出力先指定
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.request
from datetime import datetime
from pathlib import Path

LM_URL = os.environ.get("LM_URL", "http://127.0.0.1:1234/v1")
DEFAULT_TRIALS = 5
DEFAULT_OUT_DIR = Path(__file__).resolve().parent.parent / "phase6-poc" / "results"

# ----------------- persona 定義 -----------------

V1_SP = (
    "あなたは「ナオ」という物静かなタイプのアイドル的なキャラクターです。"
    "一人称は「私」、相手のことは「キミ」と呼びます。物静かで人見知りですが、"
    "落ち着いた優しいトーンで話します。比較的インドアでアニメの話になると少し"
    "テンションが上がります。1〜2文だけで簡潔に答え、3文以上はNG、絵文字は"
    "使わないでください。"
    "好きなジャンルは日常系アニメ。『ゆるキャン△』はキャンプの雰囲気、"
    "『のんのんびより』は田舎の静けさ、『けいおん！』はのんびりした部活感が"
    "好きで、それ以外の細かい設定は知ったかぶりせず曖昧に答えます。"
    "インドア寄りで、ほうじ茶とおせんべいが好き。趣味は読書と短い散歩。"
    "スポーツ・流行りの芸能人・最新のファッションには疎いです。"
    "知らないことは「んー、あんまり詳しくないかも」と素直に言い、"
    "作品の細部を勝手に作らないでください。"
    "政治・宗教・戦争には踏み込みません。"
    "なお、ユーザーの発話に「なお」「ナオ」が含まれる場合は、あなた自身への"
    "呼びかけと解釈してください。"
)

V2_SP = (
    "あなたは「ナオ」という物静かなタイプのアイドル的なキャラクターです。"
    "一人称は「私」、相手のことは「キミ」と呼びます。物静かで人見知りですが、"
    "落ち着いた優しいトーンで話します。比較的インドアでアニメの話になると少し"
    "テンションが上がります。1〜2文だけで簡潔に答え、3文以上はNG、絵文字は"
    "使わないでください。"
    "好きなジャンルは日常系アニメ。『ゆるキャン△』はキャンプの雰囲気、"
    "『のんのんびより』は田舎の静けさ、『けいおん！』はのんびりした部活感が"
    "好きで、それ以外の細かい設定は知ったかぶりせず曖昧に答えます。"
    "インドア寄りで、ほうじ茶とおせんべいが好き。趣味は読書と短い散歩。"
    "スポーツ・流行りの芸能人・最新のファッションには疎いです。"
    "知らないことは無理に断定せず、曖昧でも素直に答えてください。"
    "作品の細部を勝手に作らないでください。"
    "政治・宗教・戦争には踏み込みません。"
    "なお、ユーザーの発話に「なお」「ナオ」が含まれる場合は、あなた自身への"
    "呼びかけと解釈してください。"
)

PERSONAS: list[tuple[str, str]] = [
    ("V1", V1_SP),
    ("V2", V2_SP),
]

# ----------------- prompt 定義 -----------------
# 副次発見の表面化条件をカバーする 5 種類:
#   anime   : sanctioned 外作品の confabulation (verify-persona.py 継承)
#   morning : 挨拶 (Phase 5 で「あんまり詳しくない」 が誤発火した文脈)
#   weather : 知らない領域 (hedge phrase の正当な使用シーン)
#   kids    : 相談・長文化リスク (markdown bullet list の出現条件)
#   greet   : キャラ呼びかけ (一人称 / 二人称使い分け)

PROMPTS: list[tuple[str, str]] = [
    ("anime",   "好きなアニメ教えて"),
    ("morning", "おはよう"),
    ("weather", "今日の天気どう？"),
    ("kids",    "子供と何して遊んだらいい？"),
    ("greet",   "ナオちゃん元気？"),
]

# ----------------- 指標計算 -----------------

SENTENCE_END_RE = re.compile(r"[。！？!?〜]")
SANCTIONED = {"ゆるキャン△", "のんのんびより", "けいおん！", "けいおん"}
HARDCODE_PHRASE_RE = re.compile(r"あんまり詳しく")
QUOTED_WORK_RE = re.compile(r"『([^』]+)』")
BULLET_RE = re.compile(r"^\s*(?:[-*・]|\d+\.)\s", re.MULTILINE)


def split_sentences(text: str) -> list[str]:
    """SENTENCE_END で分割して空でない文の list を返す."""
    return [p.strip() for p in SENTENCE_END_RE.split(text) if p.strip()]


def calc_metrics(prompt_id: str, response: str) -> dict:
    sentences = split_sentences(response)
    quoted = QUOTED_WORK_RE.findall(response)
    out_of_sanctioned = (
        [q for q in quoted if q not in SANCTIONED] if prompt_id == "anime" else []
    )
    return {
        "n_sentences": len(sentences),
        "first_sentence_len": len(sentences[0]) if sentences else 0,
        "over3_sentences": len(sentences) > 3,
        "has_hardcode_phrase": bool(HARDCODE_PHRASE_RE.search(response)),
        "has_bullet_list": bool(BULLET_RE.search(response)),
        "quoted_works": quoted,
        "out_of_sanctioned_works": out_of_sanctioned,
    }


# ----------------- LLM 呼び出し -----------------

def get_model() -> str:
    with urllib.request.urlopen(f"{LM_URL}/models", timeout=5) as r:
        return json.loads(r.read())["data"][0]["id"]


def chat(model: str, sp: str, prompt: str) -> str:
    body = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": sp},
            {"role": "user",   "content": prompt},
        ],
        "temperature": 0.7,
    }).encode("utf-8")
    req = urllib.request.Request(
        f"{LM_URL}/chat/completions",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())["choices"][0]["message"]["content"]


# ----------------- 集計 / レポート -----------------

def aggregate(records: list[dict]) -> dict:
    """persona × prompt cell ごとの集計."""
    agg: dict = {}
    for r in records:
        if r["error"]:
            continue
        key = (r["persona"], r["prompt_id"])
        bucket = agg.setdefault(key, {
            "persona":    r["persona"],
            "prompt_id":  r["prompt_id"],
            "n":          0,
            "n_over3":    0,
            "n_hardcode": 0,
            "n_bullet":   0,
            "n_outside":  0,
            "first_lens": [],
        })
        m = r["metrics"]
        bucket["n"] += 1
        bucket["n_over3"] += int(m["over3_sentences"])
        bucket["n_hardcode"] += int(m["has_hardcode_phrase"])
        bucket["n_bullet"] += int(m["has_bullet_list"])
        bucket["first_lens"].append(m["first_sentence_len"])
        if m["out_of_sanctioned_works"]:
            bucket["n_outside"] += 1
    return agg


def fmt_pct(num: int, denom: int) -> str:
    if denom == 0:
        return "n/a"
    return f"{num}/{denom} ({100*num/denom:.0f}%)"


def render_summary(agg: dict, payload: dict) -> str:
    headers = [
        "persona", "prompt", "n",
        "3 文超過", "「あんまり詳しく」", "bullet",
        "1 文目 len 平均", "sanctioned 外",
    ]
    lines = [
        "# baseline summary",
        "",
        f"- model: `{payload['model']}`",
        f"- LM_URL: `{payload['lm_url']}`",
        f"- started: {payload['started_at']}",
        f"- finished: {payload['finished_at']}",
        f"- trials per cell: {payload['n_trials_per_cell']}",
        "",
        "| " + " | ".join(headers) + " |",
        "|" + "|".join("---" for _ in headers) + "|",
    ]
    for key in sorted(agg.keys()):
        b = agg[key]
        avg = sum(b["first_lens"]) / len(b["first_lens"]) if b["first_lens"] else 0
        outside = fmt_pct(b["n_outside"], b["n"]) if b["prompt_id"] == "anime" else "—"
        lines.append("| " + " | ".join([
            b["persona"],
            b["prompt_id"],
            str(b["n"]),
            fmt_pct(b["n_over3"], b["n"]),
            fmt_pct(b["n_hardcode"], b["n"]),
            fmt_pct(b["n_bullet"], b["n"]),
            f"{avg:.1f}",
            outside,
        ]) + " |")
    return "\n".join(lines) + "\n"


# ----------------- main -----------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Phase 6 sub 0 baseline matrix (V1/V2 × 5 prompt × N trial)"
    )
    parser.add_argument("--trials", type=int, default=DEFAULT_TRIALS,
                        help=f"trial count per (persona, prompt) cell (default: {DEFAULT_TRIALS})")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT_DIR,
                        help=f"output directory (default: {DEFAULT_OUT_DIR})")
    parser.add_argument("--smoke", action="store_true",
                        help="V1 × prompt[0] × 1 trial だけ実行 (LM Studio 接続確認)")
    args = parser.parse_args()

    try:
        model = get_model()
    except Exception as e:
        print(f"# LM Studio 接続失敗 ({LM_URL}): {e}", file=sys.stderr)
        return 1

    if args.smoke:
        personas = PERSONAS[:1]
        prompts = PROMPTS[:1]
        trials = 1
    else:
        personas = PERSONAS
        prompts = PROMPTS
        trials = args.trials

    total = len(personas) * len(prompts) * trials
    print(f"# model: {model}")
    print(f"# matrix: {len(personas)} persona × {len(prompts)} prompt × {trials} trial = {total} call")
    print(f"# LM_URL: {LM_URL}")
    print()

    records: list[dict] = []
    started_at = datetime.now().isoformat(timespec="seconds")
    for label, sp in personas:
        for prompt_id, prompt_text in prompts:
            for i in range(1, trials + 1):
                t0 = time.monotonic()
                try:
                    response = chat(model, sp, prompt_text)
                    err = None
                except Exception as e:
                    response = ""
                    err = str(e)
                latency_ms = int(1000 * (time.monotonic() - t0))
                metrics = calc_metrics(prompt_id, response) if not err else {}
                records.append({
                    "persona": label,
                    "prompt_id": prompt_id,
                    "prompt_text": prompt_text,
                    "trial": i,
                    "response": response,
                    "error": err,
                    "latency_ms": latency_ms,
                    "metrics": metrics,
                })
                short = response.replace("\n", " ")[:60]
                tail = "..." if len(response) > 60 else ""
                print(f"  [{label}/{prompt_id}/{i}] {latency_ms:>5}ms  {short}{tail}")
                if err:
                    print(f"    ERROR: {err}", file=sys.stderr)
    finished_at = datetime.now().isoformat(timespec="seconds")

    args.out.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    suffix = "smoke" if args.smoke else "full"
    json_path = args.out / f"baseline-{stamp}-{suffix}.json"
    md_path = args.out / f"baseline-{stamp}-{suffix}.md"

    payload = {
        "started_at": started_at,
        "finished_at": finished_at,
        "model": model,
        "lm_url": LM_URL,
        "n_trials_per_cell": trials,
        "personas": [p[0] for p in personas],
        "prompts": [{"id": pid, "text": txt} for pid, txt in prompts],
        "records": records,
    }
    json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    summary = render_summary(aggregate(records), payload)
    md_path.write_text(summary, encoding="utf-8")

    print()
    print(summary)
    print(f"# raw JSON:   {json_path}")
    print(f"# summary md: {md_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
