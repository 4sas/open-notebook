---
name: environment-setup
description: |
  既存の FR / NFR / AC / TC / ADR / OpenAPI / C4 / runbook と既存実装を根拠として、開発・実行・配備・基盤に必要な環境構築定義を新規作成・更新するスキル。
  **コンテナ化**、**ローカル実行定義**、**Kubernetes 配備定義**、**IaC による基盤定義**（例: Dockerfile, compose, Helm chart, Terraform）を対象とし、業務ロジックの実装だけが目的の場合は使わない。
---

# 環境構築スキル

## 目的

既存の仕様・受入基準・テスト仕様・設計・運用手順を根拠として、環境構築定義を最小差分で新規作成または更新する。
対象は **コンテナ化**、**ローカル実行定義**、**Kubernetes 配備定義**、**IaC による基盤定義** とし、アプリケーション実装と責務を分離する。
検証結果は、実行したコマンド、実行環境、結果（pass / fail / not-run）を実測ベースで返す。

## 対象範囲

- **コンテナ化**: `Dockerfile`、`.dockerignore`、起動スクリプト、ビルド引数、マルチステージビルド
- **ローカル実行定義**: `compose.yaml` / `docker-compose.yml`、`.env.example`、`.devcontainer/`、ローカル実行に必要な補助設定
- **Kubernetes 配備定義**: manifest、Helm chart、values、ConfigMap / Secret 参照、Probe、Resource、Service / Ingress 定義
- **IaC による基盤定義**: Terraform の module / variable / output / provider / backend / environment ごとの構成

## 対象外

- 業務ロジックやユースケースの実装
- Unit レベルの自動テストコード作成
- 根拠のない製品選定やクラウドサービス追加
- 実行経路がないのに本番運用前提の手順を推測して埋めること

## 前提

- 対応する `FR / NFR / AC / TC / ADR / 設計 / runbook` のいずれかから、必要な環境差分を説明できることを原則とする。
- 既存の環境定義がある場合は、命名、ディレクトリ構成、変数管理方針を尊重する。
- 変更対象がローカル実行用か、CI 用か、Kubernetes 用か、基盤用かを先に切り分ける。

## 判断規則

- **優先すること**:
  - 既存リポジトリの構成と命名規約の尊重
  - 1つの責務に対する 1つの定義源
  - 公式仕様に沿った標準的な書式と構成
  - シークレットの直書き回避と注入経路の明確化
  - ローカル / CI / 本番の差異をファイルまたは変数で明示すること
- **避けること**:
  - 同じ値を複数の定義へ重複記載すること
  - 将来要件を見越した過剰なテンプレート化
  - 使われない Service / Volume / Variable / Module の先回り追加
  - 検証していない配備手順を成功扱いすること
  - 既存の実行経路と競合する別系統の起動方法を無断追加すること

## 推奨ワークフロー

### 1. 差分の特定

1. `FR / NFR / AC / TC / ADR / 設計 / runbook` を読み、必要な環境差分を特定する。
2. 既存の `Dockerfile`、compose、Helm、Terraform、CI 設定を確認し、変更対象と非対象を切り分ける。
3. 同じ責務を持つ既存定義がある場合は再利用を優先する。

### 2. コンテナ化

1. 必要な場合のみ `Dockerfile` と関連ファイルを更新する。
2. ベースイメージ、ビルド手順、キャッシュ、実行ユーザー、起動コマンドを必要最小限で定義する。
3. アプリ実装に閉じる設定は `implementation` 側、実行環境定義は本スキル側に分離する。

### 3. ローカル実行定義

1. ローカル起動が必要な場合のみ compose や devcontainer を更新する。
2. サービス、ネットワーク、ボリューム、依存関係、環境変数の優先順位を明確にする。
3. `.env.example` など、利用者が再現に必要な最小情報だけを整備する。

### 4. Kubernetes 配備定義

1. 配備先が Kubernetes の場合のみ manifest または Helm chart を更新する。
2. Replica、Probe、Resource、Service、Ingress、Config / Secret 参照を必要最小限で定義する。
3. 再利用性や環境差分が必要な場合に限って Helm chart を採用し、単純な固定構成なら manifest を優先してよい。

### 5. IaC による基盤定義

1. 基盤変更が必要な場合のみ Terraform などの IaC を更新する。
2. Module の境界、入力変数、出力値、state 管理、環境ごとの差分を明確にする。
3. アプリ配備定義と基盤定義の責務が混ざらないようにする。

### 6. 検証

1. 変更対象に応じて build / config validate / template render / plan などを実行する。
2. 可能なら既存のコンテナ経路や CI 相当のコマンドを優先して検証する。
3. 未実施の検証は `not-run` とし、成功扱いしない。

## チェックリスト

- [ ] 変更が `FR / AC / TC / ADR / 設計 / runbook` のいずれかに結び付いている
- [ ] `implementation` と責務が重複していない
- [ ] ローカル実行、配備、基盤の責務が混在していない
- [ ] シークレットを定義へ直書きしていない
- [ ] 既存の命名規則、ディレクトリ構成、変数方針を不要に壊していない
- [ ] 検証結果を実測ベースで説明できる

## 入力形式

- 自然文:
  - 「API サービスをコンテナ化して、ローカルは compose、配備は Helm chart で定義して」
  - 「Terraform で VPC とアプリ実行基盤を追加して」
- 箇条書き:
  - 対象サービス
  - ローカル実行要件
  - 配備先（Kubernetes など）
  - 基盤要件
  - 既存定義の有無
- 既存ファイル:
  - `Dockerfile`
  - `compose.yaml`
  - `.devcontainer/devcontainer.json`
  - `deploy/helm/...`
  - `infra/terraform/...`

## 出力

- **場所**: 既存リポジトリ規約を優先し、未整備なら以下を目安とする
  - コンテナ化: ルート直下またはサービス配下の `Dockerfile`
  - ローカル実行定義: `compose.yaml`、`.devcontainer/`
  - Kubernetes 配備定義: `deploy/helm/` または `deploy/k8s/`
  - IaC: `infra/terraform/`
- **ファイル**: 変更対象に応じた環境構築定義一式

## 使用例

### 例1: 新規作成

**入力**:
> API をコンテナ化し、ローカル実行は compose、Kubernetes 配備は Helm chart、基盤は Terraform で定義して。

**出力**:
> `Dockerfile`、`compose.yaml`、`deploy/helm/api/`、`infra/terraform/`

### 例2: 既存定義の更新

**入力**:
> 既存の `compose.yaml` と Helm chart に worker サービスを追加して。Terraform のモジュール構成は維持して。

**出力**:
> 既存構成を保持しつつ、worker に必要な compose / Helm の最小差分を反映した環境構築定義
