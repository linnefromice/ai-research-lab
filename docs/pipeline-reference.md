# ai-research-pipeline 参照ガイド

このリポから親 repo のレポートを参照する際の早見表。

---

## パス対応表

| 種別 | パス |
|---|---|
| 国内 daily report | `../ai-research-pipeline/features/<feature>/reports/<YYYY-MM-DD>.md` |
| Global daily (EN) | `../ai-research-pipeline/features/<feature>-global/reports/<YYYY-MM-DD>.en.md` |
| Global daily (JA) | `../ai-research-pipeline/features/<feature>-global/reports/<YYYY-MM-DD>.ja.md` |
| Weekly report | `../ai-research-pipeline/features/<feature>/reports/<YYYY-MM-DD>.md` (Sunday 日付) |
| Session report | `../ai-research-pipeline/features/<feature>/reports/<YYYY-MM-DD>-<session>.md` |
| Deep research レポート | `../ai-research-pipeline/features/deep-research/reports/<topic>.md` |
| Deep research 中間 | `../ai-research-pipeline/features/deep-research/research/<topic>/` |
| Deep research goal | `../ai-research-pipeline/features/deep-research/goals/<topic>.md` |
| RSS sources 定義 | `../ai-research-pipeline/public-src/sources/<feature>/sources.json` |

## Feature 一覧 (2026-04 時点)

### 国内 daily (5 件 / 朝 cron)

- tech-trends, finance-markets, invest-japan, productivity, life-hacks

### Global daily (5 件 / EN・JA 各 1)

- tech-trends-global, wellness-global, parenting-global, family-finance-global, workstyle-global

### Weekly (5 件 / 毎週日曜 集約)

- wellness, parenting-baby, parenting-edu, family-finance, workstyle

### Session (平日のみ, 1 日 3 回)

- invest-japan: open / mid / close
- invest-global: open / mid / close

### Deep research

- on-demand。CLI / Telegram / admin UI から投入

最新の Feature 一覧は次で確認:

```bash
ls ../ai-research-pipeline/features/
```

## 公開サイト

実 URL は親 repo の `docs/guides/` 配下を参照。

| サイト | 用途 |
|---|---|
| Public site | レポート閲覧 (一般公開) |
| Admin site | 管理画面 (publish/unpublish, Deep Research 投入, ユーザー管理) |

## 親 repo を Read するときの注意

- 親 repo は production cron で頻繁に更新される (毎日 05:00 JST に run-all)
- 最新を見たい場合は `git -C ../ai-research-pipeline pull` (ただし dev branch があるなら触らない)
- レポート md には YAML frontmatter (`title`, `date`, `feature`, `engine` 等) が付いている
- 多言語 feature は `.en.md` と `.ja.md` がペアで存在する
- 作業中の deep-research は `published: false` の可能性あり (admin UI でのレビュー前)

## 親 repo の主要ドキュメント

実装を深く知りたいときは親 repo の以下を参照:

| パス | 内容 |
|---|---|
| `../ai-research-pipeline/CLAUDE.md` | パイプライン全体像 |
| `../ai-research-pipeline/docs/guides/glossary.md` | プロジェクト用語集 |
| `../ai-research-pipeline/docs/guides/deep-research-guide.md` | Deep Research の使い方 |
| `../ai-research-pipeline/docs/guides/onboarding.md` | 初回セットアップ |
| `../ai-research-pipeline/docs/adr/` | アーキテクチャ決定記録 |
