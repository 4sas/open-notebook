---
name: c4-context
description: |
   C4モデルの最上位（L1）の「System Context 図」を、C4-PlantUMLで `system-context.puml` として新規作成・更新するときに使う。
   コンテナ/コンポーネント/クラス構造など詳細設計を描く目的では使わない
---

# C4モデル Context（System Context）作成スキル

## 目的

対象システムを中心に、利用者（Person）と外部システム（System_Ext）との関係を整理した **System Context 図** を作成する。
出力物は C4-PlantUML の `system-context.puml`（PlantUMLとして文法成立）まで。

## [出力テンプレート](../../../docs/templates/c4-context.puml)

~~~puml
@startuml
!include <C4/C4_Context>

title System Context diagram for <SystemName>

' optional: layout
' left to right direction

' People
Person(<personId>, "<人物/役割名>", "<目的/関与>")

' System (the one in scope)
System(<systemId>, "<対象システム名>", "<要約（何を提供するか）>")

' External systems (only if confirmed)
System_Ext(<extSystemId>, "<外部システム名>", "<要約（何を提供するか）>")

' Grouping (when useful; do NOT use *_Boundary macros)
package "<グループ名>" {
  Person(<personId2>, "<人物/役割名>", "<目的/関与>")
  System_Ext(<extSystemId2>, "<外部システム名>", "<要約>")
}

' Relationships (high-level, technology-agnostic)
Rel(<personId>, <systemId>, "<やり取り（動詞句）>", "<任意: チャネル/プロトコル>")
Rel(<systemId>, <extSystemId>, "<やり取り（動詞句）>", "<任意: チャネル/プロトコル>")

@enduml
~~~

### フォーマット規則

* **C4-PlantUML include**: `!include <C4/C4_Context>` のみ
* **Boundary禁止**: `System_Boundary` / `Container_Boundary` 等の境界マクロは禁止。グルーピングは `package {}` / `rectangle {}` のみ
* **マクロは1行**: `Person(...)` / `System(...)` / `System_Ext(...)` / `Rel(...)` は引数途中で改行しない
* **命名禁止**: 入力から実在が確認できない名前（人/システム/製品/サービス）を創作して追加しない
* **不明要素の扱い**:
  * 実装技術や内部構造は **Context では描かない**
  * 必要なら `package` 名やコメント（`' ...`）で補足する（要素として追加しない）
* **関係の粒度**: 高レベル（利用/参照/通知/連携）に留め、API詳細やDB名などは載せない
* **言語**: 日本語（識別子IDは英数字推奨）

## ワークフロー

### 新規作成

1. 入力から「対象システム名」「利用者（人/役割）」「外部システム」「相互作用（関係）」を抽出する。
2. **名前の実在性** を確認できる要素のみ採用し、未確認要素は図に入れずコメントに退避する。
3. 対象システムを `System(...)` として中央概念に置き、利用者を `Person(...)`、外部を `System_Ext(...)` で配置する。
4. `Rel(...)` を高レベル動詞句で付与する（過剰に増やさない）。
5. `package {}` で「組織」「利用者群」「外部サービス群」などの任意グルーピングを行う（任意）。
6. PlantUMLとして文法成立（`@startuml`〜`@enduml`、括弧・カンマ、識別子重複なし）を自己チェックする。
7. `docs/specs/c4/system-context.puml` として出力する。
8. レンダリングを実行して表示崩れを修正する。

### 既存ファイルへの追記

1. 既存 `system-context.puml` を読み取り、既存要素（Person/System/System_Ext）とID重複を確認する。
2. 追加要素は **既存IDを変更せず**、新規IDで追記する（既存の意味を壊さない）。
3. 既存 `Rel` の意味が変わる場合は、関係文言のみ最小差分で更新し、不要な再配置や大量改変は避ける。
4. 文法成立チェックを行い、壊れていれば修正してから出力する。
5. レンダリングを実行して表示崩れを修正する。

## チェックリスト

* [ ] `!include <C4/C4_Context>` のみを使用している
* [ ] Boundary系マクロを使っていない（`package/rectangle` のみ）
* [ ] 未確認の名称を新規に創作していない
* [ ] `Person/System/System_Ext/Rel` がすべて1行記述になっている
* [ ] Contextに不要な詳細（技術・内部構造）を書いていない
* [ ] `system-context.puml` が PlantUML として文法的に成立する

## 入力形式

* 自然文: 「XXシステムのC4 Contextを作って。利用者は〜、外部連携は〜」
* 箇条書き:
  * 対象システム名
  * 利用者（役割/人物）
  * 外部システム（名称が確定しているもの）
  * 関係（誰が何をする/どこへ送る）
* 既存 `system-context.puml`（更新/追記指示つき）

## 出力

* ファイル: `system-context.puml`
* 場所: `docs/specs/c4/`

## 使用例

### 例1: 新規作成

**入力**:

> LibDocSet の System Context 図を作って。利用者は「一般ユーザー」「運用担当」。外部は「メール配信サービス」。関係も入れて。

**出力**: `docs/specs/c4/system-context.puml`（Person 2件、System 1件、System_Ext 1件、Rel を含む）

### 例2: 追記

**入力**:

> 既存の system-context.puml に「社内監査担当（閲覧のみ）」を追加して。対象システムとの関係も。

**出力**: 既存内容を保持しつつ Person と Rel を追記した `system-context.puml`
