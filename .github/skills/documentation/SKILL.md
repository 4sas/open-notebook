---
name: documentation
description: |
  要望の箇条書きから、`docs/` 配下の要件・受入基準・テスト仕様・設計成果物を段階的に生成・更新するオーケストレータースキル。
  複数スキル/ツールを束ね、対象判定、依存順制御、既存 `docs/` の差分更新、分岐、再試行、部分成功への切り替えが必要な場合に使う。
  実装変更そのもの、既存コードからの逆算ドキュメント生成、単一成果物だけの単発作成には使わない。
---

# 要望の箇条書きから docs/ を生成するオーケストレータースキル

## 目的（Done定義）

- 要望の箇条書きを、`docs/` 配下のIDベースで追跡可能な成果物群へ落とし込む。
- 必要な成果物だけを生成/更新する。
- 原則として `glossary` → `constraints` → `functional` / `non-functional` → `acceptance-criteria` → `testcase` → `adr` / `data-model` / `openapi` / `ui-spec` / `c4-model` → `runbook` → `traceability-check` の順で進める。
- 類似ケースと標準はWeb検索で整合性確認し、公式情報を優先して採用する。ただし、生成する成果物には出典・脚注・引用を含めない。
- 実装コード、単体テストコード、設定ファイルは変更しない。
- 最終的に、生成/更新ファイル一覧、スキップ理由、検証結果を返す。
- 成功: 必要な `docs/` 成果物が生成/更新され、重大な整合性不良がない状態で完了する。
- 部分成功: 一部成果物は入力不足・根拠不足・依存不足で生成を見送るが、生成済み成果物と未対応理由を明示して完了する。
- 失敗: 必須入力が欠落し、妥当な仮定でもトレーサブルな `docs/` 成果物を1つも作れない場合に限る。

## 適用範囲

- 対象タスク: 箇条書き要求から `docs/requirements/`、`docs/testing/`、`docs/specs/`、`docs/adr/`、`docs/runbooks/` を必要最小限で生成/更新し、整合性検証まで行うタスク
- 非対象タスク（使うべきでない）:
  - 実装変更そのもの、コード修正、テスト実装
  - 既存コードを根拠に `docs/` を逆算生成するタスク（`reverse-engineering` を使う）
  - 単一ファイルだけを単発生成するタスク
  - 調査だけで終わる相談

## 入力

- 必須:
  - 要望の箇条書き
  - 対象リポジトリ、または `docs/` 配置先
- 任意:
  - 既存 `docs/` 一式
  - 技術スタック
  - UI/API/外部連携/運用要件
  - 既知のID、採番規則、更新対象
  - 明示的な対象外スコープ
- 不足時の扱い:
  - 質問する: 既存ファイル更新時に同一ID候補が複数あり、一意に更新先を決められない場合のみ
  - 仮定する: 未指定の配置先は `docs/`、未指定の要件ステータスは `設計中`、運用根拠がない場合は `runbook` を生成しない
  - 中断する: 正式名称や既存IDを創作しないと生成できない場合、または既存の承認済み成果物を破壊的に上書きするしかない場合

## 状態モデル（State）

- state.request: 元の要望の箇条書き
- state.docs_root: `docs/` のルートパス
- state.scope: 対応対象/対象外/更新対象
- state.research: {queries:[], standards_summary:string, source_count:number}
- state.glossary_terms: 用語一覧
- state.constraints: 制約一覧
- state.fr_ids: 生成/更新対象の FR 一覧
- state.nfr_ids: 生成/更新対象の NFR 一覧
- state.ac_ids: 生成/更新対象の AC 一覧
- state.tc_ids: 生成/更新対象の TC 一覧
- state.design_targets: Data Model / OpenAPI / UI / C4 / ADR / Runbook の要否と対象
- state.artifacts: 生成/更新したファイル一覧
- state.blockers: 続行不能要因
- state.validation: 検証結果
- 不変条件（Invariants）:
  - ID を主キーとして扱い、既存IDのリネームや再採番をしない
  - KISS / DRY / YAGNI に従い、重複仕様を増やさず、将来要件を先回りしない
  - 未確認の名称を創作しない
  - 実装コード、単体テストコード、設定ファイルを変更しない
  - 生成物に出典・脚注・引用・不要なログを含めない
  - 過去の会話や回答を前提にせず、現在の入力と既存成果物のみを根拠にする
  - 専門用語への補足コメントは、理解阻害がある箇所にだけ限定する

## 実行モデル（Control）

- 方式: Plan-and-Execute + 段階ゲート付き状態機械
- 停止条件:
  - 必要な `docs/` 成果物の生成/更新が完了し、検証結果が `成功` または `部分成功` で確定した
  - または、必須入力不足により `失敗` が確定した
- 再計画条件:
  - 既存成果物の発見により採番・更新対象・差分方針が変わった
  - Web調査で当初仮定と矛盾する標準や制約が見つかった
  - `traceability-check` で `FR → AC → TC` や `x-ids` の不整合が見つかった
- 分岐条件:
  - 用語が重要なら `glossary` を実行
  - 制約があるなら `constraints` を実行
  - 機能要件があるなら `functional`、品質要件があるなら `non-functional` を実行
  - FR が確定したら `acceptance-criteria`、続いて `testcase` を実行
  - 技術判断があるなら `adr` を実行
  - 永続化対象の構造設計が必要なら `data-model` を実行
  - HTTP API があるなら `openapi` を実行
  - 画面要件があるなら `ui-spec` を実行
  - 構造設計が必要なら `c4-model` を実行
  - 運用手順が明示されている場合のみ `runbook` を実行
- 並列化ポリシー:
  - 同種成果物の採番競合を避けるため、`glossary` / `constraints` / `functional` / `non-functional` / `acceptance-criteria` / `testcase` / `adr` / `runbook` は直列
  - 依存のない `data-model` / `openapi` / `ui-spec` / `c4-model` は並列可
  - `traceability-check` は最後に直列で実行する

## ツール/スキル契約（Contracts）

- web.run:
  - 入力スキーマ: {queries[], priority:"official-first", min_independent_sources:3}
  - 出力スキーマ: {findings_summary, sources[]}
  - 前提: 類似ケースや標準を確認できる公開情報が存在する
  - 失敗時: 既存成果物の規約を優先し、標準確認不足を `state.blockers` に退避する
  - 冪等性: なし（検索結果は時点依存）

- glossary:
  - 入力スキーマ: {terms[], existing_glossary?, context?}
  - 出力スキーマ: {file_path:"docs/glossary.md", term_ids[]}
  - 前提: 抽出すべき用語がある
  - 失敗時: 用語不足ならスキップする
  - 冪等性: あり

- constraints:
  - 入力スキーマ: {constraints[], existing_constraints?}
  - 出力スキーマ: {file_path:"docs/requirements/constraints.md", constraint_ids[]}
  - 前提: 制約候補を抽出できる
  - 失敗時: 曖昧な制約は `state.blockers` に退避する
  - 冪等性: あり

- functional:
  - 入力スキーマ: {features[], related_terms?, related_constraints?, existing_files?}
  - 出力スキーマ: {file_paths[], fr_ids[]}
  - 前提: 機能境界を分解できる
  - 失敗時: 要求を機能単位へ再分割して1回だけ再試行し、それでも不明確なら部分成功へ切り替える
  - 冪等性: あり

- non-functional:
  - 入力スキーマ: {quality_requirements[], related_constraints?, existing_files?}
  - 出力スキーマ: {file_paths[], nfr_ids[]}
  - 前提: 品質属性を測定可能な要件に落とせる
  - 失敗時: 定量化できない項目は保留して部分成功へ切り替える
  - 冪等性: あり

- acceptance-criteria:
  - 入力スキーマ: {fr_ids[], scenarios_by_fr, existing_files?}
  - 出力スキーマ: {file_paths[], ac_ids[]}
  - 前提: 対応する FR が存在する
  - 失敗時: FR の粒度や不足情報を見直し、必要なら `functional` へ戻す
  - 冪等性: あり

- testcase:
  - 入力スキーマ: {fr_or_nfr_ids[], ac_ids?, interfaces?, execution_level?, existing_files?}
  - 出力スキーマ: {file_paths[], tc_ids[]}
  - 前提: 対応する FR / NFR または AC が存在する
  - 失敗時: 受入条件不足なら `acceptance-criteria` または `non-functional` へ戻す
  - 冪等性: あり

- adr:
  - 入力スキーマ: {decisions[], related_ids?, existing_files?}
  - 出力スキーマ: {file_paths:["docs/adr/ADR-NNN.md"], adr_ids[]}
  - 前提: 記録すべき技術判断がある
  - 失敗時: 判断が未確定なら生成しない
  - 冪等性: あり

- data-model:
  - 入力スキーマ: {entities[], attributes?, relations?, enums?, constraints?, indexes?, related_ids?, existing_file?}
  - 出力スキーマ: {file_path:"docs/specs/data-model.dbml", table_names[]}
  - 前提: 永続化対象、識別子、参照関係の少なくとも一部を定義できる
  - 失敗時: 識別子や参照先を推測しないと成立しない場合は生成を見送り、必要情報を `state.blockers` に退避する
  - 冪等性: あり

- openapi:
  - 入力スキーマ: {endpoints[], auth?, schemas?, errors?, related_ids?, existing_file?}
  - 出力スキーマ: {file_path:"docs/specs/interfaces/openapi.yaml", operation_ids[]}
  - 前提: HTTP API の外部契約が定義できる
  - 失敗時: API 境界が不安定なら生成を見送り、必要情報を `state.blockers` に退避する
  - 冪等性: あり

- ui-spec:
  - 入力スキーマ: {screens[], ui_elements?, events?, states?, api_links?, related_ids?, existing_files?}
  - 出力スキーマ: {file_paths:["docs/specs/ui/SCR-NNN_XXX.md"], screen_ids[]}
  - 前提: 画面単位でUI要件を定義できる
  - 失敗時: 画面遷移やイベントが未確定なら生成しない
  - 冪等性: あり

- c4-model:
  - 入力スキーマ: {system_name, people?, external_systems?, containers?, components?, classes?, existing_files?}
  - 出力スキーマ: {file_paths[], levels_completed[]}
  - 前提: アーキテクチャ対象と確定要素を識別できる
  - 失敗時: 下位レベルをスキップし、生成できたレベルだけで部分成功へ切り替える
  - 冪等性: あり

- runbook:
  - 入力スキーマ: {runbook_types[], operational_steps?, rollback?, escalation?, related_ids?, existing_files?}
  - 出力スキーマ: {file_paths:["docs/runbooks/RUN-NNN_XXX.md"], run_ids[]}
  - 前提: 手順の根拠となる運用情報が明示されている
  - 失敗時: 推測では補わず、更新対象と不足情報を `state.blockers` に退避する
  - 冪等性: あり

- traceability-check:
  - 入力スキーマ: {artifact_paths[], root_ids[]}
  - 出力スキーマ: {issues[], status:"pass"|"warn"|"fail"}
  - 前提: 少なくとも FR / NFR / AC / TC / OpenAPI / ADR のいずれかが存在する
  - 失敗時: 読み取り不能ファイルを除外して継続し、重大不整合は停止する
  - 冪等性: あり

## エラー処理（Recovery）

- エラー分類:
  - 入力不足
  - Web調査不足
  - 読み取り不能
  - 採番競合
  - 既存成果物との整合性不良
  - スキル出力フォーマット不正
  - 根拠不足による生成不能
  - 検証不合格
- リトライ:
  - 文書生成スキルは最大1回。機械的に補正できる場合のみ
  - Web調査は検索語の絞り込み・同義語追加で最大1回
  - `traceability-check` で見つかった問題への自動修正は1ループまで
- フォールバック:
  - 根拠が薄い `adr` / `data-model` / `openapi` / `ui-spec` / `c4-model` / `runbook` は生成しない
  - `AC` / `TC` は上流要件が未確定ならスキップして部分成功へ切り替える
  - `C4` は L1 → L2 → L3 → L4 の順で下位レベルを任意化する
  - Web根拠が不足しても、既存リポジトリ規約と明示要求で成立する範囲は先に進める
- ユーザー確認ポイント: 既存の承認済み成果物を破壊的に更新する場合、または更新先が複数候補に分岐して自動選択が危険な場合のみ確認する

## 生成物（任意）

- `docs/glossary.md`
- `docs/requirements/constraints.md`
- `docs/requirements/functional/FR-NNN_XXX.md`
- `docs/requirements/non-functional/NFR-NNN_XXX.md`
- `docs/requirements/acceptance-criteria/AC-FR-NNN_XXX.md`
- `docs/testing/testcases/TC-FR-NNN_XXX.md`
- `docs/testing/testcases/TC-NFR-NNN_XXX.md`
- `docs/specs/data-model.dbml`
- `docs/specs/interfaces/openapi.yaml`
- `docs/specs/ui/SCR-NNN_XXX.md`
- `docs/specs/c4/system-context.puml`
- `docs/specs/c4/containers.puml`
- `docs/specs/c4/components/<container_name>.puml`
- `docs/specs/c4/codes/<container_name>/<code_name>.puml`
- `docs/adr/ADR-NNN.md`
- `docs/runbooks/RUN-NNN_XXX.md`

## 出力テンプレート

~~~md
# docs/生成結果

## 生成 / 更新ファイル

- **glossary**: <path一覧 or 省略>
- **requirements**: <path一覧 or 省略>
- **testing**: <path一覧 or 省略>
- **specs**: <path一覧 or 省略>
- **adr**: <path一覧 or 省略>
- **runbooks**: <path一覧 or 省略>

## 検証結果

- **ステータス**: 成功 | 部分成功 | 失敗
- **要約**: <整合性・未対応事項の要約>

## スキップした成果物（任意）

- **成果物**: <path or 種別>
  - **理由**: <根拠不足 / 対象外 / 依存不足 / 検証失敗>
~~~

## ワークフロー

### 新規実行

1. 要望の箇条書きを読み、対象機能、非機能、制約、外部連携、UI/API要否、運用要否を分類する。
2. 既存成果物があれば読み、採番規則、既存ID、更新対象、差分方針を確定する。
3. 類似ケースと標準を `web.run` で調査し、公式情報を優先して整合性を確認する。
4. 用語が必要なら `glossary`、制約があるなら `constraints` を実行する。
5. `functional` と `non-functional` で FR / NFR を生成する。
6. FR を根拠に `acceptance-criteria`、続いて `testcase` を生成する。
7. 技術判断があれば `adr` を生成する。
8. 必要な設計成果物だけ `data-model`、`openapi`、`ui-spec`、`c4-model` を実行する。
9. 明示された運用手順がある場合のみ `runbook` を生成または更新する。
10. `traceability-check` で `FR → AC → TC → 設計 / RUN` の整合性を点検する。
11. 問題があれば該当段階へ戻して最小差分で修正し、なければ完了する。

### 既存状態からの再開（重要）

1. 既存 `docs/` を読み取り、既存ID、承認済み要件、既存設計、既存Runbookを `state` に取り込む。
2. 追加要求を「新規生成」か「既存更新」かに分類し、差分だけを対象にする。
3. 上流成果物が変わった場合のみ、影響する下流成果物を再生成する。
4. 既存の承認済み/実装済みステータスは、明示指示がない限り変更しない。
5. `traceability-check` は変更範囲を優先して再実行し、必要時のみ全体検証する。

## チェックリスト

- [ ] 完了条件を満たした
- [ ] 実装コード、単体テストコード、設定ファイルを変更していない
- [ ] 制約（KISS / DRY / YAGNI / 創作禁止 / 既存ID維持）を満たした
- [ ] Web調査は公式優先・3つ以上の独立ソース確認を原則として実施した、または不足理由を明示した
- [ ] 生成物に出典・脚注・引用・不要なログを含めていない
- [ ] 検証に通った、または未解決事項を部分成功として明示した

## 使用例

既存のWebアプリに対して、以下の要望を `docs/` として整備して。

- 商品検索機能を追加
- 絞り込み条件はカテゴリ、価格帯、在庫有無
- 一覧APIと詳細APIが必要
- 管理画面から検索キーワードの同義語辞書を更新できる
- 応答性能は95パーセンタイルで500ms以内
- 検索ロジックの採用方針はADRに残す
