---
name: development
description: |
  `documentation` スキルで `docs/` 配下の要件・設計成果物を生成/更新した後、その成果物を根拠に環境構築・実装・単体テスト・runbook更新・トレーサビリティ検証までを段階的に実行するオーケストレータースキル。
  複数スキル/ツールを束ね、依存順制御、段階ゲート、分岐、部分再実行、最小差分更新、失敗時の再試行/フォールバックが必要な場合に使う。
  `docs/` の新規作成や要件文書の初回生成自体は行わないため、文書化前の要求整理や単一成果物だけの生成には使わない。
---

# documentation 後工程を実施するオーケストレータースキル

## 目的（Done定義）

- `documentation` スキルが生成/更新した `docs/` 配下の成果物を根拠に、後続工程だけを実行する。
- 原則として `acceptance-criteria` → `testcase` → `adr` / `data-model` / `openapi` / `ui-spec` / `c4-*` の差分更新 → `environment-setup` → `unit-test` → `implementation` → `runbook` → `traceability-check` の順で進める。
- UI 実装が含まれる場合、`ui-spec` と既存 `tailwind/` を根拠に、`tailwind` を **Tailwind UI 実装スキル** として適用し、トークン・utility・base・components の責務を保ったまま最小差分で実装する。
- 環境構築段階では、仕様・設計・運用根拠に基づく必要最小限の定義変更のみを行い、実装段階では仕様・受入基準・テストを根拠に必要最小限のコード変更のみを行う。
- 実装変更によりセットアップ、デプロイ、ロールバック、運用、障害対応の手順が変わる場合は `docs/runbooks/` も更新する。
- 最終的に、生成/更新ファイル一覧、未対応事項、検証結果を返す。
- 成功: 後続工程に必要な仕様・設計・実装・テスト・runbook・検証が整合した状態で完了する。
- 部分成功: 実装系スキル不足、設計不足、実装境界の不確定などにより、一部工程のみ完了し、不足理由を明示して停止する。
- 失敗: `documentation` の成果物または必須根拠が不足し、保守的な仮定でも安全に後続工程へ進めない場合に限る。

## 適用範囲

- 対象タスク: `documentation` 実行後の成果物を起点に、受入基準、テスト仕様、設計差分、環境構築、実装、単体テスト、runbook、整合性検証までを一貫して進めるタスク
- 非対象タスク（使うべきでない）:
  - `docs/` 自体の新規生成や、要件定義・用語集・制約・FR/NFR の初回作成が主目的のタスク
  - 単一ファイルだけの生成、単なる要約、調査のみ、実装を伴わない単発更新
  - 実装根拠となる `docs/` が未整備で、先に `documentation` を実行すべきタスク

## 入力

- 必須:
  - `documentation` スキルで生成/更新済みの `docs/` 配下成果物
  - 対象リポジトリまたは成果物配置先
- 任意:
  - 既存実装コード
  - 技術スタック
  - 実装対象範囲
  - 既存テスト
  - 既存の環境構築定義
  - 期限、優先度、運用制約
  - 既知の関連ID
  - 既存 `tailwind/` 構成（`theme` / `utilities` / `base` / `components`）
- 不足時の扱い:
  - `FR` / `NFR` / 設計成果物が既に `docs/` に存在するなら、それを根拠として続行する。
  - `AC` / `TC` が未生成なら本スキル内で補完する。
  - UI 実装で `ui-spec` が不足していても、既存画面・既存 Tailwind component・既存 state 規約から安全に補完できる範囲のみ続行する。
  - 実装範囲や仕様境界を一意に決められない場合は、実装を止めて部分成功で返す。
  - `documentation` 未実行、または同等の `docs/` 根拠が確認できない場合は中断する。

## 状態モデル（State）

- state.docs_root: string
- state.scope: 対応対象/対象外/実装対象範囲
- state.requirement_ids: FR / NFR / AC / TC / RUN などの関連ID一覧
- state.design_targets: Data Model / OpenAPI / UI / C4 / ADR の更新要否と対象
- state.environment_targets: 環境構築定義の更新要否と対象
- state.impl_targets: 実装対象コード、対象テスト、根拠ID
- state.ui_targets:
  - 画面 / 部品 / フォーム / 状態
  - 対象 `tailwind/` パス
  - 再利用候補の component / utility / token
  - 実装レベル: `reuse-only` | `utility-extend` | `component-extend` | `token-extend`
- state.runbook_targets: 更新対象の Runbook 一覧
- state.artifacts: 生成/更新したファイル一覧
- state.blockers: 続行不能要因
- state.validation: トレーサビリティ検証結果
- 不変条件（Invariants）:
  - `documentation` が確定した既存IDのリネームや再採番をしない
  - 明示指示なしに既存確定仕様を広げない
  - 実装は `docs/` の根拠がある範囲に限定する
  - 不要なログ、出典、脚注、引用を成果物へ含めない

## 実行モデル（Control）

- 方式: Plan-and-Execute + 段階ゲート付き状態機械
- 停止条件:
  - 完了条件を満たした
  - 実装前提が不足し、保守的仮定でも誤実装リスクが高い
  - 検証で重大不整合が残り、自動修正できない
- 再計画条件:
  - `AC` / `TC` / 設計差分の要否が変わった
  - `FR → AC → TC` や `x-ids` の不整合が見つかった
  - 既存成果物との競合により、対象ファイルや更新順が変わった
  - UI 実装で、既存 component 再利用から utility 拡張または component 拡張へ方針変更が必要になった
- 分岐条件:
  - `AC` が不足 → `acceptance-criteria` を実行
  - `TC` が不足 → `testcase` を実行
  - 重要な技術判断が未記録 → `adr` を実行
  - 永続化構造の設計差分が必要 → `data-model` を実行
  - HTTP API の設計差分が必要 → `openapi` を実行
  - UI要件の設計差分が必要 → `ui-spec` を実行
  - 構造設計の差分が必要 → `c4-*` を段階実行
  - 実行・配備・基盤に関わる定義差分が必要 → `environment-setup` を実行
  - 単体で閉じる振る舞いがある → `unit-test` を実行
  - 実装対象が確定 → `implementation` を実行
  - UI 実装対象が確定し、既存 Tailwind UI システムに従う必要がある → `tailwind` を実行
  - 運用手順の更新が必要 → `runbook` を実行
- 並列化ポリシー:
  - 採番競合を起こす同種成果物は直列
  - 依存のない設計差分更新は並列可
  - 実装とトレーサビリティ検証は直列
  - `runbook` は実装・設定差分確定後に直列で実行する

## ツール/スキル契約（Contracts）

- acceptance-criteria:
  - 入力スキーマ: {fr_ids[], scenarios_by_fr, existing_files?}
  - 出力スキーマ: {file_paths[], ac_ids[]}
  - 前提: 対応FRが存在する
  - 失敗時: FR不足なら中断し、`documentation` 側の不足として `state.blockers` に退避する
  - 冪等性: あり

- testcase:
  - 入力スキーマ: {fr_or_nfr_ids[], ac_ids?, interfaces?, execution_level?, existing_files?}
  - 出力スキーマ: {file_paths[], tc_ids[]}
  - 前提: 対応FR/NFRまたはACが存在する
  - 失敗時: 受入条件不足なら `acceptance-criteria` へ戻す
  - 冪等性: あり

- adr:
  - 入力スキーマ: {decision, background, options[], constraints?, existing_files?}
  - 出力スキーマ: {file_path, adr_id}
  - 前提: 技術判断が他成果物へ影響する
  - 失敗時: 選択肢が不足する場合は実装を止めて部分成功へ切り替える
  - 冪等性: あり

- data-model:
  - 入力スキーマ: {entities?, relations?, constraints?, indexes?, fr_ids?, ac_ids?, existing_spec?}
  - 出力スキーマ: {file_path:"docs/specs/data-model.dbml", changed_paths[]}
  - 前提: 永続化対象と識別子 / 参照関係が `docs/` から特定できる
  - 失敗時: テーブル境界や識別子が不明なら当該更新をスキップし、実装も該当範囲を停止する
  - 冪等性: あり

- openapi:
  - 入力スキーマ: {target_endpoints[], fr_ids?, ac_ids?, existing_spec?}
  - 出力スキーマ: {file_path:"docs/specs/interfaces/openapi.yaml", changed_paths[]}
  - 前提: HTTP APIの入出力が `docs/` から特定できる
  - 失敗時: API境界が不明なら当該更新をスキップし、実装も該当範囲を停止する
  - 冪等性: あり

- ui-spec:
  - 入力スキーマ: {screens[], user_flows[], fr_ids?, ac_ids?, existing_specs?}
  - 出力スキーマ: {file_paths[], changed_paths[]}
  - 前提: UI要件が `docs/` から特定できる
  - 失敗時: 画面境界が不明なら当該更新をスキップし、実装も該当範囲を停止する
  - 冪等性: あり

- c4_tools:
  - c4-model
  - c4-context
  - c4-container
  - c4-component
  - c4-code
- c4_selection_policy: |
    単一レベルの図を生成する場合は対応する個別スキルを使う。
    複数レベルの生成・分岐・再試行が必要な場合のみ c4-model を使う。
- c4-context:
  - 入力スキーマ: {system_name, external_systems?, users?, existing_files?}
  - 出力スキーマ: {file_paths[], updated:boolean}
  - 前提: システム境界が特定できる
  - 失敗時: 単独スキップして上位工程は継続
  - 冪等性: あり
- c4-container:
  - 入力スキーマ: {system_name, containers?, existing_files?}
  - 出力スキーマ: {file_paths[], updated:boolean}
  - 前提: コンテナ境界が特定できる
  - 失敗時: 単独スキップして上位工程は継続
  - 冪等性: あり
- c4-component:
  - 入力スキーマ: {container_name, components?, existing_files?}
  - 出力スキーマ: {file_paths[], updated:boolean}
  - 前提: 対象コンテナ内部の責務分割が特定できる
  - 失敗時: 単独スキップして部分成功へ切り替える
  - 冪等性: あり
- c4-code:
  - 入力スキーマ: {target_files?, classes?, functions?, existing_files?}
  - 出力スキーマ: {file_paths[], updated:boolean}
  - 前提: コードレベルの対象が特定できる
  - 失敗時: 単独スキップして部分成功へ切り替える
  - 冪等性: あり
- c4-model:
  - 入力スキーマ: {system_name, containers?, components?, classes?, existing_files?}
  - 出力スキーマ: {file_paths[], updated:boolean}
  - 前提: 構造設計の差分が `docs/` または既存実装から特定できる
  - 失敗時: 上位レベルから順に不足範囲をスキップし、部分成功へ切り替える
  - 冪等性: あり

- environment-setup:
  - 入力スキーマ: {target_layers[], related_ids?, source_paths?, deployment_targets?, infrastructure_scope?, existing_files?, verification_commands?, execution_envs?}
  - 出力スキーマ: {changed_files[], summary, verification_results[]}
  - 前提: 実行・配備・基盤のいずれかに差分根拠がある
  - 失敗時: 対象をローカル実行 / 配備 / 基盤へ再分割し1回だけ再試行。それでも根拠不足または検証不能なら部分成功へ切り替える
  - 冪等性: なし

- implementation:
  - 入力スキーマ: {target_ids[], source_paths[], test_paths?, constraints?, design_refs?, coding_conventions?, verification_commands?, execution_envs?, ui_targets?, tailwind_paths?}
  - 出力スキーマ: {changed_files[], summary, verification_results[]}
  - 前提: 少なくとも FR / AC / TC の根拠が揃っている
  - 実行経路ルール: Docker / compose / devcontainer / ci-equivalent など既存のコンテナ実行経路が1つでも存在する場合、 **ホスト環境での検証実行を禁止する** （ユーザーが明示的に許可した場合のみ例外）。
  - 失敗時: テスト起点で実装単位を再分割し1回だけ再試行。検証は原則として Docker / compose / devcontainer / ci-equivalent など既存の **コンテナ実行経路を優先** し、コンテナ経路が存在しない場合に限ってホスト環境を用いる。それでも実行不能なら部分成功へ切り替える
  - 冪等性: なし

- unit-test:
  - 入力スキーマ: {tc_ids[], source_paths[], framework?, existing_tests?, verification_commands?, execution_envs?}
  - 出力スキーマ: {changed_test_files[], summary, verification_results[]}
  - 前提: 対応 TC と実装境界が特定済み
  - 実行経路ルール: Docker / compose / devcontainer / ci-equivalent など既存のコンテナ実行経路が1つでも存在する場合、 **ホスト環境での検証実行を禁止する** （ユーザーが明示的に許可した場合のみ例外）。
  - 失敗時: テスト粒度を下げて1回だけ再試行。検証は原則として Docker / compose / devcontainer / ci-equivalent など既存の **コンテナ実行経路を優先** し、コンテナ経路が存在しない場合に限ってホスト環境を用いる
  - 冪等性: なし

- runbook:
  - 入力スキーマ: {runbook_types[], related_ids?, operational_steps?, rollback?, escalation?, existing_files?}
  - 出力スキーマ: {file_paths:["docs/runbooks/RUN-NNN_XXX.md"], run_ids[]}
  - 前提: セットアップ / デプロイ / ロールバック / 障害対応 / 定常運用のいずれかに変更がある
  - 失敗時: 根拠のない手順推測はせず、更新対象と不足情報を `state.blockers` に退避する
  - 冪等性: あり

- traceability-check:
  - 入力スキーマ: {artifact_paths[], root_ids[]}
  - 出力スキーマ: {issues[], status:"pass"|"warn"|"fail"}
  - 前提: 少なくとも FR / AC / TC のいずれかが存在する
  - 失敗時: 読み取り不能ファイルを除外して継続し、重大不整合は停止する
  - 冪等性: あり

## エラー処理（Recovery）

- エラー分類:
  - 根拠不足（`documentation` 未実行、FR/設計不足、実装境界不明）
  - 採番/参照不整合（FR / AC / TC / ADR / RUN の不一致）
  - 環境構築失敗（定義競合、実行経路不整合、配備/基盤差分の根拠不足）
  - 実装失敗（変更範囲過大、依存解決不能、テスト不成立）
  - 検証失敗（トレーサビリティ欠落、runbook未更新、設計差分未反映）
- リトライ: `acceptance-criteria` / `testcase` / `environment-setup` / `unit-test` / `implementation` は各1回まで最小単位で再試行する
- フォールバック:
  - 設計差分が不明な範囲はスキップして部分成功に切り替える
  - 環境構築だけが未確定な範囲は、該当差分を保留して部分成功に切り替える
  - 実装系スキルが無い場合は、実装直前までの成果物と不足理由を返す
  - runbook の根拠が不足する場合は、実装と検証だけ完了させて runbook を保留にする
- 例外記録ルール（ホスト実行を行った場合は必須）:
  - 記録項目: コンテナ経路の有無、ホスト実行が必要だった理由、ユーザー明示許可の有無、影響範囲、コンテナ経路へ戻すための是正アクション
  - 記録先: 実行結果の「非対応 / 保留」または同等セクション
  - 許容条件: 「コンテナ経路が存在しない」または「ユーザー明示許可あり」のいずれかを満たす場合に限る
- ユーザー確認ポイント: 破壊的変更、外部I/F変更、本番運用手順変更の有無
- 実装は原則として **TDD（Red → Green → Refactor）** で進める
- `unit-test` は **Red の作成**、`implementation` は **Green と最小限の Refactor** を担当する

## 出力テンプレート

~~~md
# 実行結果

## 生成 / 更新ファイル

- **受入基準**: <path一覧 or 省略>
- **単体テスト**: <path一覧 or 省略>
- **設計**: <path一覧 or 省略>
- **環境構築**: <path一覧 or 省略>
- **実装**: <path一覧 or 省略>
- **runbook**: <path一覧 or 省略>

## 検証結果

- **ステータス**: 成功 | 部分成功 | 失敗
- **要約**: <TDD の Red / Green / Refactor の実施結果を含む要約>

## 非対応 / 保留

- **理由**: <必要な項目のみ>
- **例外記録（ホスト実行時のみ）**: <コンテナ経路の有無 / 実施理由 / ユーザー許可 / 影響範囲 / 是正アクション>
~~~

## ワークフロー

### 新規実行

1. `documentation` の成果物を読み、対象機能、非機能、制約、設計、既存ID、更新対象、差分方針を確定する。
2. `AC` が不足していれば `acceptance-criteria` を実行する。
3. `TC` が不足していれば `testcase` を実行する。
4. 技術判断が不足していれば `adr` を実行する。
5. 必要な設計差分だけ `data-model`、`openapi`、`ui-spec`、`c4-*` を実行する。
6. 実行・配備・基盤に差分がある場合は `environment-setup` を実行する。
7. `FR / AC / TC / 設計` が揃った対象だけを **TDD対象** として扱う。
8. `unit-test` で **失敗する単体テストを先に** 実装または更新する。
9. `implementation` で **追加した失敗テストを通す最小実装** のみを加える。
10. 必要な場合のみ、仕様に影響しない範囲で重複除去・命名改善・構造整理を行う。
11. 実装・環境定義・運用導線の差分から必要な `runbook` を生成または更新する。
12. `traceability-check` で `FR → AC → TC → 設計 / 環境構築 / 単体テスト / 実装 / RUN` の整合性を点検する。
13. 問題がなければ完了し、問題があれば該当段階へ戻して最小差分で修正する。

### 既存状態からの再開（重要）

1. 既存の `docs/` を読み、既存ID、承認済み要件、設計、runbook、変更対象を `state` に取り込む。
2. 追加要求を「新規生成」か「既存更新」かに分類し、差分だけを対象にする。
3. 上流成果物が変わった場合のみ、影響する下流成果物を再生成する。
4. 実行・配備・基盤に影響する差分がある場合は、先に `environment-setup` の更新要否を見直す。
5. 実装対象に変更がある場合は、既存単体テストを確認し、足りない振る舞いから **失敗テストを先に追加** する。
6. その後、追加した失敗テストを通す最小実装だけを反映する。
7. 既存の承認済み/実装済みステータスは、明示指示がない限り変更しない。
8. `traceability-check` は変更範囲を優先して再実行し、必要時のみ全体検証する。

## チェックリスト

- [ ] 完了条件を満たした
- [ ] `documentation` 後工程だけに責務を限定した
- [ ] 制約（最小差分、既存ID保持、根拠ベース実装）を満たした
- [ ] 検証に通った（`FR → AC → TC → 設計 / 環境構築 / 実装 / RUN` の整合性）
- [ ] 失敗時の代替経路が機能する

## 使用例

### 例1: documentation 後に実装まで進める

**入力**:
> 既存の `docs/requirements/` と `docs/specs/` は `documentation` で生成済み。これを根拠に AC / TC を補完し、API差分、実装、単体テスト、runbook 更新まで進めて。

**出力**:
> `AC-FR-NNN_XXX.md`、`TC-FR-NNN_XXX.md`、必要な `openapi.yaml` 差分、実装コード、単体テスト、`docs/runbooks/RUN-NNN_XXX.md`、整合性検証結果

### 例2: 設計差分は不要で実装と検証だけ進める

**入力**:
> `documentation` 済みの FR / AC / TC はある。設計差分は不要なので、実装、単体テスト、runbook、traceability-check だけ進めて。

**出力**:
> 既存 docs を保持しつつ、必要最小限のコード変更、単体テスト更新、runbook 更新、整合性レポート
