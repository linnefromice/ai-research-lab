# m1-pro-local-llm-for-avatar

M1 Pro 32GB MacBook Pro (2021) で動かす AI avatar (ローカル LLM + ASR + TTS + Live2D) の
構築を、**ai-research-pipeline 側で完了した Phase 1-4a の知見を引き継いで** 続行する
ためのトピック。

## 起点 (親リポの研究成果)

このトピックの研究レポート / 実装ログは **ai-research-pipeline (private)** に存在する。Lab 側
からは Read で参照する。**例外: `avatar-helpers.sh` は Phase 4b 期間中 lab を SoT とし、
Phase 4b 完了時に pipeline へ書き戻す** (詳細は末尾 §運用方針 参照、方針反転日 2026-04-29)。

| ファイル | 内容 |
|---|---|
| `../../../ai-research-pipeline/features/deep-research/reports/m1-pro-local-llm-for-avatar.md` | **最終レポート** (3 つの NO + 推奨構成) |
| `../../../ai-research-pipeline/features/deep-research/research/m1-pro-local-llm-for-avatar/00-knowledge-base.md` | 基礎知識 |
| `.../01-web-research.md` | Web 調査 |
| `.../02-analysis.md` | 比較分析 |
| `.../03-validation.md` | 検証 |
| `.../04-phase3-implementation-log.md` | **Phase 3 実装ログ** (PR #428) |
| `.../05-phase4-implementation-log.md` | **Phase 4a 実装ログ** (PR #429) ← 直近の状態 |
| `.../avatar-helpers.sh` | Phase 4a で完成した shell helpers の **凍結版** (元 SoT)。Phase 4b 中は [`./avatar-helpers.sh`](./avatar-helpers.sh) が SoT |
| `.../_sources.json` | 一次情報 URL 集 |

## 現在の確定構成

| 層 | 採用 | 状態 |
|---|---|---|
| OS / Hardware | macOS Sequoia 15.7.3 / M1 Pro 32GB | ✅ 確定 (Phase 4a) |
| LLM | `mlx-community/Llama-3.1-Swallow-8B-Instruct-v0.5-4bit` on **LM Studio** (port 1234) | ✅ 確定 (Phase 4a) |
| ASR | **WhisperKit** serve (`large-v3-v20240930_turbo`) | ✅ 確定 (Phase 4a) |
| VAD | `sox` `silence` effect (0.8s 無音終了 + leading silence 除去) | ✅ 確定 (Phase 4a) |
| キャラ設定 | ナオ (改名後 SYSTEM_PROMPT は Phase 4a ログ §4 / 発見 2) | ✅ 確定 (Phase 4a) |
| **TTS** | **VOICEVOX** (docker `cpu-arm64-latest`, port 50021) / `8 春日部つむぎ:ノーマル` | ✅ 確定 (Phase 4b、2026-04-29、bench 中央値 534ms) |
| **Stream chunker + 統合** | [`chunker.py`](./phase4b-llm-stream-chunker/chunker.py) (句読点 split + VOICEVOX TTS)、`voice_to_avatar` で full pipeline 統合 | ✅ 主要部完了 (Phase 4b、2026-04-29、初音 1491ms) |
| Live2D | 未着手 | 未着手 |

### 実測 latency

| Phase | 計測 | 値 |
|---|---|---|
| 4a | ASR | 0.665 - 0.862s |
| 4a | LLM TTFT | 0.690 - 0.870s |
| 4a | E2E (ASR + LLM TTFT) | 中央値 1.639s |
| **4b** | **VOICEVOX synth** (春日部つむぎ, "んー、おはようございます。") | **534ms** |
| **4b** | **chunker 1 文目 play_start** ("おはよう" prompt) | **1202ms** |
| **4b** | **voice_to_avatar 初音** (生成音声 "今日はいい天気ですね") | **1491ms** ← budget < 2.5s 達成 |

## 推奨 Avatar 起動シーケンス (Phase 4b 版)

```bash
# 1. helpers をシェルに読み込み (lab 側 SoT を source)
source ./avatar-helpers.sh

# 2. WhisperKit を常駐起動 (idempotent)
asr_serve_start

# 3. LM Studio.app で Swallow 8B をロード + Local Server (port 1234) 起動

# 4. VOICEVOX engine を起動 (port 50021)
docker run -d --name voicevox -p 50021:50021 voicevox/voicevox_engine:cpu-arm64-latest

# 5. SYSTEM_PROMPT を export (任意、未指定なら chunker.py の DEFAULT_SYSTEM_PROMPT が効く)
export SYSTEM_PROMPT='あなたは「ナオ」という物静かな...'

# 6. KV cache を事前加熱 (~2-3s)
warmup_llm

# 7. 発話開始 (VAD で動的録音長 + chunker + VOICEVOX TTS)
voice_to_avatar
```

`avatar-helpers.sh` 収録関数: `ttft` / `ttft_sys` / `ttft_multiturn` / `asr_serve_start` /
`asr_serve_stop` / `asr_record` / `asr_latency` / `asr_debug` / `warmup_llm` /
`voice_to_llm` (Phase 4a、ASR+LLM のみ、TTS なし) / **`voice_to_avatar`** (Phase 4b、full pipeline) /
`avatar_help`。詳細は `avatar-helpers.sh` 自体と Phase 4a ログ「avatar-helpers.sh の導入」節を参照。

## ここで進める Phase 4b

Phase 4 のうち未完了の B / C を実機で検証する。

| slug | 内容 | budget | 状態 |
|---|---|---|---|
| [phase4b-tts-bench/](./phase4b-tts-bench/) | TTS 候補比較 (VOICEVOX / AivisSpeech / WhisperKit Qwen3-TTS)、ナオ向け voice 選定 | 初音 latency < 700ms | ✅ 確定 (VOICEVOX `8 春日部つむぎ:ノーマル`、Qwen3-TTS は打ち切り) |
| [phase4b-llm-stream-chunker/](./phase4b-llm-stream-chunker/) | LLM stream を `。/！/？/〜` で split → 1 文目完成と同時に TTS 起動 | 体感で「3 文制約違反」を隠蔽 | ✅ 主要部完了 (`voice_to_avatar` 統合済、初音 1491ms。iv-vi 残) |

## 残課題 (Phase 4b 完了基準)

主要部 (B + C 統合) は完了。完了宣言までの残タスク:

| 項目 | 内容 | 状態 |
|---|---|---|
| **iv** 3 文以上の打ち切り (案 A) | `chunker.py --max-sentences N`、`voice_to_avatar` で default 2 | ✅ 完了 (2026-04-29、4/4 run で意図通り動作) |
| **v** multi-turn history | `~/.cache/avatar-chunker-history.json` に file-based session、`HISTORY_MAX_TURNS=5`。`reset_avatar` 関数追加 | ✅ 完了 (2026-04-29、2 turn 文脈継続を実機で確認) |
| **vi** character drift / 一人称揺れ fewshot | `chunker.py` の messages に 4 pair fewshot 挿入 (default ON、`--no-fewshot` で無効) | ✅ 完了 (2026-04-29、文コンパクト化 + キャラ説明の自然挿入。一人称揺れは iv が間接的に抑制) |
| **書き戻し** | Phase 4b 完了時、lab 側 `avatar-helpers.sh` を pipeline へ書き戻し PR (運用方針 §運用方針 参照) | ⏳ Phase 4b 完了基準達成後 |
| Live2D | 顔 / 口パク / 表情。動作 OK 後で着手 | ⏳ Phase 5 推奨 (PoC では音優先) |

## 別タスク (このトピック内で扱う / 扱わない)

| 項目 | 扱う場所 | 状態 |
|---|---|---|
| **WhisperKit `prompt` field upstream issue** | [whisperkit-prompt-bug-repro/](./whisperkit-prompt-bug-repro/) (lab 内) | 再現リポを最小化して `argmaxinc/WhisperKit` に投稿予定 |
| **system prompt 一人称揺れ / character drift** | Phase 4b の chunker と一緒に fewshot で対処 | Phase 4b 内 |
| **ai-research-pipeline 側 CI infrastructure 修復** | **lab 外 (pipeline 側で別 PR)** | runner 未割当で 2-3 秒 fail (Uptime Monitor / Deploy / Secret Scan)。GitHub Actions 分数枯渇 or Settings 問題。avatar とは無関係 |

## Phase 4a までの主要な発見 (要点抜粋)

詳細は親リポの `05-phase4-implementation-log.md` 参照。Lab で再開する時に頭に
入れておくべきもの:

1. **3 つの NO**: NO Thinking / NO GGUF on Mac / NO Heavy System Prompt (>800 chars)
2. **本命 LLM**: Llama-3.1-Swallow-8B-Instruct-v0.5-4bit (MLX, LM Studio)。Qwen 3.5 系は reasoning デフォルト ON で TTFT 60+ 秒なので NG
3. **改名 ミナ → ナオ**: ASR の同音衝突 ("ミナ" → "皆さん") を name 衝突しない名前で回避
4. **WhisperKit `prompt` field は壊れている**: 句点で終わる prompt で空 transcript。改名で root cause 回避し、issue 投稿は別タスク
5. **VAD は sox の `silence` effect で十分**: `rec ... silence 1 0.3 1% 1 0.8 1% trim 0 10`
6. **3 文制約違反は system prompt 強化では根本解決しない**: 生成側でなく chunker 側で対処 (Phase 4b C)

## このリポ (lab) の制約 (再掲)

- Lab は **public**。秘匿情報を入れない (詳細は [../../README.md](../../README.md))
- 親リポの研究ファイル (00-04, 05, reports/, _sources.json) は **Read のみ**。lab からの作業で改変しない

## 運用方針 — `avatar-helpers.sh` の SoT

| 期間 | SoT | 備考 |
|---|---|---|
| Phase 4a 完了時 (2026-04-28) | pipeline 側 | 元の方針 |
| **Phase 4b 期間中 (2026-04-29 〜)** | **lab 側 [`./avatar-helpers.sh`](./avatar-helpers.sh)** | TTS / chunker の試作で頻繁に編集するため、往復コスト回避 |
| Phase 4b 完了時 | pipeline へ書き戻し | 完了時に pipeline 側で別 PR を切り、SoT を pipeline へ戻す |

Phase 4b 中の編集は lab 側の `avatar-helpers.sh` に対して行う。pipeline 側のファイルは
Phase 4a 時点の凍結版として残し、編集しない (差分は書き戻し PR でまとめる)。
