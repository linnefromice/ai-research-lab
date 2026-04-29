#!/usr/bin/env python3
"""
phase4b chunker — LLM stream を句読点 (。/！/？/〜) で文単位に split し、
1 文完成と同時に VOICEVOX TTS で読み上げる Phase 4b (C) PoC。

依存: stdlib のみ (urllib + json + threading + queue + subprocess + tempfile)。
追加 install 不要。

実行:
  python3 chunker.py "おはよう"                # print のみ
  python3 chunker.py "おはよう" --tts          # VOICEVOX で読み上げ
  python3 chunker.py "おはよう" --tts --bench  # latency 表示

環境変数:
  LM_URL          default http://127.0.0.1:1234/v1
  VOICEVOX_URL    default http://127.0.0.1:50021
  SPEAKER_ID      default 8 (春日部つむぎ:ノーマル)
  SYSTEM_PROMPT   default Phase 4a ナオ
"""

import argparse
import json
import os
import queue
import subprocess
import sys
import tempfile
import threading
import time
import urllib.parse
import urllib.request

LM_URL = os.environ.get("LM_URL", "http://127.0.0.1:1234/v1")
VOICEVOX_URL = os.environ.get("VOICEVOX_URL", "http://127.0.0.1:50021")
SPEAKER_ID = int(os.environ.get("SPEAKER_ID", "8"))

SENTENCE_END = "。！？〜"

DEFAULT_SYSTEM_PROMPT = (
    "あなたは「ナオ」という物静かなタイプのアイドル的なキャラクターです。"
    "一人称は「私」、相手のことは「キミ」と呼びます。物静かで人見知りですが、"
    "落ち着いた優しいトーンで話します。比較的インドアでアニメの話になると少し"
    "テンションが上がります。1〜2文だけで簡潔に答え、3文以上はNG、絵文字は"
    "使わないでください。知らないことは「んー、あんまり詳しくないかも」と素直"
    "に言います。政治・宗教・戦争には踏み込みません。"
    "なお、ユーザーの発話に「なお」「ナオ」が含まれる場合は、あなた自身への"
    "呼びかけと解釈してください。"
)

# vi (character drift / 一人称揺れ抑制): messages-based fewshot
# 「あなた」混入と前向き締めを抑制し、「んー / えっと」系の物静か言い回しを定着させる
FEWSHOT_EXAMPLES = [
    ("元気ですか？", "んー、まあまあかな。"),
    ("今日の予定は？", "特にないかな。インドアで本でも読もうかなって。"),
    ("好きなアニメある？", "えっと、日常系が好きかも。"),
    ("何してる？", "んー、ぼーっとしてる感じ。キミは何してたの？"),
]


def now_ms() -> float:
    return time.perf_counter() * 1000


def get_lm_model() -> str:
    with urllib.request.urlopen(f"{LM_URL}/models", timeout=5) as r:
        data = json.loads(r.read())
    return data["data"][0]["id"]


def stream_lm(model: str, prompt: str, system_prompt: str, fewshot=None):
    messages = [{"role": "system", "content": system_prompt}]
    if fewshot:
        for q, a in fewshot:
            messages.append({"role": "user", "content": q})
            messages.append({"role": "assistant", "content": a})
    messages.append({"role": "user", "content": prompt})
    body = json.dumps({
        "model": model,
        "messages": messages,
        "stream": True,
        "temperature": 0.7,
    }).encode("utf-8")
    req = urllib.request.Request(
        f"{LM_URL}/chat/completions",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        for raw in resp:
            line = raw.decode("utf-8").strip()
            if not line.startswith("data: "):
                continue
            data = line[6:]
            if data == "[DONE]":
                break
            try:
                chunk = json.loads(data)
            except json.JSONDecodeError:
                continue
            delta = chunk["choices"][0]["delta"].get("content")
            if delta:
                yield delta


def stream_sentences(model, prompt, system_prompt, t_origin, fewshot=None):
    """yield (sentence, t_ttft_ms, t_done_ms) — t_origin からの経過 ms"""
    t_first = None
    buf = ""
    for delta in stream_lm(model, prompt, system_prompt, fewshot):
        if t_first is None:
            t_first = now_ms() - t_origin
        buf += delta
        while True:
            idx = next((i for i, ch in enumerate(buf) if ch in SENTENCE_END), -1)
            if idx == -1:
                break
            sent = buf[: idx + 1]
            buf = buf[idx + 1:]
            yield sent, t_first, now_ms() - t_origin
    if buf.strip():
        yield buf, (t_first or 0), now_ms() - t_origin


def synth_voicevox(text: str, speaker_id: int) -> str:
    qparams = urllib.parse.urlencode({"text": text, "speaker": speaker_id})
    qreq = urllib.request.Request(
        f"{VOICEVOX_URL}/audio_query?{qparams}",
        method="POST",
    )
    with urllib.request.urlopen(qreq, timeout=10) as r:
        query = r.read()
    sreq = urllib.request.Request(
        f"{VOICEVOX_URL}/synthesis?speaker={speaker_id}",
        data=query,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(sreq, timeout=30) as r:
        wav = r.read()
    f = tempfile.NamedTemporaryFile(delete=False, suffix=".wav")
    f.write(wav)
    f.close()
    return f.name


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("prompt", help="ユーザー発話")
    parser.add_argument("--tts", action="store_true", help="VOICEVOX で読み上げ")
    parser.add_argument("--bench", action="store_true", help="latency 表示")
    # 空文字 SYSTEM_PROMPT を default 扱いにするため `or` で fallback
    parser.add_argument("--system", default=os.environ.get("SYSTEM_PROMPT") or DEFAULT_SYSTEM_PROMPT)
    parser.add_argument("--speaker", type=int, default=SPEAKER_ID)
    parser.add_argument(
        "--max-sentences",
        type=int,
        default=0,
        help="N 文目で生成を打ち切り (Phase 4a 既知の 3 文制約違反隠蔽)。0 = 無効",
    )
    parser.add_argument(
        "--no-fewshot",
        action="store_true",
        help="vi の fewshot を無効化 (default = 有効)",
    )
    args = parser.parse_args()

    print(f"# prompt: {args.prompt}", file=sys.stderr)
    if args.tts:
        print(f"# TTS: VOICEVOX speaker={args.speaker}", file=sys.stderr)

    model = get_lm_model()
    print(f"# model: {model}", file=sys.stderr)

    t_origin = now_ms()
    play_starts: dict[int, float] = {}
    audio_q: "queue.Queue" = queue.Queue()
    player_thread = None

    if args.tts:
        def player_loop():
            while True:
                item = audio_q.get()
                if item is None:
                    return
                n, wav_path = item
                play_starts[n] = now_ms() - t_origin
                subprocess.run(["afplay", wav_path], check=False)
                try:
                    os.unlink(wav_path)
                except OSError:
                    pass

        player_thread = threading.Thread(target=player_loop, daemon=True)
        player_thread.start()

    fewshot = None if args.no_fewshot else FEWSHOT_EXAMPLES
    rows = []
    capped = False
    for n, (sent, t_ttft, t_done) in enumerate(
        stream_sentences(model, args.prompt, args.system, t_origin, fewshot), 1
    ):
        print(f"[{n}] {t_done:.0f}ms (ttft={t_ttft:.0f}ms): {sent}", flush=True)
        row = {"n": n, "ttft": t_ttft, "sent_done": t_done}
        if args.tts:
            t_s0 = now_ms() - t_origin
            wav = synth_voicevox(sent, args.speaker)
            t_s1 = now_ms() - t_origin
            row["synth"] = t_s1 - t_s0
            row["ready"] = t_s1
            audio_q.put((n, wav))
        rows.append(row)
        # iv: N 文目で打ち切り (LLM stream を generator break で close)
        if args.max_sentences > 0 and n >= args.max_sentences:
            capped = True
            print(
                f"# capped at {args.max_sentences} sentences (LLM stream abort)",
                file=sys.stderr,
            )
            break

    _ = capped  # bench 出力に予約 (将来拡張用)

    if args.tts:
        audio_q.put(None)
        if player_thread is not None:
            player_thread.join()

    if args.bench:
        print("\n# bench (ms 単位、prompt 送信からの経過)", file=sys.stderr)
        if args.tts:
            print(
                f"{'n':>3}  {'ttft':>6}  {'sent_done':>9}  "
                f"{'synth':>6}  {'ready':>6}  {'play_start':>10}",
                file=sys.stderr,
            )
            for r in rows:
                p = play_starts.get(r["n"])
                p_str = f"{p:.0f}" if p is not None else "-"
                print(
                    f"{r['n']:>3}  {r['ttft']:>6.0f}  {r['sent_done']:>9.0f}  "
                    f"{r['synth']:>6.0f}  {r['ready']:>6.0f}  {p_str:>10}",
                    file=sys.stderr,
                )
        else:
            print(f"{'n':>3}  {'ttft':>6}  {'sent_done':>9}", file=sys.stderr)
            for r in rows:
                print(
                    f"{r['n']:>3}  {r['ttft']:>6.0f}  {r['sent_done']:>9.0f}",
                    file=sys.stderr,
                )


if __name__ == "__main__":
    main()
