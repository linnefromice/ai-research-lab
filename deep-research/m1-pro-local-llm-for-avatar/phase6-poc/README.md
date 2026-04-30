# phase6-poc — kickoff context

新セッションで Phase 6 (= D5 (b) PoC) を始める時に、まず読む文書。
Phase 5 (a) Minimum は技術的に達成済 ([PR #8](https://github.com/linnefromice/ai-research-lab/pull/8))
なので、Phase 6 は **「ナオを連続会話 + 表情切替 + 安定稼働まで含めて整える」** 独立した
品質向上 phase。

## 起点

- **Phase 5 完了状態**: [../phase5-live2d/README.md](../phase5-live2d/README.md) (D1-D5 確定 + サブタスク 3-7 実装ログ + 副次発見 7 件)
- **D4 評価結果**: [../phase5-live2d/D4-evaluation.md](../phase5-live2d/D4-evaluation.md) (chunker.py 役割 = δ + ε + γ snapshot 維持)
- **Phase 4b 実装ログ** (pipeline): `../../../../ai-research-pipeline/features/deep-research/research/m1-pro-local-llm-for-avatar/06-phase4b-implementation-log.md`
- 参考研究 (pipeline、2026-04-28 完成):
  - `local-avatar-rendering-stack.md`
  - `open-llm-vtuber-deep-dive.md`

## Phase 6 開始時点の状態

### 動作する状態 (Phase 5 達成、PR #8 merged)

| 層 | 実体 | 起動 |
|---|---|---|
| ASR | sherpa-onnx (SenseVoice、port 12393 内蔵) | `uv run run_server.py` |
| LLM | Llama-3.1-Swallow-8B 4bit MLX on LM Studio (port 1234) | LM Studio.app + Local Server |
| TTS | VOICEVOX (port 50021、`8 春日部つむぎ:ノーマル`) | `docker run -d --name voicevox -p 50021:50021 voicevox/voicevox_engine:cpu-arm64-latest` |
| 統合 | Open-LLM-VTuber `v1.2.1` + 自作 `voicevox_tts` plugin | `cd $OLV && uv run run_server.py` (port 12393) |
| 表示 | Live2D mao_pro / 音量ベース 口パク (Web Audio AnalyserNode RMS) | Browser localhost:12393 |
| 履歴 | OLV `chat_history/<conf_uid>/<timestamp>_<uuid>.json` | Browser session 終了で自動保存 |

OLV plugin patch は [../phase5-live2d/olv-patches/](../phase5-live2d/olv-patches/) に snapshot。
実機: M1 Pro 32GB / macOS Sequoia 15.7.3 / Chrome。

### Phase 6 で扱うもの (元 Phase 5 scope 外 + D4 結果)

| 項目 | 由来 |
|---|---|
| **D4 実装** (δ: OLV agent cap 機構 + ε: persona V3) | Phase 5 副次発見 3 → D4 評価結果 |
| 元 Phase 5 タスク 8: 表情切替 (`[neutral][joy][sad]` 等の tag を Live2D 表情に bind) | phase5 README サブタスク table 「scope 外」 |
| 元 Phase 5 タスク 9: 30 分稼働 + thermal/fps 計測 | 同上 |
| 元 Phase 5 タスク 10: Phase 5 (b) PoC 達成 → pipeline 側実装ログ作成 | 同上 |

## Phase 6 で決める必要のある事項 (D6-D8)

### D6: 表情切替の実装方針

LLM 出力の表情タグ (`[neutral]` `[joy]` `[sad]` 等) を Live2D の表情に bind する方法。

| 候補 | Pro | Con |
|---|---|---|
| **(a) OLV emotionMap (`model_dict.json`)** | 公式機構、Phase 5 で `mao_pro/runtime/expressions/exp_NN.exp3.json` 8 種類が読み込まれていることを log で確認済 | tag セット (= emotion 種類) は `mao_pro` の表情 set に依存、自由度限定 |
| (b) 自作 viseme + emotion track | 完全制御 | 工数大、Live2D Web SDK の表情 API 直叩き必要 |
| (c) なし (Phase 5 のまま `[neutral]` tag が出るだけで visual 反映なし) | 工数ゼロ | 表情切替なしでは PoC 不成立 |

→ **既定推奨: (a) OLV emotionMap**。Phase 5 ですでに `exp_01.exp3.json` 〜 `exp_08.exp3.json` が読み込まれていることが確認できているので、bind だけで動く想定。

### D7: stability test の範囲

| 候補 | 内容 |
|---|---|
| **(a) Minimum 形** | 30 分稼働 + 目視 fps + `pmset -g thermlog` で thermal 簡易計測 |
| (b) 詳細形 | 1 時間 + Chrome DevTools Performance + 数値化 |
| (c) Standard prompt set | 10 prompt × 3 ターン で発話 latency も含めて計測 |

→ **既定推奨: (a) Minimum 形** で開始、結果を見て (b)(c) を判断。lab CLAUDE.md「動くものを最速で」と整合。

### D8: pipeline 側実装ログのタイミング

| 候補 | 内容 |
|---|---|
| **(a) まとめて 1 commit** | Phase 6 (b) PoC 達成時に Phase 4b 同様の pipeline 書き戻し pattern |
| (b) D4 / D6 / D7 ごとに 個別 PR | 細分化、追跡しやすいが PR 数が増える |

→ **既定推奨: (a) まとめて**。Phase 4b で pipeline #432 単一 PR が機能した pattern を踏襲。

## Phase 6 サブタスク (D6-D8 確定後の暫定 table)

| 順 | タスク | 推定 | 依存 |
|---|---|---|---|
| 0 | **事前ベースライン (A2 + D5)**: `verify-persona-matrix.py` (verify-persona.py の prompt 多様化版) を構築し、persona V1 vs V2 を 5 prompt × 5 trial で測定。**Phase 6 D4 実装前のベースライン値** + persona V2 効果定量を兼ねる。詳細計画は [../phase4b-llm-stream-chunker/README.md#次回検証計画--verify-personapy-多様化版-a2--d5](../phase4b-llm-stream-chunker/README.md#次回検証計画--verify-personapy-多様化版-a2--d5) | 1-1.5 時間 | (着手判断後すぐ) |
| 1 | D6-D8 確定 + 本 README に「Phase 6 決断 (確定)」 節を追記 | 30 分 | research 再読 |
| 2 | **D4 実装 (δ)**: OLV `basic_memory_agent.chat_with_memory` に N 文 cap 機構 | 2-3 時間 | D4 evaluation 結果 |
| 3 | **D4 実装 (ε)**: persona prompt V3 (「3 文以内厳禁」 強調) | 30 分 | 2 |
| 4 | D4 動作確認: ベースラインと **同じ matrix** (5 prompt × 5 trial) で V3 + cap 後の 3 文超過率と「あんまり詳しくない」 出現率を測定し、改善定量化 | 30-45 分 | 0, 3 |
| 5 | **D6 実装**: emotionMap で `[neutral]` 等 tag を Live2D 表情に bind | 2-3 時間 | D6 = (a) |
| 6 | D6 動作確認: 表情変化が visible に出るか目視 | 15 分 | 5 |
| 7 | **D7 実施**: 30 分稼働 + thermal/fps 計測 | 30-60 分 | 5 |
| 8 | (b) PoC 達成判定 + lab 側実装ログ (`phase6-poc/README.md` 末尾に「実装ログ」 節) | 1-2 時間 | 7 |
| 9 | **D8 実施**: pipeline 書き戻し PR (D4/D6 patch + Phase 6 実装ログ) | 30-45 分 | 8 |

累計: 約 10-14 時間 (3-4 セッション想定、サブタスク 0 含む)

## Phase 6 で踏まないリスト (Phase 5 から継承 + 副次発見)

Phase 5 README の [踏まない 4 項目](../phase5-live2d/README.md#重要な発見-phase-5-で踏まないように) は継続有効。加えて Phase 5 サブタスク 3-7 の副次発見から:

- **edge-tts に依存しない** (Microsoft の Sec-MS-GEC token rotation で頻発失敗)
- **OLV main 追従はしない** (`v1.2.1` で tag pin 維持、license 変更回避)
- **persona prompt は trait 指示にとどめる** (hard-code フレーズの過学習回避、Phase 5 副次発見 5)
- **yq 編集時は path 全長確認** (`character_config.tts_config.*` を `.tts_config.*` と書かない、Phase 5 で実際に踏んだ)

## アーキテクチャの拡張 (Phase 5 → Phase 6)

```
Phase 5 (a) Minimum (PR #8 達成):
  user mic → browser (Web Audio + sherpa-onnx VAD)
                ↓ WebSocket
              OLV backend (FastAPI) basic_memory_agent
                ↓ HTTP (lmstudio_llm)
              LM Studio (1234)
                ↓ HTTP (voicevox_tts plugin)
              VOICEVOX (50021)
                ↓ WebSocket (audio stream)
              browser → AnalyserNode → Live2D PARAM_MOUTH_OPEN_Y → speaker

Phase 6 (b) PoC (本 phase 達成目標):
  上記に加えて:
  - basic_memory_agent に "N 文目で stream abort" の早期停止機構 (D4 δ)
  - persona prompt V3 で "3 文厳禁" を強調 (D4 ε)
  - LLM 応答の `[neutral][joy][sad]` tag を OLV emotionMap で
    Live2D `exp_NN.exp3.json` 切替に bind (D6)
  - 30 分連続会話の安定性 + thermal/fps 検証 (D7)
```

## Phase 6 完了基準

D5 = (b) PoC 達成 = (a) Minimum + 表情切替 + 30 分安定稼働 + pipeline 書き戻し。
配信品質 (= D5 (c)) は依然として **別 phase (Phase 7) で扱う**。

Phase 6 (b) PoC を達成した時点で:
- Phase 5 + 6 の合計が D5 = (a) + (b) を full に達成 (= 元 Phase 5 サブタスク 1-10 全部 ✅)
- D4 評価で出した「δ + ε + γ snapshot」 採用結果が実装で検証された状態
- pipeline 側に Phase 6 実装ログが書き戻され、avatar ストーリーは形式的に区切れる
