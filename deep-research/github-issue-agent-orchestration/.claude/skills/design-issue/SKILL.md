---
name: design-issue
description: "[2] design issue の本文に要件定義・詳細設計・調査結果を構造化して書き込む。重い推論工程。コードは変更しない。"
---

# design-issue スキル

## 概要

[2] 設計工程の本体。`type:design` issue の本文を DoD を満たす設計ドキュメントに
仕上げる。**コードは書かない**（実装は [3] の仕事）。

## 実行手順

入力: claim 済み（`status:in-progress`）の `type:design` issue `N`。

1. `issue-read` で [2] と親 [1] を把握する。
2. 必要なら `TARGET_REPO` のコードを Read / Grep / WebSearch で調査する。
3. 設計本文を作り、issue 本文を更新する（`gh issue edit <N> --body-file -`）。
   本文 DoD（protocol §7）:
   - **背景** — 何を・なぜ（親 [1] の要約）
   - **要件** — 満たすべき条件
   - **設計** — 方針・構成・データフロー・影響範囲
   - **調査ソース** — 参照した一次情報・コード位置（事実誤認を G3 で検証可能に）
   - **子 [3] のリスト** — 実装単位の見出し（起票は `breakdown-design` が行う）
4. 本文を更新したら呼び出し元へ「設計完了」を返す（`breakdown-design` に続く）。

## 注意

- このスキルの工程は `--allowedTools` から `Edit`/`Write` を外す前提（protocol /
  レポート §7-4）。設計はコードを変更しない。
- 設計方針の承認（G3）は人間。エージェントは `review` までしか進めない。
