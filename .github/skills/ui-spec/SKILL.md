---
name: ui-spec
description: |
    UI仕様書（画面構成・UI要素・イベント・状態・API連携）を新規作成または更新するスキル。
    画面単位の仕様を整理し、UIとFR/AC/APIのトレーサビリティを確立する際に使用する。
    APIや要件の定義のみを行う場合は使用しない。
---

# UI仕様書生成スキル

## 目的

画面単位のUI仕様書を生成・更新し、**画面構成・UI要素・イベント・状態遷移・API連携**を一貫した形式で整理する。
出力物は `SCR-NNN_<NAME>.md` 形式のUI仕様書。

## [出力テンプレート](../../../docs/templates/SCR-NNN_XXX.md)

~~~md
# SCR-NNN <画面論理名>

- **URIパス**:
  - <例: `/client-list`, `/prompt-template-form`, `/screen-path/{id}` など>

---

## レイアウト

- <要素ID>
- <要素ID>
  - <要素ID>
    - <要素ID>

---

## 要素一覧

- **要素ID**: SCR-NNN-<TYPE>-<NAME>
  - **種別**: <例: フォーム>
  - **名称**: <例: 要素論理名>
  - **Refs**（任意）:
    - AC-FR-NNN
- **要素ID**: <例: SCR-NNN-TXT-SYSTEM_SEARCH>
  - **種別**: <例: テキストインプット>
  - **名称**: <例: 利用システム検索>
  - **Refs**（任意）:
    - AC-FR-NNN

---

## イベント

### EV-SCR-NNN-<NAME> <イベント名>

- **トリガー**: 初期表示
- **処理**:
  1. <OpenAPIのoperationId>
  2. STATE-SCR-NNN-nn
- **Refs**（任意）:
  - AC-FR-NNN-nn
  - ...

### <例: EV-SCR-001-CREATE> <例: 作成画面へ遷移>

- **トリガー**: <例: クリック(SCR-NNN-BTN-CREATE)>
- **処理**:
  1. ...
  2. <例: SCR-NNN-CLIENT_CREATE へ遷移>
- **Refs**（任意）:
  - AC-FR-NNN-nn
  - ...

---

## 状態

### STATE-SCR-NNN-<NAME> <状態名>

- **UI**:
  - <要素ID>: ...
- **遷移**（任意）:
  - 成功: STATE-SCR-NNN-XXX
  - 失敗: STATE-SCR-NNN-XXX

### <例: STATE-SCR-001-LOADING> <例: ローディング中>

- **UI**:
  - <例: SCR-NNN-MSG-LOADING>: 表示
  - <例: SCR-NNN-TBL-CLIENTS>: 非表示
- **遷移**:
  - 成功: STATE-SCR-NNN-XXX
  - 失敗: STATE-SCR-NNN-XXX

---

## API連携

- <OpenAPIのoperationId>
  - request:
    - <ParamName>: <要素ID>
    - systemId: <例: SCR-NNN-DDL-SYSTEM>
  - response:
    - <要素ID>: <API Field>
    - <例: SCR-NNN-TBL-CLIENTS>: clients
    - ...: ...
  - error:
    - 400: <例: STATE-SCR-001-VALIDATION_ERROR>
    - 404: <例: STATE-SCR-001-NOT_FOUND>
    - 500: <例: STATE-SCR-001-SYSTEM_ERROR>
- ...
  - ...: ...
  - ...: ...
~~~

### フォーマット規則

* **画面ID体系**: `SCR-NNN`（3桁ゼロ埋め）
* **要素TYPE**:
  * `BTN` ボタン
  * `TXT` テキスト入力
  * `DDL` ドロップダウン
  * `LBL` ラベル
  * `TBL` テーブル
  * `ROW` テーブル行
  * `COL` テーブル列
  * `MSG` メッセージ
  * `FRM` フォーム
  * `SEC` セクション
  * `MOD` モーダル
* **省略ルール**: `（任意）` セクションは該当がない場合、項目ごと削除
* **言語**: 日本語（識別子・コード・API名は英語可）

## ワークフロー

### 新規作成

1. 入力から以下を抽出する
   * 画面名
   * URI
   * UI要素
   * ユーザー操作
   * API呼び出し
2. `SCR-NNN` を採番する。
3. UI構造を **レイアウト → 要素一覧 → イベント → 状態 → API連携** の順で整理する。
4. 不要セクションを削除して仕様書を生成する。

### 既存ファイルへの追記

1. 既存 `SCR-NNN_*.md` を読み込み既存要素を確認する。
2. 新しいUI要素・イベント・状態のみ追記する。
3. **既存IDは変更しない**。

## チェックリスト

* [ ] 画面IDが `SCR-NNN` 形式（3桁ゼロ埋め）
* [ ] UI要素IDが `SCR-NNN-TYPE-NAME` 形式
* [ ] イベントIDが `EV-SCR-NNN-*` 形式
* [ ] 状態IDが `STATE-SCR-NNN-*` 形式
* [ ] OpenAPI `operationId` が正しく参照されている
* [ ] Refs が ID のみで記述されている
* [ ] 既存仕様更新時に既存エントリを破壊していない

## 入力形式

* 自然文
  * 「顧客一覧画面のUI仕様書を作って」
* 箇条書き
  * 画面名
  * URI
  * UI要素
  * API
  * 操作イベント
* 既存 UI仕様書 + 変更指示

## 出力

* **場所**: `docs/specs/ui/`
* **ファイル**: `SCR-NNN_XXX.md`

## 使用例

### 例1: 新規作成

**入力**:

> 顧客一覧画面のUI仕様書を作って。
> URI `/clients`。
> テーブルで顧客一覧表示。
> 「作成」ボタンで顧客作成画面へ遷移。

**出力**: `SCR-001_client_list.md`

### 例2: 追記

**入力**:

> 既存の `SCR-001_client_list.md` に「顧客検索フィールド」を追加して

**出力**: 既存内容を保持しつつ検索入力UI・イベントを追加した `SCR-001_client_list.md`
