---
name: c4-component
description: |
  C4モデルのL3（Component Diagram）として、特定コンテナ内部の主要コンポーネントと関係を C4-PlantUML で `docs/specs/c4/components/<container_name>.puml` に新規作成・更新するときに使う。
  L2（Container）の粒度で十分な場合、または実在/実装が確定していない要素を無理に図へ入れる目的では使わない
---

# C4モデル Component（L3）作成スキル

## 目的

対象コンテナを **主要コンポーネント（責務単位のまとまり）** に分解し、責務・技術要素・依存関係・外部I/Fを俯瞰できる **Component Diagram** を `components/<container_name>.puml` として出力する（PlantUMLとして文法成立まで）。

## [出力テンプレート](../../../docs/templates/c4-component.puml)

~~~puml
@startuml <diagram_id>
!include <C4/C4_Component>

' （任意）レイアウト
' LAYOUT_TOP_DOWN()
' LAYOUT_LEFT_RIGHT()

title <SystemName> - <ContainerName> - Component Diagram

' 対象コンテナ（L2で定義済みの名称/alias を使用）
Container(<container_id>, "<ContainerName>", "<技術/種別>", "<責務の要約>")

' コンポーネント（実在・確定しているもののみ）
Component(<component_id>, "<表示名>", "<技術/種別>", "<責務の要約>")
ComponentDb(<component_db_id>, "<表示名>", "<DB種別>", "<保持データ/用途>")

' 依存（L2の他コンテナ/外部要素を必要最小限で）
Container(<other_container_id>, "<表示名>", "<技術/種別>", "<責務の要約>")
System_Ext(<ext_id>, "<外部名>", "<概要>")

' グルーピング（境界マクロは禁止。任意）
package "<group_name>" {
  ' Component(...)
}

' 関係（高レベルI/F。クラス名やエンドポイント羅列は書かない）
Rel(<from_id>, <to_id>, "<関係（動詞句）>", "<プロトコル/方式（任意）>")

@enduml
~~~

### フォーマット規則

- **C4-PlantUML include**: `!include <C4/C4_Component>` のみ
- **Boundary禁止**: `Container_Boundary` / `System_Boundary` 等は禁止。グルーピングは `package {}` / `rectangle {}` のみ
- **マクロは1行**: `Container/Component/ComponentDb/ContainerDb/System_Ext/Rel` 等は引数途中で改行しない
- **命名禁止**: 入力から実在が確認できない名称（製品/サービス/コンポーネント名）を創作して追加しない
- **不明要素の扱い**:
  - 実装型名・製品名が不明なものは **Componentとして描かない**
  - 必要ならコメント（`' ...`）または `package` 名で「未確定領域」として示す（要素追加しない）
- **粒度**:
  - L3は「責務が明確なモジュール/サービス境界（凝集したコードの塊）」として描く
  - 画面/関数/クラス/テーブル詳細などL4相当の情報は載せない
- **識別子（alias）**:
  - 重複禁止。英数字＋`_`で統一
  - 推奨: `<container_alias>_<component_slug>`（例: `libdocset_api_search`, `libdocset_api_authz`）
- **省略ルール**: `（任意）` コメント行は必要な場合のみ残し、不要なら行ごと削除
- **言語**: 日本語（識別子ID・技術名・プロトコルは英語可）

## ワークフロー

### 新規作成

1. 入力（要件/設計メモ/既存L2 `containers.puml`）から以下を抽出する
   - 対象コンテナ（分解対象）
   - コンポーネント候補（責務、入出力、依存先）
   - コンポーネント間/外部との関係（参照/保存/通知/呼び出し）
2. **実在性・確定性を検証**し、未確認の名称・不明な実装要素は採用しない（コメントに退避）。
3. 図に `Container(...)` を置き、内部要素として `Component(...)` / `ComponentDb(...)` を配置する。
4. 依存先（同一システム内の他コンテナ、外部システム）は **必要最小限** を再掲し、`Rel(...)` で接続する。
5. `Rel(...)` は「何が何をするか」が分かる動詞句で付与し、過剰に増やさない。
6. 必要な場合のみ `package {}` で「API層/ドメイン/永続化/外部連携」等にグルーピングする。
7. PlantUMLとして文法成立（`@startuml`〜`@enduml`、括弧/カンマ、識別子重複なし）を自己チェックする。
8. `docs/specs/c4/components/<container_alias>/components.puml` として出力する。
9. レンダリングを実行して表示崩れを修正する。

### 既存ファイルへの追記

1. 既存 `components/<container_name>.puml` を読み取り、既存要素の alias 重複を確認する。
2. 追加対象が「コンポーネント追加」か「関係追加/修正」かを切り分け、最小差分で反映する。
3. 既存の意味を壊すリネーム/大量再配置は避ける（必要なら新規diagramとして追加）。
4. 文法成立チェックを行い、壊れていれば修正してから出力する。
5. レンダリングを実行して表示崩れを修正する。

## チェックリスト

- [ ] `!include <C4/C4_Component>` のみを使用している
- [ ] Boundary系マクロを使っていない（`package/rectangle` のみ）
- [ ] 未確認の名称を新規に創作していない
- [ ] `Container/Component/ComponentDb/System_Ext/Rel` がすべて1行記述
- [ ] L3に不要な詳細（クラス/関数/テーブル/エンドポイント羅列）が入っていない
- [ ] alias が重複していない
- [ ] `components/<container_name>.puml` が PlantUML として文法的に成立する

## 入力形式

- 自然文: 「<システム名>の <コンテナ名> のC4 Component図を作って。主要モジュールは〜、外部は〜」
- 箇条書き:
  - 対象コンテナ（L2のどれを分解するか）
  - コンポーネント一覧（名称/責務/技術）
  - データストア（名称/種別/用途）
  - 依存先（他コンテナ/外部）
  - 関係（A→B: 何をする/何を渡す）

## 出力

- ファイル: `<container_name>.puml`
- 場所: `docs/specs/c4/components/`

## 使用例

### 例1: 新規作成

**入力**:
> LibDocSet の「APIコンテナ」を分解したC4 Component図を作って。検索、認証、ドキュメント管理の主要コンポーネントと、DB/外部サービスとの関係も入れて。

**出力**: `docs/specs/c4/components/libdocset_api/components.puml`

### 例2: 追記

**入力**:
> 既存の `docs/specs/c4/components/libdocset_api/components.puml` に「監査ログ」コンポーネントを追加して。DBへの保存関係も。

**出力**: 既存内容を保持しつつ Component と Rel を追記した `components.puml`
