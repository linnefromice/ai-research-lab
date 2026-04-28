# lab ワークフロールール

ai-research-lab での作業ルール。pipeline の重い production ルールではなく、
PoC / 実験向けの軽量な指針。

---

## 大原則

1. **動くものを最速で**。production 品質の error handling / test / docs は不要
2. **起点を必ず残す**。どのレポートのどの段落を試したかを実験 README に書く
3. **捨てる前提**。3 ヶ月後に「これ何だっけ」となる実験は消して良い

## 親リポは絶対に勝手に変更しない

`../ai-research-pipeline/` は別 repo の production code。このリポからの作業で
変更してはいけない。Read は OK。

検証で得た知見を pipeline 側に還元したい場合は、ユーザーに伝えた上で別途 PR を
切る (このリポからの作業ではない)。

## 新規実験ディレクトリの最低条件

- ディレクトリ名は短く具体的な slug
- 配下に `README.md` を必ず置く
- README には次の節を入れる:
  - **起点** — 起点レポートへの相対パスリンク + 該当節の引用
  - **目的** — 1-2 文
  - **実行方法** — 再現可能なコマンド
  - **結果メモ** — 得られた知見 (実験完了後に追記)

### 実験 README テンプレ

````markdown
# <slug>

## 起点
- レポート: `../../../../ai-research-pipeline/features/<feature>/reports/<date>.md`
- 該当節: 「<節タイトル>」

## 目的
<1-2 文>

## 実行方法
```bash
<command>
```

## 結果メモ
- <得られた知見>
````

## ブランチ運用

- main 直 commit OK (実験リポなので)
- 複数の独立した実験を並行で進めるなら branch を切ると整理しやすい
- PR は任意 (pipeline と違うところ)

## 秘密情報

- API key, token は `.env` (gitignored) に置く
- `.env.example` でキー名だけ共有
- うっかり commit してしまった場合は **即ローテート** + git history からの除去を検討

## やっていいこと / やってはいけないこと

| ✅ やっていい | ❌ やってはいけない |
|---|---|
| 汚いコード / 1 ファイル script | 秘密情報の commit |
| 未完成の実験を残す | 親リポ (`../ai-research-pipeline/`) の改変 |
| `// TODO: あとで` コメント | 実験 README の省略 |
| 個人メモ・走り書き | 起点不明の実験追加 |

## 適用しないこと (pipeline からの逸脱)

pipeline 側で必須のルールで、ここでは適用しない:

- TDD / 80% カバレッジ
- 設計書ファースト
- main 直接禁止 / PR 必須
- code-reviewer エージェント必須
- 非自明な機能追加の事前設計

## 流用しているルール

`.claude/rules/` 配下の以下は pipeline からのコピー (変えていない):

- `bash-best-practices.md` — シェルスクリプトを書くなら必読
- `common/coding-style.md` — 一般的な品質指針 (PoC でも参考レベルで)
