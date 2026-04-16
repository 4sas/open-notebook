---
name: openapi
description: |
  HTTP API の仕様（エンドポイント、リクエスト/レスポンス、スキーマ、認証、エラー等）を OpenAPI として新規作成・更新する必要があるときに使う。
  逆に、API 変更が伴わない内部実装の詳細（DB最適化など）だけを記述したい場合は使わない
---

# OpenAPI 作成スキル

## 目的

HTTP API を OpenAPI 形式（YAML）で **新規作成または更新** し、機械可読な仕様（paths / components / security 等）を `openapi.yaml` として出力する。

## [出力テンプレート](../../../docs/templates/openapi.yaml)

~~~md
openapi: 3.1.0
info:
  title: <API名>
  version: <SemVer or 日付版>
  description: <1〜3行の概要（任意）>

servers:
  - url: <https://api.example.com>

tags:
  - name: <ドメイン/領域名>
    description: <任意>

paths:
  /<resource>:
    get:
      tags: [<tag>]
      operationId: <lowerCamelCaseVerbNoun>
      summary: <1行>
      description: <任意>
      x-ids: ["FR-001"] # （任意）
      parameters:
        - $ref: "#/components/parameters/<ParamName>"
      responses:
        "200":
          $ref: "#/components/responses/<ResponseName>"
        "4XX":
          $ref: "#/components/responses/Error"
    post:
      tags: [<tag>]
      operationId: <lowerCamelCaseVerbNoun>
      summary: <1行>
      x-ids: ["FR-002"] # （任意）
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/<RequestSchema>"
      responses:
        "201":
          $ref: "#/components/responses/<ResponseName>"
        "400":
          $ref: "#/components/responses/Error"
        "401":
          $ref: "#/components/responses/Unauthorized"

components:
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

  parameters:
    <ParamName>:
      name: <param>
      in: path | query | header
      required: true
      schema:
        type: <string|integer|...>

  schemas:
    <RequestSchema>:
      type: object
      required: [<field>]
      properties:
        <field>:
          type: <string|integer|...>

    <ResponseSchema>:
      type: object
      required: [<field>]
      properties:
        <field>:
          type: <string|integer|...>

    Error:
      type: object
      required: [code, message]
      properties:
        code:
          type: string
        message:
          type: string
        details:
          type: array
          items:
            type: string

  responses:
    <ResponseName>:
      description: <概要>
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/<ResponseSchema>"

    Error:
      description: Error
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/Error"

    Unauthorized:
      description: Unauthorized
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/Error"

security:
  - BearerAuth: []
~~~

### フォーマット規則

* **OpenAPI バージョン**: 原則 `3.1.0`
* **命名**:
  * `operationId`: `lowerCamelCase`（例: `getUser`, `createOrder`）
  * `schema` / `response` / `parameter` 名: `PascalCase` 推奨（例: `CreateUserRequest`）
* **Schema 再利用**: 重複する構造は必ず `components/schemas` に切り出し、`$ref` で参照
* **レスポンス統一**:
  * 正常系は `200/201/204` を用途に応じて選ぶ
  * 失敗系は `components/responses` に共通化（例: `Error`, `Unauthorized`, `Forbidden`, `NotFound`, `Conflict`）
* **認証/認可**:
  * 全体共通は `security` をルートに置く
  * 例外（公開APIなど）は operation 側で `security: []` を明示
* **トレーサビリティ**（任意）:
  * operation に `x-ids: ["FR-001", "NFR-003"]` のように **IDのみ** を列挙
* **省略ルール**: `（任意）` セクションは該当がない場合、項目ごと削除
* **言語**: 日本語（識別子・コード・列挙値は英語可）

## ワークフロー

### 新規作成

1. 入力から以下を抽出して一覧化する
   * リソース（名詞）/ 操作（GET/POST/PUT/PATCH/DELETE）/ パス / 認証要否
   * リクエスト（path/query/header/body）/ レスポンス（status + body）/ エラーケース
2. `info / servers / tags` を確定し、`paths` を **リソース単位** で並べる。
3. すべての入出力ボディを `components/schemas` に定義し、operation から `$ref` で参照する。
4. 共通レスポンス（`Error` 等）と共通パラメータ（`Id` 等）を `components` に集約する。
5. 認証方式を `components/securitySchemes` に定義し、適用範囲（全体 or operation）を決める。
6. （任意）要件ID を `x-ids` として operation に付与する。

### 既存ファイルへの追記

1. 既存 `openapi.yaml` を読み取り、既存の `paths / components` を **保持** する。
2. 追加/変更対象を **差分** として反映する（既存 operation の `operationId` は原則変更しない）。
3. スキーマ重複が発生する場合は `components/schemas` 側で統合し、参照先を揃える。
4. 互換性に注意して変更を分類する
   * 破壊的: 必須項目追加、型変更、レスポンス形状変更、認証必須化 等
   * 非破壊: 任意項目追加、エラー追加、説明追加 等
5. （任意）`x-ids` の追加・更新を行い、ID のみを列挙する。

## チェックリスト

* [ ] `openapi: 3.1.0` が宣言されている
* [ ] すべての operation に `operationId` があり、重複がない
* [ ] request/response の JSON ボディが `components/schemas` に集約され `$ref` 参照になっている
* [ ] エラー応答が共通化され、最低限 `400/401/403/404/409/500` の方針が一貫している（必要なもののみ）
* [ ] 認証要否が operation 単位で曖昧でない（全体適用 or `security: []` 明示）
* [ ] （任意）`x-ids` が **IDのみ** で記載されている
* [ ] パラメータ（path/query/header）の `required` と `schema` が矛盾していない

## 入力形式

* 自然文: 「ユーザーAPIをOpenAPIにして。JWT認証、/users で一覧と作成」
* 箇条書き:
  * エンドポイント一覧（method, path, summary）
  * リクエスト（params/body）とレスポンス（status/body）例
  * エラーケース（例: 404, 409）
  * 認証方式（例: Bearer JWT, API Key）
  * （任意）関連ID（FR/NFR/ADR 等）
* 既存の `openapi.yaml`（追記/更新指示込み）

## 出力

* ファイル: `openapi.yaml`
* 場所: `docs/specs/interfaces/`

## 使用例

### 例1: 新規作成

**入力**:

> ユーザー管理APIを OpenAPI にして。Bearer JWT 認証。
>
> * GET /users（一覧）
> * POST /users（作成）
> * GET /users/{userId}（詳細）
>   400/401/404 は共通エラーで。

**出力**: `docs/specs/interfaces/openapi.yaml`（`Users` 系 paths と `Error` schema/response を含む）

### 例2: 追記

**入力**:

> 既存の openapi.yaml に PATCH /users/{userId}（部分更新）を追加して。メールアドレス更新のみ。FR-010 に紐付けて。

**出力**: 既存定義を保持しつつ `PATCH /users/{userId}` と `x-ids: ["FR-010"]` を追加した `openapi.yaml`
