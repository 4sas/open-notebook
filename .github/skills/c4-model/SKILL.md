---
name: c4-model
description: |
   C4モデル（L1〜L4）を一貫した規約・命名・更新方針で作成/更新する必要があるときに使う。
   複数スキル（c4-context / c4-container / c4-component / c4-code）が絡み、入力の不足・確定度に応じて分岐（スキップ/部分成功）や再試行（文法チェック起因）が必要なケースを想定。
   単一レベルだけを描きたい、またはC4以外（ERD/シーケンス等）が目的なら使わない
---

# C4モデル作成オーケストレーター

## 目的（Done定義）

* L1〜L4のうち、入力で確定している範囲のみを採用してC4図（PlantUML）を生成/更新できた
* 各図がPlantUMLとして文法成立し、禁則（Boundary禁止・未確認名称の創作禁止・マクロ1行等）を満たした
* 生成/更新先が規約のパスに配置され、既存更新では「最小差分」を守れた
* **成功**: L1〜L4の必要レベルがすべて生成/更新
  **部分成功**: 一部レベルは入力不足のためスキップし、生成できたレベルのみ出力
  **失敗**: いずれのレベルも文法成立せず、リカバリ規定回数を超えた

## 適用範囲

* 対象タスク: システムのC4モデル（Context/Container/Component/Code）を新規作成または既存へ追記・更新
* 非対象タスク（使うべきでない）:

  * C4以外の図（ERD、シーケンス、デプロイ等）が主目的
  * 1つの図だけを単発で作り、分岐/再試行が不要
  * 実在/確定していない要素を「推測」で埋めたい要求

## 入力

* 必須:

  * 対象システム名
  * 利用者（役割）と外部システム（名称が確定しているもの）の一覧（少なくともどちらか）
* 任意:

  * L2コンテナ候補（表示名/技術/責務）
  * L3対象コンテナとコンポーネント候補（表示名/技術/責務）
  * L4対象コンポーネント配下のクラス候補（属性/操作/関連、型不明は許容）
  * 既存puml（更新指示つき）
* 不足時の扱い:

  * **質問する**: 対象システム名が不明、または「図に入れる外部/人」がゼロでL1が成立しない
  * **仮定する**: レイアウト方針（TopDown/LeftRight）は未指定ならデフォルト不使用
  * **中断する**: 未確認名称を創作して補う必要がある場合（創作禁止のため）

## 状態モデル（State）

* state.system_name: string（最初に確定）
* state.targets.levels: {l1:boolean,l2:boolean,l3:boolean,l4:boolean}（入力確定度で決定）
* state.inputs.l1: {people:[], external_systems:[], rels:[]}（抽出結果）
* state.inputs.l2: {containers:[], dbs:[], external_refs:[], rels:[]}（抽出結果）
* state.inputs.l3: {target_container, components:[], component_dbs:[], rels:[]}（抽出結果）
* state.inputs.l4: {target_container, target_component, classes:[], rels:[]}（抽出結果）
* state.outputs.files: string[]（生成/更新したファイルパス）
* state.validation: {pass:boolean, errors:[]}（文法/禁則チェック結果）
* 不変条件（Invariants）:

  * 未確認の名称（人/システム/製品/コンポーネント/クラス）を新規に創作しない
  * Boundary系マクロを使わない（package/rectangleのみ）
  * 既存更新は最小差分（ID/aliasの不用意な変更禁止）

## 実行モデル（Control）

* 方式: 状態機械（レベルごとの段階実行 + 検証 + 失敗時リカバリ）
* 停止条件:

  * 対象レベルの生成/更新が完了し、全ファイルが検証合格
  * または部分成功として、生成できたレベルのみ合格して終了
* 再計画条件:

  * 入力不足で上位レベル（L1/L2）が成立しない
  * 下位レベルが上位のalias/名称に依存して不整合になった
* 分岐条件:

  * L2が未確定ならL3/L4はスキップ
  * L3対象コンテナ未確定ならL4はスキップ
* 並列化ポリシー:

  * 生成はレベル依存のため原則直列（L1→L2→L3→L4）
  * ただし複数L2/L3図の「追加作成」は同一レベル内で独立に扱う（実装側で並列化可）

## ツール/スキル契約（Contracts）

* c4-context:

  * 入力スキーマ: {system_name, people[], external_systems[], rels[], existing_file?}
  * 出力スキーマ: {file_path:"docs/specs/c4/system-context.puml", updated:boolean}
  * 前提: L1に必要な要素（PersonとSystemの関係）が最低1本は書ける
  * 失敗時: 1回だけ再生成（識別子重複/括弧崩れ等の機械的修正）。それでもダメなら中断
  * 冪等性: あり（同一入力なら同一出力を目標）

* c4-container:

  * 入力スキーマ: {system_name, containers[], dbs[], external_systems_refs[], rels[], existing_files?}
  * 出力スキーマ: {file_paths:["docs/specs/c4/containers/<diagram>.puml"...], updated:boolean}
  * 前提: 対象システム名がL1と一致、alias重複を避けられる
  * 失敗時: 1回だけ再生成（alias重複/Relの参照先欠落を修正）。それでもダメなら当該図のみスキップ
  * 冪等性: あり

* c4-component:

  * 入力スキーマ: {system_name, target_container, components[], component_dbs[], external_refs[], rels[], existing_files?}
  * 出力スキーマ: {file_path:"docs/specs/c4/components/<container_alias>/components.puml", updated:boolean}
  * 前提: target_containerがL2に存在（alias/名称が確定）
  * 失敗時: 1回だけ再生成（参照コンテナ/外部の不足をコメントへ退避）。それでもダメならスキップ
  * 冪等性: あり

* c4-code:

  * 入力スキーマ: {system_name, target_container, target_component, classes[], rels[], existing_files?, unknown_type_placeholder:"?"}
  * 出力スキーマ: {file_path:"docs/specs/c4/codes/<container_alias>/<component_alias>/<diagram>.puml", updated:boolean}
  * 前提: target_componentがL3に存在（alias/名称が確定）
  * 失敗時: 1回だけ再生成（型/引数不明を`?`/`(...)`へ正規化、関係線を最小化）。それでもダメならスキップ
  * 冪等性: あり

## エラー処理（Recovery）

* エラー分類:

  * 文法エラー（PlantUML構文、括弧/カンマ、未定義参照）
  * 規約違反（Boundary使用、マクロ改行、未確認名称の創作）
  * 整合性エラー（L2/L3 alias不一致、参照先不在）
* リトライ: 各レベル最大1回（機械的修正のみ）
* フォールバック:

  * 下位レベル（L3/L4）はスキップして部分成功に切り替え
  * 未確定要素は「コメントへ退避」（図要素として追加しない）
* ユーザー確認ポイント:

  * 対象システム名
  * 図に載せる外部システムの正式名称（確定していない場合は載せない）

## 生成物（任意）

* `docs/specs/c4/system-context.puml`
* `docs/specs/c4/containers.puml`
* `docs/specs/c4/components/<container_name>.puml`
* `docs/specs/c4/codes/<container_name>/<code_name>.puml`

## 出力テンプレート

```md
# C4モデル生成結果

## 生成/更新ファイル

- **L1(Context)**: <path or 省略>
- **L2(Container)**: <path(s) or 省略>
- **L3(Component)**: <path(s) or 省略>
- **L4(Code)**: <path(s) or 省略>

## スキップしたレベル（任意）

- **レベル**: <L2/L3/L4>
  - **理由**: <入力不足/依存不整合/検証失敗>
```

## ワークフロー

### 新規実行

1. 入力から対象システム名・関係者・外部システム・主要要素（コンテナ/コンポーネント/クラス）を抽出し、確定度で `state.targets.levels` を決める
2. L1を `c4-context` で生成し、文法/禁則チェック（失敗なら1回リトライ）
3. L2が必要なら `c4-container` を生成（複数図がある場合は図単位で処理）。失敗した図はスキップ可
4. L3が必要なら対象コンテナごとに `c4-component` を生成（対象コンテナ未確定ならスキップ）
5. L4が必要なら対象コンポーネントごとに `c4-code` を生成（型/引数不明は`?`/`(...)`で許容）
6. 生成/更新ファイル一覧と、スキップ理由（あれば）を出力テンプレートで返す

### 既存状態からの再開（重要）

1. 既存puml群を読み取り、alias/名称/既存関係を `state` に取り込む（リネーム禁止を前提に差分計画）
2. 追加要求を「新規要素追加」か「関係追加/文言修正」かに分類し、最小差分で各レベルへ適用
3. 依存する上位レベル（例: L3がL2 aliasに依存）に不整合が出る場合は、上位から順に再検証・必要最小限の修正
4. 文法/禁則チェックに通らないファイルのみを対象にリトライ（全体再生成は避ける）

## チェックリスト

* [ ] 完了条件を満たした
* [ ] 制約（創作禁止/Boundary禁止/最小差分）を満たした
* [ ] 検証に通った（PlantUML文法・参照整合性）
* [ ] 失敗時の代替経路（下位スキップ）が機能する

## 使用例

**入力**:

> 在庫管理システムのC4を作って。利用者: 店舗スタッフ/管理者。外部: 決済サービス。主要コンテナ: Web、API、DB。API内コンポーネント: 認証、在庫、注文。

**出力**: L1〜L3のpumlを生成し、L4はクラス情報が無いのでスキップ（理由つき）
