---
name: data-model
description: |
  業務要件・API・既存制約を根拠に、論理データモデルを DBML で `docs/specs/data-model.dbml` へ新規作成または更新するときに使う。
  ERD として可視化できるテーブル / カラム / 主キー / 一意制約 / 外部キー / インデックス / 列挙型 / 注記までを対象とし、SQL マイグレーションの実装そのものや、実在しない列・制約の推測追加には使わない。
---

# データモデル作成スキル

## 目的

論理データモデルを、DBML として一貫した命名・制約・参照関係で表現する。
出力物は `docs/specs/data-model.dbml` であり、主要エンティティ、カラム定義、主キー、外部キー、一意制約、必要最小限のインデックス、列挙型、注記までを含む。

## 出力テンプレート

~~~dbml
Project <project_name> {
  database_type: "<postgres | mysql | mariadb | sqlserver | oracle>"
  Note: '''
  <対象システムまたはモデルの要約>
  '''
}

Enum <EnumName> {
  <VALUE_A>
  <VALUE_B>
}

Table <schema_name>.<table_name> {
  <column_name> <type> [pk, not null]
  <column_name> <type> [not null, unique]
  <column_name> <type> [ref: > <schema_name>.<parent_table>.<parent_column>]
  <column_name> timestamp [not null, note: 'UTC']
  <column_name> <enum_name>

  Note: '''
  <テーブル責務>
  '''

  Indexes {
    (<column_name>) [name: 'idx_<table_name>_<column_name>']
    (<column_a>, <column_b>) [name: 'uq_<table_name>_<column_a>_<column_b>', unique]
  }
}

Ref <ref_name>: <schema_name>.<child_table>.<child_column> > <schema_name>.<parent_table>.<parent_column>
~~~

### フォーマット規則

- **ファイル名**: `data-model.dbml`
- **場所**: `docs/specs/`
- **表現対象**: `Project` / `Enum` / `Table` / `Ref` / `Indexes` / `Note`
- **DBML方針**:
  - 列単位で表現できる参照は列定義の `[ref: > ...]` を優先する
  - 複合外部キーや列定義だけで読みづらい参照は `Ref` を使う
  - 物理実装依存の詳細は持ち込まない
- **命名**:
  - テーブル名 / カラム名 / 制約名 / インデックス名は既存規約を優先する
  - 未指定時は `snake_case`
  - 外部キー名は `fk_<child_table>_<parent_table>`、一意制約 / 一意インデックス名は `uq_<table_name>_<columns_name>`、通常インデックス名は `idx_<table_name>_<columns_name>` を推奨する
- **型**:
  - アプリケーション都合の曖昧な型名を創作しない
  - DB種別が未確定でも業務上必要な型は一般的なDBML型で表現する
  - 長さ・精度・scale が確定している場合のみ付与する
- **主キー / 一意制約**:
  - 主キーは必須
  - 業務上一意な識別子は `unique` または `Indexes { ..., unique }` で表現する
- **外部キー**:
  - 参照先の主キーまたは一意列を明示する
  - 多対多は中間テーブルで表現する
  - 参照列と被参照列の意味が確認できない場合は外部キーを創作しない
- **監査列**:
  - `created_at` / `updated_at` は根拠がある場合のみ追加する
  - `deleted_at` など論理削除列も根拠がある場合のみ追加する
- **正規化方針**:
  - まず 3NF を基本とする
  - 明示的な性能要件または既存制約がある場合に限り、非正規化を採用し `Note` で理由を残す
- **省略ルール**: `（任意）` 相当の要素は該当がない場合、項目ごと削除する
- **言語**: 日本語（識別子・型名・制約名は英語可）

## ワークフロー

### 新規作成

1. 入力から対象業務、主要エンティティ、識別子、属性、参照関係、列挙値、制約、検索条件を抽出する。
2. 類似ケースと標準を Web 検索で確認し、公式情報を優先して DBML 構文と整合性を確認する。
3. テーブル候補を整理し、主キー、必須列、一意列、外部キー候補を確定する。
4. 多対多は中間テーブルへ分解し、重複列や導出可能列を削る。
5. 必要な列挙型、インデックス、注記だけを追加する。
6. `Project`、`Enum`、`Table`、必要な `Ref` を記述し、DBML として読める形に整える。
7. KISS / DRY / YAGNI を満たすか、過剰な将来拡張列や未確認制約が混入していないかを確認する。
8. `docs/specs/data-model.dbml` として出力する。

### 既存ファイルへの追記

1. 既存 `data-model.dbml` を読み、既存テーブル、列、参照、命名規約、注記を把握する。
2. 追加要求を「新規テーブル追加」「既存テーブルへの列追加」「制約追加」「参照追加」に分解する。
3. 既存要素のリネームや並び替えは避け、最小差分で追記する。
4. 既存の主キー、外部キー、一意制約と矛盾しないことを確認する。
5. 参照先や列挙値が未確定な要素は追加せず、必要なら `Note` で未確定事項を補足する。
6. 更新後に、孤立テーブル、重複列、循環参照の妥当性、不要インデックスの有無を見直して出力する。

## チェックリスト

- [ ] ファイルが `docs/specs/data-model.dbml` に配置される
- [ ] `Project` / `Table` / `Enum` / `Ref` / `Indexes` の使い分けが過不足ない
- [ ] すべてのテーブルに主キーがある
- [ ] 外部キーの参照先が実在し、列の意味が一致している
- [ ] 多対多を中間テーブルで表現している
- [ ] 一意制約と通常インデックスを混同していない
- [ ] 未確認の列、制約、列挙値、監査列を創作していない
- [ ] 物理実装依存の詳細を書き込みすぎていない
- [ ] KISS / DRY / YAGNI を満たしている
- [ ] UTF-8（BOMなし）/ LF 前提で扱える内容になっている

## 入力形式

- 自然文: 「受注、受注明細、商品、顧客のデータモデルを DBML で作って。受注は明細を複数持つ」
- 箇条書き:
  - 対象業務 / サブドメイン
  - テーブル候補
  - 各テーブルの主キー
  - 属性一覧
  - 参照関係
  - 一意制約 / 検索条件
  - 列挙値
- 既存ファイル: `docs/specs/data-model.dbml`（更新指示つき）
- 補助根拠（任意）: FR / NFR / OpenAPI / UI仕様 / 既存DDL / ADR

## 出力

- **ファイル**: `data-model.dbml`
- **場所**: `docs/specs/`

## 使用例

### 例1: 新規作成

**入力**:
> 顧客、注文、注文明細、商品、在庫引当のデータモデルを DBML で作って。注文と商品は注文明細で多対多。注文番号は一意。注文ステータスは列挙型で管理したい。

**出力**: `docs/specs/data-model.dbml`

### 例2: 追記

**入力**:
> 既存の `docs/specs/data-model.dbml` に「配送」テーブルを追加して。注文と 1 対多。追跡番号は一意にして。

**出力**: 既存内容を保持しつつ `delivery` テーブル、注文への参照、一意制約を最小差分で追記した `docs/specs/data-model.dbml`
