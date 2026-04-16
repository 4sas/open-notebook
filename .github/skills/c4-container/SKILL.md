---
name: c4-container
description: |
  C4モデルのL2（Container Diagram）として、対象システム内の主要コンテナ（アプリ/サービス/データストア等）とその関係を C4-PlantUML で `docs/specs/c4/containers.puml` に新規作成・更新するときに使う。
  コンポーネント分解（L3）やクラス図（L4）を描く目的、または名称・実装が確定していない要素を無理に図へ入れる目的では使わない
---

# C4モデル Container（L2）作成スキル

## 目的

対象システムの **主要コンテナ（実行単位/データストア/外部依存）** を整理し、責務・技術要素・通信関係を俯瞰できる **Container Diagram** を `containers.puml` として出力する（PlantUMLとして文法成立まで）。

## [出力テンプレート](../../../docs/templates/c4-container.puml)

~~~puml
@startuml <diagram_id>
!include <C4/C4_Container>

' （任意）レイアウト
' LAYOUT_TOP_DOWN()
' LAYOUT_LEFT_RIGHT()

title <SystemName> - Container Diagram

' システム（L1で定義済みの名称を使用）
System(<system_id>, "<SystemName>", "<概要>")

' コンテナ（実在・確定しているもののみ）
Container(<container_id>, "<表示名>", "<技術/種別>", "<責務の要約>")
ContainerDb(<db_id>, "<表示名>", "<DB種別>", "<保持データ/用途>")

' 外部（L1で定義済みの外部要素を必要最小限で）
System_Ext(<ext_id>, "<外部名>", "<概要>")

' グルーピング（境界マクロは禁止。任意）
package "<group_name>" {
  ' Container(...)
}

' 関係（高レベルI/F。API詳細やクラス名は書かない）
Rel(<from_id>, <to_id>, "<関係（動詞句）>", "<プロトコル/方式（任意）>")

@enduml
~~~

### フォーマット規則

* **C4-PlantUML include**: `!include <C4/C4_Container>` のみ
* **Boundary禁止**: `System_Boundary` / `Container_Boundary` 等は禁止。グルーピングは `package {}` / `rectangle {}` のみ
* **マクロは1行**: `System/Container/ContainerDb/System_Ext/Rel` 等は引数途中で改行しない
* **命名禁止**: 入力から実在が確認できない名称（製品/サービス/コンポーネント名）を創作して追加しない
* **不明要素の扱い**:
  * 実装型名・製品名が不明なものは **Containerとして描かない**
  * 必要ならコメント（`' ...`）または `package` 名で「未確定領域」として示す（要素追加しない）
* **粒度**:
  * L2は「アプリ/サービス」「データストア」「外部システム」「メッセージング（キュー/トピック等）」の単位に留める
  * 画面/クラス/関数/テーブル詳細などL3/L4の内容は載せない
* **識別子（alias）**:
  * 重複禁止。英数字＋`_`で統一（例: `libdocset_web`, `libdocset_api`, `libdocset_db`）
  * 表示名は日本語可
* **言語**: 日本語（識別子ID・技術名・プロトコルは英語可）

## ワークフロー

### 新規作成

1. 入力（要件/設計メモ/既存L1 `system-context.puml`）から以下を抽出する

   * 対象システム名（L1と同一）
   * 主要コンテナ候補（実行単位/データストア/外部依存/メッセージング）
   * コンテナ間の関係（送受信/参照/保存/通知）
2. **実在性・確定性を検証**し、未確認の名称・不明な実装要素は採用しない（コメントに退避）。
3. 図の中心に `System(...)`、周辺に `Container(...)` / `ContainerDb(...)` / `System_Ext(...)` を配置する。
4. `Rel(...)` を「何が何をするか」が分かる動詞句で付与し、過剰に増やさない。
5. 必要な場合のみ `package {}` で「UI層/バックエンド/データ層/外部連携」等にグルーピングする。
6. PlantUMLとして文法成立（`@startuml`〜`@enduml`、括弧/カンマ、識別子重複なし）を自己チェックする。
7. `docs/specs/c4/containers/<diagram>.puml` として出力する。
8. レンダリングを実行して表示崩れを修正する。

### 既存ファイルへの追記

1. 既存 `containers.puml` を読み取り、既存要素の alias 重複を確認する。
2. 追加対象が「コンテナの追加」か「関係の追加/修正」かを切り分け、最小差分で反映する。
3. 既存の意味を壊すリネーム/大量再配置は避ける（必要なら新規diagramとして追加）。
4. 文法成立チェックを行い、壊れていれば修正してから出力する。
5. レンダリングを実行して表示崩れを修正する。

## チェックリスト

* [ ] `!include <C4/C4_Container>` のみを使用している
* [ ] Boundary系マクロを使っていない（`package/rectangle` のみ）
* [ ] 未確認の名称を新規に創作していない
* [ ] `System/Container/ContainerDb/System_Ext/Rel` がすべて1行記述
* [ ] L2に不要な詳細（クラス/関数/テーブル詳細/エンドポイント羅列）が入っていない
* [ ] alias が重複していない
* [ ] `containers.puml` が PlantUML として文法的に成立する

## 入力形式

* 自然文: 「<システム名>のC4 Container図を作って。主要サービスは〜、DBは〜、外部は〜」
* 箇条書き:
  * 対象システム名（L1と一致）
  * コンテナ一覧（名称/役割/技術）
  * データストア（名称/種別/用途）
  * 外部システム（名称/用途）
  * 関係（A→B: 何をする、方式）
* 既存 `system-context.puml` / `containers.puml`（更新指示つき）

## 出力

* ファイル: `containers.puml`
* 場所: `docs/specs/c4/`

## 使用例

### 例1: 新規作成

**入力**:

> LibDocSet の Container 図を作って。Web UI、API、DB、外部のメール配信サービスがある。関係も入れて。

**出力**: `docs/specs/c4/containers/libdocset.puml`

### 例2: 追記

**入力**:

> 既存の libdocset.puml に「全文検索用のインデックスストア」を追加して。APIが更新・検索する関係も。

**出力**: 既存内容を保持しつつ Container/Rel を追記した `docs/specs/c4/containers/libdocset.puml`
