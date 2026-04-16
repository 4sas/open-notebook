---
name: c4-code
description: |
  C4モデルのL4（Code）として、特定コンポーネントに紐づくクラス構造（クラス/属性/操作/関連）を PlantUML（C4-PlantUML準拠のinclude制約つき）で `docs/specs/c4/codes/<container_name>/<code_name>.puml` に新規作成・更新するときに使う。
  L2/L3の粒度で十分な場合、または実在しないクラス名・型名を推測して図に起こす目的では使わない。
---

# C4モデル Code（L4: クラス図）作成スキル

## 目的

特定コンポーネント（L3）配下のコード構造を、クラス図（クラス/属性/操作/関連）として可視化する。
出力物は PlantUML として文法成立する `codes/<container_name>/<code_name>.puml`（C4-PlantUMLのinclude規約・禁則を満たす）まで。

## [出力テンプレート](../../../docs/templates/c4-code.puml)

~~~puml
@startuml <diagram_id>
!include <C4/C4_Component>

title <SystemName> - <ContainerName> - <ComponentName> - Code（Class Diagram）

' 対象コンテナ/コンポーネント（L2/L3で定義済みの名称/alias を使用）
Container(<container_id>, "<ContainerName>", "<技術/種別>", "<責務の要約>")
Component(<component_id>, "<ComponentName>", "<技術/種別>", "<責務の要約>")

' グルーピング（境界マクロは禁止。任意）
package "<namespace_or_module>" {

  class <ClassName> {
    <visibility><field_name> : <type_or_?>
    <visibility><method_name>(<args_or_...>) : <return_type_or_?>
  }

  interface <InterfaceName> {
    <visibility><method_name>(<args_or_...>) : <return_type_or_?>
  }
}

' 関係（必要最小限）
' 継承/実装
<ClassA> --|> <ClassB>
<ClassImpl> ..|> <Interface>

' 参照/集約/合成（任意）
<ClassA> --> <ClassB>
<ClassA> o-- <ClassB>
<ClassA> *-- <ClassB>

@enduml
~~~

### フォーマット規則

* **C4-PlantUML include**: `!include <C4/C4_Component>` のみ（他includeと混在させない）
* **Boundary禁止**: `Container_Boundary` / `System_Boundary` 等は禁止。グルーピングは `package {}` / `rectangle {}` のみ
* **マクロは1行**: `Container(...)` / `Component(...)` は引数途中で改行しない
* **命名禁止**: 入力から実在が確認できないクラス名/型名/モジュール名を創作して追加しない
* **不明要素の扱い**:
  * 実装型名が不明で、名前も確認できない場合は **図に含めない**
  * **変数名/関数名が確認できるが型が不明**: 型を `?` とする（例: `m_NTList : ?`）
  * **引数詳細が不明**: `(...)` を許容（例: `set_form(...)`）
* **可視性（推奨）**: `+` public / `-` private / `#` protected / `~` package（不明なら省略可）
* **粒度**:
  * L4は「クラス/インターフェース/主要なデータ構造」とその関連に限定
  * エンドポイント羅列、SQL詳細、処理フロー（シーケンス）などは載せない
* **省略ルール**: `（任意）` セクションは該当がない場合、項目ごと削除
* **言語**: 日本語（識別子・型・シグネチャは英語可）

## ワークフロー

### 新規作成

1. 入力（既存の `components/<container_name>.puml`、設計メモ、コード断片）から対象の **コンテナalias/コンポーネントalias** を確定する。
2. 対象コンポーネントに属する **実在クラス/インターフェース**、属性、操作、関連（継承/参照）を抽出する。
3. **未確認の名称は採用しない**。型が不明でも名前が確認できるもののみ `?` / `(...)` で表現する。
4. `Container(...)` と `Component(...)` を先頭に置き、`package` 配下にクラス定義を配置する（任意）。
5. 関係線は「設計意図が変わる最小限」に絞る（多すぎる関連は省く）。
6. PlantUMLとして文法成立（`@startuml`〜`@enduml`、識別子重複、括弧・波括弧整合）を自己チェックする。
7. `docs/specs/c4/codes/<container_alias>/<component_alias>/<diagram>.puml` として出力する。
8. レンダリングを実行して表示崩れを修正する。

### 既存ファイルへの追記

1. 既存 `codes/<container_name>/<code_name>.puml` を読み取り、既存クラス/関係の **名称・構造を保持** する。
2. 追加対象（クラス追加/属性追加/操作追加/関係追加）を最小差分で反映する。
3. 既存要素のリネームや大量再配置は避ける（必要なら新規diagramとして追加）。
4. 文法成立チェックを行い、壊れていれば修正してから出力する。
5. レンダリングを実行して表示崩れを修正する。

## チェックリスト

* [ ] `!include <C4/C4_Component>` のみを使用している（混在なし）
* [ ] Boundary系マクロを使っていない（`package/rectangle` のみ）
* [ ] 未確認のクラス名/型名を創作していない
* [ ] 型不明は `?`、引数不明は `(...)` で統一している
* [ ] 関係線が過剰でなく、意図が読める最小限になっている
* [ ] `codes/<container_name>/<code_name>.puml` が PlantUML として文法的に成立する
* [ ] ファイルが UTF-8（BOMなし）/ LF 前提で扱える内容になっている

## 入力形式

* 自然文: 「<コンポーネント名>のC4 Code（クラス図）を作って。対象は<範囲>」
* 箇条書き:
  * 対象コンテナ/コンポーネント（L3のalias/名称）
  * クラス一覧（分かる範囲で属性/操作/関連）
  * 不明点（型不明、引数不明の箇所）
* 既存ファイル: `components/<container_name>.puml` / `codes/<container_name>/<component_name>.puml`（更新指示つき）
* コード断片（任意）: クラス/メソッド定義、フィールド名が確認できるもの

## 出力

* ファイル: `<component_name>.puml`
* 場所: `docs/specs/c4/codes/<container_name>/`

## 使用例

### 例1: 新規作成

**入力**:

> LibDocSet の `components/libdocset/components.puml` にある Search コンポーネントに対応するクラス図を作って。型が不明なフィールドは `?` にして。

**出力**: `docs/specs/c4/codes/libdocset/libdocset_api_search/search_code.puml`

### 例2: 追記

**入力**:

> 既存の `.../search_code.puml` に `IndexWriter` クラスと `SearchService` からの参照関係を追加して。メソッド引数の詳細は不明。

**出力**: 既存内容を保持しつつ `IndexWriter` と `(...)` のメソッド、関連線を最小差分で追記した `search_code.puml`
