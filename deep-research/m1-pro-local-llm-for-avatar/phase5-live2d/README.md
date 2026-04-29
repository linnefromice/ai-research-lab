# phase5-live2d — kickoff context

新セッションで Phase 5 (Live2D による視覚 layer 追加) を始める時に、まず読む文書。
Phase 4b までの音声 layer は完成済 (発話 → ナオが声で応答 + 文脈継続) なので、
Phase 5 は **「ナオに顔を与える + 口パク + 表情」** の独立した拡張。

## 起点

- **トピック README**: [../README.md](../README.md) (Phase 4b 完了状態 + 全体構成図)
- **Phase 4b 実装ログ** (pipeline 側): `../../../../ai-research-pipeline/features/deep-research/research/m1-pro-local-llm-for-avatar/06-phase4b-implementation-log.md`
- **必読の deep-research 2 件** (pipeline 側、2026-04-28 完成):
  - `../../../../ai-research-pipeline/features/deep-research/reports/local-avatar-rendering-stack.md` — レンダリング層の選定、ライセンス、案 A/B/C
  - `../../../../ai-research-pipeline/features/deep-research/reports/open-llm-vtuber-deep-dive.md` — 統合テンプレ評価 (OLV vs AITuberKit)

これら 2 件は Phase 5 の **設計判断の起点**。新セッション開始時に Phase 4b の README に加えて必ず Read する。

## Phase 5 開始時点の状態 (2026-04-29 末時点)

### 動作する音声 avatar pipeline (Phase 4b 完了)

| 層 | 実体 | 起動 |
|---|---|---|
| ASR | WhisperKit serve (port 50060, large-v3-v20240930_turbo) | `asr_serve_start` |
| LLM | Llama-3.1-Swallow-8B 4bit MLX on LM Studio (port 1234) | LM Studio.app + Local Server |
| TTS | VOICEVOX (port 50021, 春日部つむぎ:ノーマル, 534ms) | `docker run voicevox_engine` |
| chunker | `chunker.py` (split + cap=2 + fewshot + history) | `voice_to_avatar` から spawn |
| 統合 | `voice_to_avatar` (avatar-helpers.sh) | `source avatar-helpers.sh` |

実測: 発話 → 初音 1491ms (budget < 2.5s に 40% headroom)。

### SoT (重要)

- `avatar-helpers.sh` + `chunker.py` の SoT は **pipeline 側** (`features/deep-research/research/m1-pro-local-llm-for-avatar/`)
- lab 側の同ファイルは Phase 4b 完了時点の snapshot
- Phase 5 で avatar runtime に手を入れる場合、**変更は pipeline 側で行う** (lab で試作 → 完了後書き戻しの SoT 移行運用は Phase 4b で 1 ラウンド完結済み、再度やるかは判断)

### Phase 4b 完結漏れタスク (Phase 5 の前 or 中で対応)

| 項目 | 推定 | 状態 |
|---|---|---|
| persona 拡張 (PR #4) の M1 検証 | < 30 分 | ✅ 完了 (2026-04-29、OLD/NEW 5 trial 比較。詳細は [phase4b-llm-stream-chunker/README.md persona 拡張 A/B 検証 節](../phase4b-llm-stream-chunker/README.md#persona-拡張-ab-検証-2026-04-29pr-4-a99f0d3-の効果測定)、検証 script は [`verify-persona.py`](../phase4b-llm-stream-chunker/verify-persona.py)) |
| Qwen3-TTS PoC (任意) | < 1 hr | feasibility report (lab `qwen3-tts-feasibility.md`) は WAIT 判定 |
| README 用語修正 (lab 側) | 5 分 | ✅ 完了 (2026-04-29、`phase4b-tts-bench/README.md` 2 箇所 + topic `README.md` 1 箇所を「Qwen3-TTS (MLX stack)」へ統一。`qwen3-tts-feasibility.md` 内は誤り指摘のための引用なので保持) |
| README 用語修正 (pipeline 側) | 5 分 | ⏳ pipeline `06-phase4b-implementation-log.md` L15 / L82 / L327 の「WhisperKit Qwen3-TTS」を「Qwen3-TTS (MLX stack)」へ。lab からは触らない (read-only)、pipeline 側で別 PR |
| pipeline CI infrastructure 修復 | 別タスク | gitleaks/shellcheck が runner 不可で 3s fail (avatar とは無関係、将来の pipeline PR ブロッカー) |

## 採用方針 sketch (research 推奨)

`local-avatar-rendering-stack` の Executive Summary 抜粋:

> **2026-04 時点での最良解は「Live2D Cubism 5 SDK for Web (公式) + Open-LLM-VTuber v1.2 + Web Audio 音量ベース口パク」**

詳細:

| 層 | 採用候補 | 理由 |
|---|---|---|
| **ランタイム** | **Live2D Cubism 5 SDK for Web (公式)** | de facto VTuber 標準、M1 Pro で 60fps、ライセンス費 ¥0 (個人/Small-Scale) |
| **モデル** | **mao_pro** (Live2D 公式サンプル) で開始 | Free Material License 範囲、即時利用可 |
| **lip-sync** | **音量ベース (Web Audio AnalyserNode RMS)** | 8 割の VTuber が採用、latency < 5ms、実装最易 |
| **統合テンプレ** | **Open-LLM-VTuber v1.2.x** (本命) | 7.2k stars, MIT, MCP/memory/vision、ただし VOICEVOX/AivisSpeech native 未サポート → 50-100 行の plugin 必要 |
| 代替テンプレ (短期) | AITuberKit v2.43.x | VOICEVOX native、しかし 2025-11-17 に開発停止アナウンス済 |

**3D (VRM) は将来選択肢として保留**。商用配信を主軸 (年商 2,000 万 JPY 超) に見据える時に、Live2D Publication License 回避のため `@pixiv/three-vrm` + VRoid Studio に移行する案 C が研究内に整理済。

### 重要な発見 (Phase 5 で踏まないように)

1. **AivisSpeech は viseme timing を返さない** (`accent_phrases[].moras[].consonant_length / vowel_length / pitch` がダミー 0.0)。
   → TTS 由来の高品質 viseme stream は **VOICEVOX 採用済** の Phase 4b 構成が活きる場合のみ可能 (Phase 4b は VOICEVOX を採用したので、将来 phoneme-based lip-sync に upgrade する余地あり)
2. **`pixi-live2d-display` は除外**: メンテナンス停止 + Cubism 5 非対応
3. **WebGPU は急がない**: WebGL 2 で十分高 fps、Safari 18 + macOS Sequoia での stable 性は未確実
4. **Live2D ライセンスは 2 段階**: 「Small-Scale (年商 < 1,000 万)」と「Primary Element + 2,000 万超」。VTuber を主収益化するなら 2,000 万閾値で Publication License 有償必須

## Phase 5 で決める必要のあること

### D1: 統合テンプレの採用 (最大の判断)

| 選択肢 | Pro | Con |
|---|---|---|
| **(A) Open-LLM-VTuber v1.2.x** (research 本命) | 機能の幅 (MCP/memory/vision/Pet Mode)、長期メンテ継続、Cubism 5 公式 SDK | VOICEVOX native 未サポート → `tts_factory.py` に 50-100 行 plugin 自作 |
| (B) AITuberKit v2.43.x | VOICEVOX/AivisSpeech native、日本語ドキュメント一次、最短セットアップ | **2025-11-17 開発停止** (bug fix のみ)、新機能なし、VRM は ◎ だが Live2D は v5 not guaranteed |
| (C) 自作 mini frontend | 完全制御、chunker.py を活用しやすい | 時間コスト高、Live2D Web SDK の習熟必要 |

判断材料:
- Phase 4b で VOICEVOX を採用 → (A) は plugin 自作の手間、(B) は即時、(C) は中道
- 「すぐ動かしたい」優先なら (B)、「長期投資」優先なら (A)
- 開発停止の (B) を採用しても Live2D + VOICEVOX 経路の動作確認用としては機能する想定

### D2: モデル

- **(a) mao_pro** (Live2D 公式 sample): 即時開始、free、Free Material License OK
- (b) nizima 購入モデル ($50-500): 配信用キャラ性
- (c) commission ($500-10K): 完全独自

→ Phase 5 の **PoC は (a) で開始**、配信フェーズで (b)/(c) を検討。

### D3: lip-sync 手法

- **(a) 音量ベース** (Web Audio RMS, VTuber 8 割): 実装最易、latency < 5ms、品質低
- (b) lipsync-engine (MIT, AudioWorklet, ~15KB): 中段、3-6 viseme
- (c) VOICEVOX phoneme stream: 最高品質、VOICEVOX 採用前提で Phase 4b 構成が活きる

→ PoC は (a) で開始、品質に物足りなさを感じたら (b) → (c) へ段階的に upgrade。

### D4: chunker.py の役割 (アーキテクチャ転換)

Phase 4b: `voice_to_avatar` (shell) → `chunker.py` (python CLI) → afplay (CLI playback)
Phase 5: browser frontend が中心 → 音声再生も browser → afplay 不要

OLV/AITuberKit を採用すると、chunker.py の機能 (LLM stream、句読点 split、history、cap、fewshot) はテンプレが提供する範囲に **重複** する可能性がある。採用後の判断:
- chunker.py を **廃止** (テンプレに完全移行)
- chunker.py を **backend 関数として再利用** (テンプレが /chat エンドポイントを叩く形)
- chunker.py を **lab snapshot として残す** (CLI 検証用、本流はテンプレ)

OLV は LM Studio native なので、chunker.py の split/cap/fewshot/history と OLV の同等機能の優劣を実機比較してから判断。

### D5: Phase 5 scope (どこを完了点とするか)

- (a) **Minimum**: ブラウザで 1 回 (mao_pro) が voice_to_avatar の応答に合わせて口パクする (録画 demo)
- (b) **PoC**: 連続会話で安定動作、表情切り替え (喜び/驚き/通常)、30 分稼働
- (c) **配信品質**: OBS Browser Source 連携、lip-sync 高品質化、独自モデル

→ **(a) で「動く」状態に到達することを Phase 5 の最小完了基準** に置くのが推奨。(b)(c) は別 phase で扱える。

## アーキテクチャの大きな転換

```
Phase 4b (CLI):
  user mic → voice_to_avatar (shell)
                ↓
              chunker.py (python)
                ↓
              VOICEVOX → afplay → speaker

Phase 5 (browser frontend、案 A 想定):
  user mic → browser (Web Audio + sherpa-onnx VAD)
                ↓ WebSocket
              Open-LLM-VTuber backend (FastAPI)
                ↓ HTTP
              LM Studio (1234) / VOICEVOX (50021) / WhisperKit (50060) ※plugin
                ↓ WebSocket (audio stream)
              browser → AnalyserNode → Live2D PARAM_MOUTH_OPEN_Y → speaker
```

`voice_to_avatar` (shell) は Phase 4b の検証 / debug 用としては引き続き有効、ただし Phase 5 の本流 UX は browser に移る。

## 起動シーケンス (Phase 5 案 A 採用想定)

```bash
# Phase 4b 部分 (変更なし)
asr_serve_start                                            # WhisperKit (50060)
# LM Studio.app で Swallow 8B Load + Local Server (1234)
docker run -d --name voicevox -p 50021:50021 voicevox/voicevox_engine:cpu-arm64-latest

# Phase 5 追加
cd ~/path/to/Open-LLM-VTuber
git checkout v1.2.1
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
# config.yaml: live2d.model = mao_pro, lip_sync.method = volume
# tts_factory.py に VOICEVOX plugin 追加 (50-100 行、既存 chunker.py の synth_voicevox を移植)
python run_server.py
# Browser: http://localhost:12393
```

## Phase 5 サブタスク候補 (実装順、推奨)

| 順 | タスク | 推定 | 依存 |
|---|---|---|---|
| 1 | Phase 4b 完結漏れ消化 (persona 検証 + 用語修正) | 30-60 分 | なし |
| 2 | テンプレ採用判断 (D1)、選定根拠を本 README に追記 | 30 分 | research 再読 |
| 3 | テンプレ install + mao_pro が起動するか確認 | 1 時間 | D1 |
| 4 | VOICEVOX plugin 自作 (OLV 採用なら) | 2-3 時間 | D1=A |
| 5 | LLM/ASR/TTS のテンプレ統合 → 1 回応答 | 2-3 時間 | 4 |
| 6 | 音量ベース lip-sync 動作確認 (D3=a) | 30 分 | 5 |
| 7 | Phase 5 (a) Minimum 達成 → 録画 demo | 30 分 | 6 |
| 8 | 表情切り替え (基本 3-5 種) | 2-3 時間 | 7 |
| 9 | 30 分稼働 + 安定性検証 | 30 分 | 8 |
| 10 | Phase 5 (b) PoC 達成 → 実装ログ作成 (pipeline 側) | 1 時間 | 9 |

## モデル / ライセンス前提 (lab は public)

- **mao_pro** (Live2D 公式 sample): Free Material License、商用 OK (Small-Scale)、再配布 NG
- **lab repo は public** → モデルファイル本体 (`.moc3` / `.png` / `.json`) は **lab に commit しない** 方針推奨
  - 理由: Free Material License の再配布条項、また 1 ファイルが数 MB あり repo 肥大化
  - 配置案: `phase5-live2d/models/.gitignore` で `*` 除外、download/setup は手順として README に書く
- License 詳細は `local-avatar-rendering-stack` §1-4 のシナリオ別表を参照

## 参考: Phase 5 が **必要としない** もの (誤判断防止)

- **multi-turn history を OLV に複製しなくていい** (chunker.py が `~/.cache/avatar-chunker-history.json` で持っているが、OLV 採用後は OLV 側の memory 機構を使う)
- **chunker.py の cap=2 / fewshot を OLV に複製しなくていい** (OLV の system prompt 機構で同等表現が可能、ただし fewshot は messages 形式で渡す前提のため検証要)
- **WhisperKit の使用は OLV/AITuberKit ではサポートされない** (両者とも sherpa-onnx 系)。Phase 4b は WhisperKit を採用したが、Phase 5 では sherpa-onnx に置き換える可能性大 (research 推奨済)
- **AivisSpeech 経路は採用見送り** (Phase 4b で決着、Phase 5 でも VOICEVOX で進める)
