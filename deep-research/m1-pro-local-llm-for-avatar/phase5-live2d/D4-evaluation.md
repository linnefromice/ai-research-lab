# D4 評価 — chunker.py の役割の確定

## 起点

Phase 5 着手時 (2026-04-29、PR #7) に「サブタスク 5 後に再評価」 と保留した
**D4 (chunker.py の役割)** を、Phase 5 (a) Minimum 達成 (PR #8) で得た副次発見を
踏まえて確定する評価ドキュメント。

- Phase 5 D1-D5 決断: [./README.md#phase-5-決断-2026-04-29-確定](./README.md#phase-5-決断-2026-04-29-確定)
- 副次発見の出元: [./README.md#サブタスク-3-7-実装ログ-2026-04-30](./README.md#サブタスク-3-7-実装ログ-2026-04-30)
- D4 候補比較材料: [./README.md#d4-chunkerpy-の役割-アーキテクチャ転換](./README.md#d4-chunkerpy-の役割-アーキテクチャ転換)

## 副次発見の整理 (Phase 5 で観測)

| 観測 | impact | D4 への効き方 |
|---|---|---|
| OLV native で persona の「3 文以内」 制約が破られる (markdown bullet list の長文応答) | high (UX) | **persona prompt 単独では押さえきれない** → 構造的解決の必要性 |
| OLV codebase に fewshot 機構なし (`basic_memory_agent` は system + memory のみ) | medium (アーキ) | chunker.py の `FEWSHOT_EXAMPLES` 移植は構造的に困難 |
| persona の hard-code フレーズが LLM に定型語尾として過学習 | medium (UX) | persona prompt は trait 指示にとどめる方針が妥当 |
| OLV `chat_history` JSON が A/B 比較用永続ログとして使える | low (再利用) | 検証ツール (verify-persona の後継) の入力源になる |

## 候補と評価

D1 採用時の Phase 5 README に列挙した α/β/γ + Phase 5 副次発見から派生した δ/ε の
合計 5 候補を比較。

### 候補 α: 廃止 (テンプレに完全移行)

| 観点 | 評価 |
|---|---|
| Pros | SoT 一本化、メンテ重複なし、lab 側ファイル削減 |
| Cons | **副次発見「3 文制約破り」 を解決しない**、Phase 4b 実装の cap=2 / fewshot / multi-turn history が失われる |
| 採否 | ❌ NG |

副次発見 (3 文制約破り) の解決にならない以上、現実的選択肢ではない。

### 候補 β: backend 関数として再利用

| 観点 | 評価 |
|---|---|
| Pros | Phase 4b knowledge 完全活用、3 文制約破り解決 |
| Cons | **OLV と chunker.py で memory 二重管理** (`~/.cache/avatar-chunker-history.json` と OLV `chat_history/`)、アーキ複雑化、chunker.py を OLV から呼ぶインタフェース新設 (HTTP API 化等) が必要 |
| 採否 | 🟡 効果あるが工数とアーキ複雑化のバランスが悪い |

knowledge 活用は最大だが、memory 二重管理の整合コストが大きい。lab CLAUDE.md
「動くものを最速で / 作り込みすぎない」 に逆行する。

### 候補 γ: lab snapshot として残す (Phase 5 着手時の選択)

| 観点 | 評価 |
|---|---|
| Pros | 現状維持、影響なし、CLI debug は引き続き可能 |
| Cons | **副次発見「3 文制約破り」 を解決しない**、「snapshot 維持」 が実質的に放置と区別できない |
| 採否 | ⚠️ 短期判断としては妥当、しかし副次発見の今となっては不十分 |

Phase 5 着手前 (2026-04-29) の判断としては正しかった。ただし副次発見で
「persona prompt 単独では 3 文制約を守れない」 が確認された後では、γ 単独では
Phase 6 (b) PoC の品質を保証できない。

### 候補 δ: OLV agent に cap 機構を追加

Phase 5 副次発見 3 を受けて新規派生した候補。

| 観点 | 評価 |
|---|---|
| Pros | OLV 内部完結 (外部依存追加なし)、knowledge transfer (Phase 4b chunker.py の split + cap だけ移植) が直接的、upstream PR 候補にもなりうる |
| Cons | `basic_memory_agent.py` への patch が必要、stream の途中 abort を OLV agent でやる必要、`faster_first_response: True` との相性確認要 |
| 採否 | ✅ 影響範囲が局所、構造的解決 |

`SENTENCE_END = "。！？〜"` で句点を検出して N 文超過で stream を early break する
処理を `chat_with_memory` に追加するだけで済む。chunker.py の `--max-sentences=2`
と同等の挙動を OLV native で実現できる。

### 候補 ε: persona prompt 強化 (γ + 追加)

| 観点 | 評価 |
|---|---|
| Pros | 一番安価 (1 文 edit)、副作用なし |
| Cons | **LLM の system prompt 遵守度に頼る** (副次発見 5 で「hard-code は過学習する」 と確認済 = 遵守度ベースの解は不安定)、副次発見 3 (markdown bullet list 長文) は persona 単独では押さえきれない |
| 採否 | ⚠️ ベースライン的、確実性低 |

「3 文以内」 を ALL CAPS / 繰り返し / 否定強調で書く程度。ただし副次発見 3 の観測上、
persona 強化だけでは markdown bullet list を抑止できない。

## 採用判断

### **採用: δ + ε + γ** (構造解 + ベースライン + snapshot)

| 役割 | 採用候補 | 効果 |
|---|---|---|
| **構造的解決** | **δ** OLV agent に cap 機構 | N 文超過で stream early break (Phase 4b cap=2 と同等) |
| **ベースライン** | **ε** persona prompt V3 (「3 文以内」 強調) | δ の遵守ガイド、UX 補助 |
| **chunker.py 取扱** | **γ** snapshot 維持 (継続) | CLI 検証ツールとして残す、本流は OLV |

### Phase 4b 機能の OLV native 代替表

採用結果により、Phase 4b の chunker.py 主要機能 (i / iv / v / vi) は OLV native で
全部代替可能になる:

| Phase 4b 機能 | OLV native での代替 |
|---|---|
| (i) split (`SENTENCE_END` 句点検出) | OLV `pysbd` (`segment_method: 'pysbd'`、conf.yaml で設定済み) |
| (iv) cap (`--max-sentences=2`) | **δ で実装 (本評価結果)** |
| (v) multi-turn history (`~/.cache/...json`) | OLV `chat_history/<conf_uid>/<timestamp>_<uuid>.json` |
| (vi) fewshot (`FEWSHOT_EXAMPLES`) | persona prompt + ε で trait レベル指示 |

## Phase 6 への引き渡し

採用結果 = δ + ε (γ snapshot 維持は無編集) を Phase 6 で実装する。
Phase 6 サブタスク table に以下を組み込む:

1. `basic_memory_agent.py` の `chat_with_memory` で stream を文単位で abort する diff を draft (~30 行想定)
2. `conf.yaml` schema 拡張: `agent_settings.basic_memory_agent.max_sentences: int = 2` を許容 (Pydantic schema 1 箇所追加)
3. impl: stream の delta から `SENTENCE_END = "。！？〜"` を検出 → N 文超過で `break`
4. persona prompt V3 (ε): 「**1〜2文だけで簡潔に答えてください。3文以上は厳禁です。**」 で trait 強調
5. 動作確認: 5-10 prompt × 数 trial で 3 文超過率を測定 (verify-persona-matrix.py を Phase 6 で構築する場合に活用)

詳細は [../phase6-poc/README.md](../phase6-poc/README.md) のサブタスク table 参照。

## chunker.py の今後の取扱

| 項目 | 取り扱い |
|---|---|
| 配置 | `phase4b-llm-stream-chunker/chunker.py` (lab 内 snapshot、現状維持) |
| 役割 | CLI 単体検証 (例: persona 単体テスト、独立した LLM 動作確認、verify-persona.py) |
| OLV からの呼び出し | **なし** (β 不採用、memory 二重管理を回避) |
| 将来の再評価 | δ 実装が upstream PR で OLV に取り込まれた場合、γ snapshot のさらなる整理候補 (Phase 7+) |

## 採用決定後のリスクと注意点

| リスク | 対処 |
|---|---|
| δ の `faster_first_response: True` との相性 (1 文目を comma 切り出しした直後に 2 文目で abort できないケース) | Phase 6 サブタスク 4 (動作確認) で実機計測、必要なら `faster_first_response: False` 併用 |
| stream early break で TTS が中断された場合の再生品質 | `synth_voicevox` は per-sentence 完結なので問題なし、再生 queue の最後 chunk が正常に閉じることを確認 |
| OLV upstream の v1.3+ で agent インタフェース変更があると δ patch が壊れる | `v1.2.1` tag pin は継続 (D1 採用時の方針)、upstream 追従は別判断 |
