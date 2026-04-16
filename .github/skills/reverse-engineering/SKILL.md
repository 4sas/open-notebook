---
name: reverse-engineering
description: |
  既存のソースコードと既存ドキュメント断片を根拠に、`docs/` 配下の成果物を逆算生成・更新するオーケストレータースキル。
  複数スキル/ツールを束ね、対象判定、依存順制御、差分更新、再試行、部分成功への切り替えが必要な場合に使う。
  単一ファイルだけを単発生成する単純タスク、実装変更そのもの、根拠なしの新機能提案、`docs/` 以外の成果物生成には使わない。
---

# 既存コードから docs/ を逆算生成するオーケストレータースキル

## 目的（Done定義）

- 既存のソースコード、設定、API定義、テスト、既存 `docs/` を調査し、根拠のある `docs/` 成果物だけを生成/更新する。
- 生成対象は `README.md` に定義された SSOT 配置に従い、`docs/` 配下へ配置する。
- 参照・関連付けは原則として ID を主キーとし、`FR → AC → TC` の関係、および `OpenAPI x-ids`、`RUN Refs` などの接続を維持する。
- セットアップ、デプロイ、ロールバック、障害対応、定常運用の手順がコード・設定・スクリプト・CI から根拠を持って復元できる場合は `docs/runbooks/` も生成/更新する。
- 成功: 必要な `docs/` 成果物が生成/更新され、整合性チェックで重大不整合がない状態で完了する。
- 部分成功: 一部の成果物は根拠不足・対象不明・下位依存不足で生成を見送るが、生成済み成果物と未対応理由を明示して完了する。
- 失敗: 必須入力が欠落し、妥当な仮定でもトレーサブルな `docs/` 成果物を1つも作れない場合に限る。
- 最終成果物は、生成/更新ファイル一覧、スキップ理由、整合性検証結果を含む実行結果レポートとする。

## 適用範囲

- 対象タスク: 既存コードベースを調査し、`docs/glossary.md`、`docs/requirements/**`、`docs/specs/**`、`docs/testing/**`、`docs/adr/**`、`docs/runbooks/**` を新規作成または更新する作業。
- 非対象タスク（使うべきでない）:
  - 実装コードの新規開発・修正そのもの
  - 根拠がない仕様の創作
  - 単一スキルで完結する単純な文書生成
  - `docs/` 以外の成果物を主目的とする作業

## 入力

- 必須:
  - リポジトリルートまたは調査対象パス
  - 既存ソースコード一式
- 任意:
  - 既存 `docs/` 一式
  - 生成対象スコープ（例: `requirements only`, `openapi + c4 only`, `runbooks only`）
  - 除外パス/除外パターン
  - 既存 ID 規約や命名規約の補足
  - 更新モード（新規優先 / 既存追記優先）
- 不足時の扱い: リポジトリルートまたはソースコードが無い場合は中断する。生成対象スコープが無ければ、コードから観測できる成果物だけを最小集合で仮定して進める。

## 状態モデル（State）

- state.repo_root: 調査対象ルートパス（string）
- state.scope: 生成対象スコープ（object）
- state.evidence: 根拠断片の収集結果（object）
- state.doc_plan: 生成対象ファイルと依存順を表す計画（array）
- state.ids: 既存ID・採番状況・未接続ID（object）
- state.generated: 生成/更新済みファイル一覧（array）
- state.skipped: スキップした成果物と理由（array）
- state.validation: 整合性検証結果（object）
- 不変条件（Invariants）:
  - 根拠のない要件・外部システム名・画面・API・運用手順を創作しない
  - 既存ファイル更新時は明示対象以外を不必要に変更しない
  - state には秘密情報そのものを保存せず、必要最小限の要約だけを保持する
  - 参照はタイトルではなく ID を優先する

## 実行モデル（Control）

- 方式: Plan-and-Execute + 状態機械
- 停止条件:
  - 計画済み成果物をすべて処理し、検証が完了した
  - 必須入力不足により継続不能と判定した
- 再計画条件:
  - 既存 `docs/` とコードの不整合により対象成果物の優先順位を変える必要がある
  - 上流成果物の生成結果から下流成果物の対象が確定した
- 分岐条件:
  - 用語が抽出できる場合のみ `glossary`
  - 制約が観測できる場合のみ `constraints`
  - ユースケース/振る舞いが観測できる場合のみ `functional` / `acceptance-criteria` / `testcase`
  - 品質属性が観測できる場合のみ `non-functional`
  - HTTP API が観測できる場合のみ `openapi`
  - システム境界・主要構成が観測できる場合のみ `c4-context` / `c4-container` / `c4-component`
  - 重要な技術判断が明示されている場合のみ `adr`
  - 実行手順がコード・設定・スクリプト・CI から観測できる場合のみ `runbook`
- 並列化ポリシー:
  - 読み取りと証拠収集は並列化可
  - 生成は依存順を守る
  - `FR` 確定前に `AC/TC` を確定しない
  - `runbook` は関連する仕様・設定・実行導線の証拠が揃ってから生成する

## ツール/スキル契約（Contracts）

- 調査ツール:
  - 入力スキーマ: {repo_root, include_globs?, exclude_globs?, target_paths?}
  - 出力スキーマ: {files[], symbols?, routes?, schemas?, tests?, configs?, scripts?, ci?, evidence_notes[]}
  - 前提: 読み取り権限がある
  - 失敗時: 除外パスを拡大して再読取し、それでも不可なら該当領域を未確定として継続
  - 冪等性: あり

- glossary:
  - 入力スキーマ: {terms[], existing_glossary?}
  - 出力スキーマ: {file_path:"docs/glossary.md", term_ids[]}
  - 前提: 用語候補が抽出できる
  - 失敗時: 定義不足の用語を除外して1回だけ再生成
  - 冪等性: あり

- constraints:
  - 入力スキーマ: {constraints[], existing_constraints?}
  - 出力スキーマ: {file_path:"docs/requirements/constraints.md", constraint_ids[]}
  - 前提: 制約の根拠がコード・設定・運用要件から観測できる
  - 失敗時: 未確定値を除外して1回だけ再生成
  - 冪等性: あり

- functional:
  - 入力スキーマ: {features[], existing_files?, related_terms?, related_constraints?}
  - 出力スキーマ: {file_paths[], fr_ids[]}
  - 前提: ユースケースまたは観測可能な振る舞いが特定できる
  - 失敗時: 対象外・例外フローを削減して1回だけ再生成
  - 冪等性: あり

- non-functional:
  - 入力スキーマ: {quality_requirements[], existing_files?, related_constraints?}
  - 出力スキーマ: {file_paths[], nfr_ids[]}
  - 前提: 性能・可用性・セキュリティ・運用などの品質属性が観測できる
  - 失敗時: 数値未確定要素を除外して1回だけ再生成
  - 冪等性: あり

- acceptance-criteria:
  - 入力スキーマ: {fr_ids[], scenarios[], existing_files?}
  - 出力スキーマ: {file_paths[], ac_ids[]}
  - 前提: 対応 FR が存在する
  - 失敗時: シナリオを基本系中心に縮小して1回だけ再生成
  - 冪等性: あり

- testcase:
  - 入力スキーマ: {fr_ids?, nfr_ids?, ac_ids?, interfaces?, scenarios[], existing_files?}
  - 出力スキーマ: {file_paths[], tc_ids[]}
  - 前提: 少なくとも AC または NFR の根拠が存在する
  - 失敗時: 観測点を最小化して1回だけ再生成
  - 冪等性: あり

- openapi:
  - 入力スキーマ: {endpoints[], auth?, errors?, related_ids?, existing_openapi?}
  - 出力スキーマ: {file_path:"docs/specs/interfaces/openapi.yaml", operation_ids[]}
  - 前提: HTTP API が対象に含まれる
  - 失敗時: スキーマ統合を1回だけ再試行
  - 冪等性: あり

- c4-context / c4-container / c4-component:
  - 入力スキーマ: {system_name, people?, externals?, containers?, components?, rels[], existing_files?}
  - 出力スキーマ: {file_paths[]}
  - 前提: 実在・確定している名称のみを扱う
  - 失敗時: 各レベル1回だけ機械的再生成。不明要素はコメントへ退避し、下位レベルはスキップ可
  - 冪等性: あり

- adr:
  - 入力スキーマ: {decisions[], options[], rationale[], existing_files?, related_ids?}
  - 出力スキーマ: {file_paths[], adr_ids[]}
  - 前提: 重要な技術判断と比較根拠が確認できる
  - 失敗時: 比較選択肢を最低2案に整理して1回だけ再生成。それでも根拠不足ならスキップ
  - 冪等性: あり

- runbook:
  - 入力スキーマ: {operational_evidence[], related_ids?, existing_files?, update_mode?}
  - 出力スキーマ: {file_paths:["docs/runbooks/RUN-NNN_XXX.md"], run_ids[]}
  - 前提: スクリプト、CI、設定、運用コマンド、障害対応導線のいずれかに根拠がある
  - 失敗時: 根拠不足の手順は生成せず、対象と不足理由を `state.skipped` に記録する
  - 冪等性: あり

- traceability-check:
  - 入力スキーマ: {artifact_paths[], root_ids[]}
  - 出力スキーマ: {issues[], status:"pass"|"warn"|"fail"}
  - 前提: 少なくとも FR / AC / TC / RUN のいずれかが存在する
  - 失敗時: 読み取り不能ファイルを除外して継続し、重大不整合のみ停止
  - 冪等性: あり

## エラー処理（Recovery）

- エラー分類:
  - 入力不足
  - 読み取り不能
  - 採番競合
  - 既存成果物との整合性不良
  - スキル出力フォーマット不正
  - 根拠不足による生成不能
  - 検証不合格
- リトライ:
  - 文書生成スキルは最大1回。機械的に補正できる場合のみ
  - 調査ツールは対象範囲縮小または除外パターン追加で最大1回
- フォールバック:
  - `glossary` / `constraints` / `adr` / `c4-*` / `openapi` / `runbook` は根拠が薄い場合は生成しない
  - `AC/TC` は上流要件が未確定ならスキップして部分成功へ切り替える
  - C4 は L1 → L2 → L3 の順で下位を任意化する
- ユーザー確認ポイント: 破壊的な既存仕様更新を伴う場合のみ確認する

## 生成物（任意）

- `docs/glossary.md`
- `docs/requirements/constraints.md`
- `docs/requirements/functional/FR-NNN_XXX.md`
- `docs/requirements/non-functional/NFR-NNN_XXX.md`
- `docs/requirements/acceptance-criteria/AC-FR-NNN_XXX.md`
- `docs/testing/testcases/TC-FR-NNN_XXX.md`
- `docs/testing/testcases/TC-NFR-NNN_XXX.md`
- `docs/specs/interfaces/openapi.yaml`
- `docs/specs/c4/system-context.puml`
- `docs/specs/c4/containers.puml`
- `docs/specs/c4/components/<container_name>.puml`
- `docs/adr/ADR-NNN.md`
- `docs/runbooks/RUN-NNN_XXX.md`

## 出力テンプレート

~~~md
# 逆算ドキュメント生成結果

## 生成 / 更新ファイル

- **requirements**: <path一覧 or 省略>
- **specs**: <path一覧 or 省略>
- **testing**: <path一覧 or 省略>
- **runbooks**: <path一覧 or 省略>
- **adr**: <path一覧 or 省略>

## 検証結果

- **ステータス**: 成功 | 部分成功 | 失敗
- **要約**: <整合性・未対応事項の要約>

## スキップした成果物（任意）

- **成果物**: <path or 種別>
  - **理由**: <根拠不足 / 対象外 / 依存不足 / 検証失敗>
~~~

## ワークフロー

### 新規実行

1. リポジトリを走査し、ルーティング、公開API、主要モジュール、設定、永続化、テスト、CI、スクリプト、既存 `docs/` を収集する。
2. 抽出結果から `state.evidence` を作り、用語・制約・機能・品質属性・構成要素・技術判断・運用手順に分類する。
3. `README.md` の SSOT 配置と ID ルールに照らして `state.doc_plan` を作る。
4. 原則として `glossary` → `constraints` → `functional` / `non-functional` → `acceptance-criteria` → `testcase` → `openapi` → `c4-context` / `c4-container` / `c4-component` → `adr` → `runbook` → `traceability-check` の順で進める。
5. 既存ファイルがある場合は差分更新、新規ファイルが必要な場合は採番して生成する。
6. 生成後に `traceability-check` で接続漏れ・孤立・重複・矛盾を検査し、重大不整合があれば上流成果物へ戻って1回だけ再計画する。
7. 出力テンプレートで結果を返す。

### 既存状態からの再開（重要）

1. 既存 `docs/` と過去の生成結果を読み込み、未完了・失敗・スキップ済みの成果物を特定する。
2. `state.generated` と `state.skipped` を再構築し、未処理の成果物だけを `state.doc_plan` に残す。
3. 依存済み成果物は再生成せず、必要な差分更新だけを行う。
4. 再開時も最後に `traceability-check` を実行し、全体整合性を再確認する。

## チェックリスト

- [ ] 完了条件を満たした
- [ ] 既存 SSOT 配置と ID ルールを満たした
- [ ] 根拠のない仕様や名称を追加していない
- [ ] `FR → AC → TC` と `x-ids` 等の接続を検証した
- [ ] 失敗時の代替経路が機能する

## 使用例

### 例1: コードベース全体から docs/ を再構築

**入力**:

> 既存の TypeScript リポジトリを読んで、`docs/` を逆算生成して。既存ファイルは保持し、足りないものだけ追加して。

**出力**: `docs/requirements/**`、`docs/specs/interfaces/openapi.yaml`、`docs/specs/c4/**`、`docs/testing/testcases/**` の生成/更新結果と整合性レポート

### 例2: API と要件だけを逆算生成

**入力**:

> Express のルーティングとバリデーション実装を根拠に、FR / AC / TC と `openapi.yaml` を作って。C4 と ADR は不要。

**出力**: `FR-NNN_XXX.md`、`AC-FR-NNN_XXX.md`、`TC-FR-NNN_XXX.md`、`docs/specs/interfaces/openapi.yaml`

### 例3: 既存 docs/ の補完

**入力**:

> 既存の `docs/requirements/` はある。コードとテストを根拠に、不足している `AC` と `TC` だけ補完して。

**出力**: 既存要件を保持しつつ、不足していた `AC-FR-NNN_XXX.md` と `TC-FR-NNN_XXX.md` を追加した結果
