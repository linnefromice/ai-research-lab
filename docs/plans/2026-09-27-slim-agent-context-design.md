# 常時読み込みコンテキストの縮小（AGENTS.md 新設 + rules 整理）

参照した手順・判断基準: `private-research-hub` の
`notes/agent-context-slimming-playbook.md` / `notes/agent-context-file-policy.md`
（このリポの外にあるメモ。パス・skill 名など research-hub 固有の実装は持ち込まず、
「4 つの質問」「移動先の表」「200 行 / 20-80 行」の基準だけを適用する）。

## 使っているエージェント

このリポで実際に使われているのは **Claude Code のみ**。確認した内容:

- `AGENTS.md` / `opencode.json` / `.codex/` は存在しない
- `.claude/agents/`（サブエージェント）/ `.claude/skills/` は存在しない
- `.claude/settings.json` は存在しない（hooks / permissions なし）
- `scripts/`・`justfile`・各実験配下を `codex exec` / `claude -p` / `opencode run` 等で
  grep — リポ内から他エージェント CLI を起動している箇所はゼロ

→ 他ツール（opencode / Grok Build 等）や settings/hooks は対象外。Claude Code の
常時読み込み（CLAUDE.md + `paths` の無い rules）だけが対象。

## 現状（起動時に毎回読まれるもの）

| ファイル | 行数 | `paths` frontmatter |
|---|---|---|
| `CLAUDE.md` | 88 | — |
| `.claude/rules/lab-workflow.md` | 111 | なし → 常時読み込み |
| `.claude/rules/bash-best-practices.md` | 219 | なし → 常時読み込み |
| `.claude/rules/common/coding-style.md` | 48 | なし → 常時読み込み |
| **合計** | **466** | 目標 200 未満 |

`AGENTS.md` が無いため、Claude Code は `CLAUDE.md` を直接読む構成。

## prompt-audit（基準モデル: Claude Opus 5.5）

`/claude-api prompt-audit` の手順で対象 4 ファイルを監査。スコープはこの 4 ファイルのみ。
見つかった問題は「古い指示」というより **重複・矛盾・他リポの残滓** で、いずれも
Group 2（instruction file 側の劣化）に分類される。

| # | 所在 | パターン | 根拠 | 確信度 | 対応 |
|---|---|---|---|---|---|
| 1 | `.claude/rules/common/coding-style.md`（全 48 行）vs `CLAUDE.md:51-63`・`lab-workflow.md:8-12` | **指示ファイル間の矛盾** — coding-style.md は「常に包括的にエラー処理」「関数 50 行未満」等を絶対規範として要求。CLAUDE.md の行動原則は同じリポで「production 品質の error handling / test を要求しない」と明言し、真逆 | 両方が常時読み込みで同時にモデルに渡る。`git log` 上 coding-style.md は初期スキャフォールド (2026-04-28) からのコピーで一度も改訂されておらず、CLAUDE.md/lab-workflow.md はその後 (2026-09-18) に更新されている＝矛盾を書いた側が古い | **High** | `flag`＋提案（本設計書で承認を得てから適用）— 削除 or `paths` 縮小 + 「参考レベル」への書き換えの二択。ユーザー判断を仰ぐ（4 つの質問の「モデルが言われなくてもやることか」にも該当: 過剰な数値チェックリストは現行モデルには過剰仕様） |
| 2 | `bash-best-practices.md:168`「過去に `./manage.sh run tech-trends` が追加引数なしで即死した PR #133 事例」 | **他リポの残滓（History narratives）** — `manage.sh` はこのリポに存在しない（grep で確認）。pipeline 側の PR 番号・スクリプト名をそのままコピーしている | ai-research-lab には `manage.sh` が無い。ルール自体（空配列展開のトラップ）は `.sh` が 17 本あるこのリポでも有効だが、引用元は無関係 | **High** | `rewrite` — 教訓だけ残し、他リポの PR 番号 / スクリプト名を削除 |
| 3 | `bash-best-practices.md:218-219`「`shared/lib/enhance-goal-merge.sh` ... PR #164」 | 同上 | `shared/lib/` はこのリポに存在しない | **High** | `rewrite` — 同上（実例の固有パスを削除、教訓のみ残す） |
| 4 | `CLAUDE.md:75-84` と `lab-workflow.md:96-105` | **重複** — 「pipeline からの逸脱（適用しないこと）」がほぼ同一文面で 2 ファイルに存在し、両方常時読み込み | 内容は一致しており矛盾ではないが、常時読み込みの中で完全に同じ情報を二重に払っている | **High**（キープリストの原則8「機能している重複はcruftではない」は、常時読み込みコストの二重負担には当てはまらないため） | `move` — 1 箇所（新設 AGENTS.md）に統合、他方は削除 |
| 5 | `CLAUDE.md:28-43`（親リポへのアクセス表）と `docs/pipeline-reference.md:7-19`（パス対応表） | **重複** — ほぼ同一の表が 2 箇所にあり、`docs/pipeline-reference.md` 側の方が新しく詳細（weekly / session report 形式も含む） | 移動先（`docs/pipeline-reference.md`）は現行かつより網羅的なことを確認済み | **High** | `remove`（CLAUDE.md 側）+ 1 行のポインタに置換 |
| 6 | `CLAUDE.md:65-73`・`lab-workflow.md:28-57`・`docs/workflow.md:42-78`・`README.md:99-107` | **重複** — 「実験ディレクトリの作り方 + README テンプレ」が 4 箇所に存在（テンプレ本文はほぼ一字一句同じ） | `docs/workflow.md` が最も詳細で正本として妥当。他 3 箇所は縮約または削除できる | **High** | `move` — 詳細は `docs/workflow.md` に一本化。AGENTS.md には「実験 README 必須（起点/目的/実行方法/結果メモ）」の 1 行だけ残す（`paths` 付きルールは触る前の判断に間に合わないため、この 1 行だけは常時に残す） |
| 7 | `CLAUDE.md:45-49` と `lab-workflow.md:22-26` | **重複** — 「日次定例 vs 定型日次」がほぼ同一文面 | 同上 | **Medium** | `move` — 1 箇所に統合、2 行に圧縮 |
| 8 | `lab-workflow.md:87-94`（やっていい/やってはいけない表） | 行動原則・適用しないこと節と内容が重複する要約表 | 同じ事実を表形式で再掲しているだけ | **Medium** | `remove`（AGENTS.md に統合後は不要） |

監査対象 4 ファイルのうち Group 1（古いモデル向けの圧力言語・シンキング足場・過剰な逐語手順）に
該当する記述は見つからなかった（0 件）。見つかった問題はすべて Group 2（重複・矛盾・他リポの
残滓）。

## 仕分け表（4 つの質問を適用）

### CLAUDE.md

| 節 | 判定 | 移動先 |
|---|---|---|
| 冒頭説明 | 圧縮して AGENTS.md へ | — |
| ⚠️ Public 警告（秘密情報） | **残す**（破ると事故になる）→ AGENTS.md に一本化 | README.md の同節は人間向けとして残置 |
| 秘匿情報は private repo を提案 | 残す（要約） → AGENTS.md | 詳細は README.md 既存節 |
| 親リポへのアクセス（パス表） | 削る | `docs/pipeline-reference.md`（既存・現行） |
| 日次定例 vs 定型日次 | 圧縮して残す（2 行） → AGENTS.md | — |
| 行動原則（PoC の軽量方針） | **残す**（このリポの性格を決める中核） → AGENTS.md | coding-style.md との整合は上記 #1 で別途決定 |
| 新規実験を始めるとき | 削る（1 行の必須条件だけ AGENTS.md に残す） | `docs/workflow.md`（既存） |
| 適用しないこと / 守ること | 残す → AGENTS.md に一本化 | — |

### `.claude/rules/lab-workflow.md`

| 節 | 判定 | 理由 |
|---|---|---|
| 大原則 | 削除 | CLAUDE.md の行動原則と重複、AGENTS.md に統合 |
| 親リポは絶対に変更しない + 還元 PR の作法 | 圧縮して AGENTS.md へ移す（1-2 行） | 独自情報（還元 PR は別 PR、の一文）を保持 |
| 日次定例 | 削除（重複） | CLAUDE.md 側と統合 |
| 新規実験ディレクトリの最低条件 + README テンプレ | 削除 | `docs/workflow.md` に同一内容が既存 |
| ブランチ運用 | 圧縮して 1 行だけ AGENTS.md へ（PR 任意） | 「main 直 commit OK」は適用しないこと節と重複するので削れる |
| 秘密情報 | 削除（重複） | AGENTS.md に一本化 |
| やっていい/やってはいけない表 | 削除 | 他節と重複する要約 |
| 適用しないこと | 削除（重複） | AGENTS.md に一本化 |
| 流用しているルール（bash/coding-style の注記） | 削除 | coding-style.md 自体の扱いが変わるため不要に |

→ 残る固有情報がほぼ無いため、**ファイルごと削除**を提案（research-hub の
`development-workflow.md` 削除と同じ理由: 「AGENTS.md の進め方と重複」）。

### `.claude/rules/bash-best-practices.md`

| 判定 | 内容 |
|---|---|
| `paths` を追加して残す | `paths: ["**/*.sh"]`（このリポに `.sh` が 17 本あり、内容自体は現在も有効） |
| 修正 | #2, #3 の他リポ残滓（PR 番号・存在しないパス）を削除し、教訓だけ残す |

### `.claude/rules/common/coding-style.md`

矛盾（#1）があるため、実装フェーズ着手前に **ユーザーに選んでもらう**:

- **案 A（削除）**: このリポの行動原則（PoC・最小限の error handling）と矛盾するため、
  `.claude/rules/common/coding-style.md` ごと削除する
- **案 B（残すが縮小）**: `paths` を付けて必要な時だけ読ませ、冒頭を
  「PoC のため参考レベル。イミュータビリティ・小さい関数は理想だが強制しない」に書き換える

## 新しい構成

```text
起動時に読む（常時、目標 ~50-60 行）     必要なときだけ読む
──────────────────────────────      ─────────────────────────────────
CLAUDE.md（1 行: @AGENTS.md）          .claude/rules/bash-best-practices.md
 └ AGENTS.md（新設・40-70 行）           （paths: **/*.sh）
                                       .claude/rules/common/coding-style.md
                                        （案 B の場合。paths 付き）
                                       README.md / docs/workflow.md /
                                       docs/pipeline-reference.md
```

他ツール（opencode / Grok Build 等）は現状このリポで使われていないため、
「rules を全部読むツールにだけ厚めの内容が届く」という考慮は不要（research-hub と異なる点）。

## 実装ステップ（PR 分割）

- **PR 1（常時読み込みの縮小）**: `AGENTS.md` 新設、`CLAUDE.md` を `@AGENTS.md` 1 行に、
  `.claude/rules/lab-workflow.md` 削除、`README.md` のディレクトリ構成図を更新
- **PR 2（rules の再配置、PR 1 マージ後に main から切る）**: `bash-best-practices.md` に
  `paths` 追加 + 他リポ残滓の修正、`coding-style.md` は承認された案（A/B）を適用

どちらも self-review（参照切れの grep + `/context` で実際の読み込みを確認）まで行う。

## 確認事項（承認前にユーザーに決めてほしいこと）

1. **coding-style.md は案 A（削除）/ 案 B（`paths` 化して残す）のどちらにするか**
2. 設計書の置き場を `docs/plans/` としたが、他に慣習があればそちらに合わせる
3. PR を 2 本に分けるか、1 本にまとめるか（分けるなら PR 1 マージ後に PR 2 を着手）
