# Phase 6 サブタスク 0 — ベースライン測定 (A2 + D5)

`verify-persona-matrix.py` で persona V1 / V2 × 5 prompt × 5 trial = 50 LLM call を
実行し、**A2 (persona V2 効果定量)** + **Phase 6 D4 実装前ベースライン** を取得した。

## 起点

- **設計**: [../phase4b-llm-stream-chunker/README.md#次回検証計画--verify-personapy-多様化版-a2--d5](../phase4b-llm-stream-chunker/README.md#次回検証計画--verify-personapy-多様化版-a2--d5)
- **A2 = persona V2 仮説**: V1 の hard-code フレーズ「んー、あんまり詳しくないかも」を
  trait 指示に緩和した V2 で「定型語尾としての過学習」が消えるはず
- **D4 ベースライン**: [../phase5-live2d/D4-evaluation.md](../phase5-live2d/D4-evaluation.md)
  採用結果 = δ + ε + γ snapshot を実装する前の指標スナップショット

## 実行条件

| 項目 | 値 |
|---|---|
| script | `phase4b-llm-stream-chunker/verify-persona-matrix.py` |
| model | `llama-3.1-swallow-8b-instruct-v0.5` (LM Studio, port 1234) |
| temperature | 0.7 |
| persona | V1 (Phase 4b PR #4 NEW_SP) / V2 (Phase 5 投入版、hard-code 1 行緩和) |
| fewshot | **使用しない** (OLV `basic_memory_agent` に fewshot 機構が無いため) |
| prompt | anime / morning / weather / kids / greet (5 種類) |
| trial | 各 cell 5 回 |
| 実行 | 2026-04-30 15:56 〜 15:57、約 74 秒 |
| raw data | [results/baseline-20260430-155737-full.json](./results/baseline-20260430-155737-full.json) |
| 集計 md | [results/baseline-20260430-155737-full.md](./results/baseline-20260430-155737-full.md) |

## 結果サマリ

### V1 vs V2 比較表 (再掲)

| persona | prompt | n | 3 文超過 | 「あんまり詳しく」 | bullet | 1 文目 len 平均 | sanctioned 外 |
|---|---|---|---|---|---|---|---|
| V1 | anime   | 5 | 2/5 (40%) | 3/5 (60%) | 0/5 (0%) | 16.0 | 0/5 (0%) |
| V1 | greet   | 5 | 0/5 (0%)  | 1/5 (20%) | 0/5 (0%) | 13.6 | — |
| V1 | kids    | 5 | 0/5 (0%)  | 1/5 (20%) | 0/5 (0%) | 14.0 | — |
| V1 | morning | 5 | 0/5 (0%)  | 0/5 (0%)  | 0/5 (0%) | 9.4  | — |
| V1 | weather | 5 | 0/5 (0%)  | 4/5 (80%) | 0/5 (0%) | 13.0 | — |
| V2 | anime   | 5 | 1/5 (20%) | 0/5 (0%)  | 0/5 (0%) | 21.2 | 0/5 (0%) |
| V2 | greet   | 5 | 0/5 (0%)  | 0/5 (0%)  | 0/5 (0%) | 15.4 | — |
| V2 | kids    | 5 | 2/5 (40%) | 0/5 (0%)  | 1/5 (20%) | 20.4 | — |
| V2 | morning | 5 | 0/5 (0%)  | 0/5 (0%)  | 0/5 (0%) | 10.8 | — |
| V2 | weather | 5 | 0/5 (0%)  | 0/5 (0%)  | 0/5 (0%) | 14.2 | — |

### V1 vs V2 全体集計

| 指標 | V1 (n=25) | V2 (n=25) | Δ (V2 - V1) |
|---|---|---|---|
| 「あんまり詳しく」 出現率 | **9/25 (36%)** | **0/25 (0%)** | **−36 pt** ✅ |
| 3 文超過率 | 2/25 (8%) | 3/25 (12%) | +4 pt ⚠️ |
| markdown bullet list 出現率 | 0/25 (0%) | 1/25 (4%) | +4 pt |
| 1 文目 length 平均 | 13.2 chars | 16.4 chars | +3.2 chars |
| sanctioned 外作品 (anime のみ) | 0/5 (0%) | 0/5 (0%) | ±0 |

## 結論

### A2 = persona V2 効果 ✅ 完全実証

- **「あんまり詳しくない」 出現率: 36% → 0%**
- V1 の 9/25 = 36% は、Phase 5 副次発見観測 (2026-04-30 chat 11 ターン中 4 回 = 36%)
  と **偶然ながら完全に一致**。実環境で踏んだ過学習現象が matrix 上で同率で再現された
  = サンプリング数 5 trial × 5 prompt が観測信頼性を持っていた裏付け
- V2 では **全 25 trial で hard-code フレーズが 1 度も出現しない**。
  「定型語尾としての過学習」は SP 1 行 (hard-code → trait 指示) で完全に潰せる
- 副作用としての sanctioned 外 confabulation 増加 **なし** (V1/V2 共に 0/5)

### D4 残課題 ⚠️ — V2 でも 3 文制約は 12% 破られる

- V2 全体の 3 文超過率 = **3/25 (12%)** は persona V2 単独では押さえきれない残課題
- 特に **kids prompt で 40%** (相談・長文化リスクの典型) と **anime prompt で 20%** (作品紹介の列挙化)
- これは D4 評価書 候補 ε (persona 強化のみ) の限界と整合 = **構造的解決 (δ: OLV agent
  cap 機構) が必要**

### 副作用 — V2 で長文化傾向

- V2 の 1 文目 length 平均は V1 より +3.2 chars 長い
- 全 25 trial で見ると 1 文目が 20 chars 超になる cell (anime / kids) が登場
- 解釈: hard-code フレーズ (短文の「あんまり詳しくない」) が消えて、その分の文字数枠が
  説明文に回った結果。V2 で 3 文超過が増えた件 (+4 pt) はこの長文化と同根
- **D4 (δ: cap 機構 + ε: persona V3 で「3 文厳禁」 強調)** で解決狙う

### bullet list は依然 marginal

- V2 で 1/25 = 4% (V2/kids/3 で `*   **絵...`)
- V1 は 0/25 だが、kids で短文化していた = 試行する余地が無かったとも読める
- D4 cap=2 は副次的に bullet list 展開も abort する見込み

## Phase 6 D4 実装後の検証 (= サブタスク 4) で見る指標

D4 実装 (δ: OLV agent N 文 cap + ε: persona V3) 後に **同じ matrix script を再実行**
し、V3 cell のみ追加 で以下の改善を確認する:

| 指標 | V2 ベースライン | V3 (D4 後) 目標 | 評価方法 |
|---|---|---|---|
| 3 文超過率 (全体) | 12% | **0%** (cap=2 で構造的に保証) | 同 matrix の V3 行 |
| 「あんまり詳しく」 出現率 | 0% | 0% (regression なし) | 同 |
| 1 文目 length 平均 | 16.4 chars | 維持 〜 微増 (cap で 2 文目以降が消えるため、各文の質に変化なし想定) | 同 |
| markdown bullet list | 4% | 0% | 同 |
| sanctioned 外作品 | 0% | 0% (regression なし) | 同 |

**注意**: D4 実装が `chat_with_memory` の stream early break に介入するため、cell ごとの
latency は構造的に短縮される見込み。latency 比較は副次指標として記録 (本 baseline でも
JSON 内 `latency_ms` 保持済み)。

## raw data 追記 (V1 で観察された具体例)

V1 anime での「あんまり詳しくないかも」 過学習の実例 (3/5 trial で出現):

> **V1/anime/2**: んー、あんまり詳しくないかも。日常系が好きで、特に『ゆるキャン△』はキャンプの雰囲気が素敵だと思っています。あとは『のん…
>
> **V1/anime/4**: んー、あんまり詳しくないかも。日常系のアニメが好きで、『ゆるキャン△』とか『のんのんびより』とか見てます。あ、でも『けい…
>
> **V1/anime/5**: んー、あんまり詳しくないかも。日常系が好きで、たまに『ゆるキャン△』とか見てます。あと、『のんのんびより』も好きですね。

「好きなアニメ教えて」 と聞かれて *直後に* 「あんまり詳しくない」 を付ける = SP の
「知らないことは『あんまり詳しくない』 と言う」 ルールを **無関係なターン頭でも発火**
させている。これが過学習。V2 では 5 trial 全てで自然に作品名から入る応答に変わった。

## 次のアクション

- ✅ サブタスク 0 完了
- → Phase 6 サブタスク 1: D6-D8 確定 (`phase6-poc/README.md` に「Phase 6 決断」 節を追記)
- → サブタスク 2-3: D4 実装 (δ + ε)
- → サブタスク 4: 本 matrix の **V3 cell 追加実行 + 改善定量化**
