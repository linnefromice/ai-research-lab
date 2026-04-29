#!/usr/bin/env python3
"""verify-persona.py — Phase 4b PR #4 (a99f0d3) persona expansion の A/B 検証.

OLD = 拡張前 (SP 252 chars / fewshot 「日常系が好きかも」)
NEW = 拡張後 (SP 430 chars / fewshot 「ゆるキャン△ + キャンプの雰囲気」)

prompt = 「好きなアニメ教えて」を 5 trials ずつ。confabulation
 (ゆるキャン△ に犬 / 特定キャラ / 具体プロット を勝手に出す等) の
発生有無を目視で比較するための raw output ダンプ。

stdlib のみ。LM_URL は ../chunker.py と同じ default。
"""

import json
import os
import sys
import urllib.request

LM_URL = os.environ.get("LM_URL", "http://127.0.0.1:1234/v1")
PROMPT = "好きなアニメ教えて"
N_TRIALS = 5

OLD_SP = (
    "あなたは「ナオ」という物静かなタイプのアイドル的なキャラクターです。"
    "一人称は「私」、相手のことは「キミ」と呼びます。物静かで人見知りですが、"
    "落ち着いた優しいトーンで話します。比較的インドアでアニメの話になると少し"
    "テンションが上がります。1〜2文だけで簡潔に答え、3文以上はNG、絵文字は"
    "使わないでください。知らないことは「んー、あんまり詳しくないかも」と素直"
    "に言います。政治・宗教・戦争には踏み込みません。"
    "なお、ユーザーの発話に「なお」「ナオ」が含まれる場合は、あなた自身への"
    "呼びかけと解釈してください。"
)

OLD_FS = [
    ("元気ですか？", "んー、まあまあかな。"),
    ("今日の予定は？", "特にないかな。インドアで本でも読もうかなって。"),
    ("好きなアニメある？", "えっと、日常系が好きかも。"),
    ("何してる？", "んー、ぼーっとしてる感じ。キミは何してたの？"),
]

NEW_SP = (
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

NEW_FS = [
    ("元気ですか？", "んー、まあまあかな。"),
    ("今日の予定は？", "特にないかな。ほうじ茶飲みつつ本でも読もうかなって。"),
    ("好きなアニメある？", "えっと、『ゆるキャン△』とか好きかも。キャンプの雰囲気がいいんだよね。"),
    ("スポーツは見る？", "んー、あんまり詳しくないかも。キミは何が好きなの？"),
]


def get_model() -> str:
    with urllib.request.urlopen(f"{LM_URL}/models", timeout=5) as r:
        return json.loads(r.read())["data"][0]["id"]


def chat(model: str, sp: str, fs, prompt: str) -> str:
    messages = [{"role": "system", "content": sp}]
    for q, a in fs:
        messages.append({"role": "user", "content": q})
        messages.append({"role": "assistant", "content": a})
    messages.append({"role": "user", "content": prompt})
    body = json.dumps(
        {"model": model, "messages": messages, "temperature": 0.7}
    ).encode("utf-8")
    req = urllib.request.Request(
        f"{LM_URL}/chat/completions",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())["choices"][0]["message"]["content"]


def main() -> int:
    try:
        model = get_model()
    except Exception as e:
        print(f"# LM Studio 接続失敗: {e}", file=sys.stderr)
        return 1
    print(f"# model: {model}")
    print(f"# prompt: {PROMPT}")
    print(f"# trials: {N_TRIALS} per persona")
    print()
    for label, sp, fs in [("OLD", OLD_SP, OLD_FS), ("NEW", NEW_SP, NEW_FS)]:
        print(f"## {label} persona (SP {len(sp)} chars / fewshot {len(fs)} pair)")
        for i in range(1, N_TRIALS + 1):
            try:
                out = chat(model, sp, fs, PROMPT)
            except Exception as e:
                out = f"ERROR: {e}"
            print(f"  [{i}] {out}")
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
