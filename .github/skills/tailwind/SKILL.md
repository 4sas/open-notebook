---
name: implementation
description: |
  本プロジェクト固有の Tailwind UI システムを使用・拡張・更新して、画面・部品・フォーム・状態表現を実装するためのスキル。
  既存の design tokens、@utility、@layer base/components、意味クラス、アクセシビリティ規約を根拠に、必要最小限の差分で UI を実装・修正するときに使う。
  Tailwind の生ユーティリティを場当たり的に HTML へ追加すること、既存トークンを無視した独自スタイルの乱立、根拠のない新規コンポーネント設計には使わない。
---

# Tailwind UI 実装スキル

## 目的（Done定義）

- 既存の Tailwind UI システムの設計思想を維持したまま、画面または UI 部品を実装・更新できている。
- 変更は **既存トークンの活用 → 既存 utility の再利用 → 既存 component の組み合わせ → 必要最小限の拡張** の順で行われている。
- `tailwind/` 配下の責務分離（`theme` / `utilities` / `base` / `components`）を壊していない。
- HTML / TSX / JSX / テンプレート上では、見た目の数値直書きより **意味クラス** と **状態クラス** を優先している。
- hover / focus-visible / disabled / validation / reduced motion / forced colors など、既存 UI システムが前提とする状態表現とアクセシビリティ要件を維持している。
- 成功: 仕様に必要な UI が最小差分で実装され、既存部品との整合性が保たれている。
- 部分成功: 既存トークンや部品だけでは表現できず、最小限の拡張までは完了したが、UI 仕様自体が不足して一部を保守的に留保した。
- 失敗: 既存設計との整合を保った実装ができず、推測でクラスや部品を発明しないと進められない。

## 適用範囲

- 対象タスク:
  - 既存画面への UI 追加・修正
  - 既存コンポーネントの状態追加・サイズ追加・バリアント追加
  - フォーム UI の実装・統一
  - Tailwind ベースの設計済み UI システムへの小規模〜中規模拡張
  - `tailwind/` 配下の CSS と利用側マークアップの両方を伴う UI 実装
- 非対象タスク（使うべきでない）:
  - 新規デザインシステムの全面再設計
  - 既存トークン体系を捨てる大規模リブランド
  - 単なる見た目の思いつきによるクラス追加
  - JavaScript の複雑な状態管理や業務ロジックが主題の変更
  - Tailwind と無関係な CSS フレームワークへの移行

## 設計原則

- **KISS**: まず既存の部品とトークンの組み合わせで解く。複雑な抽象化は最後に検討する。
- **DRY**: 同じ見た目・同じ状態遷移・同じアクセシビリティ処理を複数箇所へ重複定義しない。
- **YAGNI**: 現在必要な variant / size / state だけを追加する。将来用の汎用フックや未使用トークンを先回りで作らない。
- **Token First**: 色・余白・半径・影・duration・z-index は既存変数を優先し、値の直書きを避ける。
- **Semantic First**: 利用側には `.button-primary`、`.alert-error`、`.form-group.has-error` のような意味クラスを優先する。
- **Low Specificity**: `:where(...)`、`@layer`、`@utility` を活かし、特異性競争を起こさない。
- **Accessible by Default**: `:focus-visible`、`prefers-reduced-motion`、`forced-colors`、disabled、readonly、validation を標準要件として扱う。
- **Native Respect**: checkbox / radio / select / date / range などは、ネイティブ要素の意味と挙動を活かしながら必要最小限だけ再構築する。

## この Tailwind システムの前提

### レイヤ責務

- `tailwind/theme/`
  - design tokens を定義する層。
  - 色・余白・タイポグラフィ・影・z-index・アニメーションなどの基準値を置く。
- `tailwind/utilities/`
  - `@utility` による再利用単位を定義する層。
  - component の骨格・サイズ・variant・レイアウト・フォーム共通部品をここで作る。
- `tailwind/base/`
  - 要素セレクタや共通状態を標準化する層。
  - form 要素、table、list、typography、section などの土台を扱う。
- `tailwind/components/`
  - アプリで直接使う意味クラスを定義する層。
  - `.button-*`、`.badge-*`、`.alert-*`、`.tab`、`.notification-*` などを置く。

### 実装順序

1. 既存 component を探す。
2. 無ければ既存 utility の組み合わせで表現できるか確認する。
3. 無ければ既存 token の範囲で utility を拡張する。
4. それでも足りない場合のみ、新しい component クラスを追加する。
5. token の追加は最終手段とし、既存命名体系へ揃える。

### 命名方針

- component は **意味名** を使う。
  - 例: `.button-primary`, `.alert-success`, `.section-warning`
- utility は **骨格 / variant / size / layout / state 補助** を表す。
  - 例: `button-base`, `button-size-sm`, `badge-variant-success`
- state は **既存規約に寄せる**。
  - 例: `.active`, `.disabled`, `.is-invalid`, `.is-valid`, `.has-error`, `.collapsed`
- wrapper が必要な場合は **用途が分かる名前** を使う。
  - 例: `.week-input-wrapper`, `.month-input-wrapper`, `.color-input-wrapper`

## 入力

- 必須:
  - 対象画面または対象部品
  - 期待する UI 変更内容
  - 既存ファイルまたは変更対象パス
- 任意:
  - UI 仕様書、受入基準、デザインモック
  - 使用可能な既存 component / utility の指定
  - 状態要件（hover / focus / disabled / error / success / loading など）
  - responsive 要件
  - アクセシビリティ要件
- 不足時の扱い:
  - **読む**: まず既存 `tailwind/` と利用側マークアップから再利用可能な部品を確認する。
  - **保守的に仮定する**: 未指定の色・余白・角丸・影は既存 token / variant に合わせる。
  - **中断する**: 既存規約と矛盾する新規 UI 構造を推測で発明しないと成立しない場合。

## 状態モデル（State）

- `state.request.target`
  - 画面 / 部品 / フォーム / テーブル / ナビゲーション等
- `state.inventory.tokens`
  - 利用可能な色・余白・影・半径・duration・z-index
- `state.inventory.utilities`
  - 再利用可能な `@utility`
- `state.inventory.components`
  - 再利用可能な意味クラス
- `state.plan.level`
  - `reuse-only` | `utility-extend` | `component-extend` | `token-extend`
- `state.a11y`
  - focus-visible / keyboard / disabled / reduced-motion / forced-colors / validation
- `state.outputs.files`
  - 変更した CSS / markup / script / test の一覧
- 不変条件（Invariants）:
  - 既存 token で表現できるものを直値で増やさない。
  - 同じ UI 意味に対して別名クラスを増殖させない。
  - `base` に画面固有スタイルを書かない。
  - `components` に token の直値を大量に埋め込まない。
  - キーボードフォーカス可視性を消さない。

## 実行モデル（Control）

- 方式: 既存資産の棚卸し → 再利用優先判定 → 最小差分実装 → 状態確認 → 整合性確認
- 停止条件:
  - 既存設計を壊さずに対象 UI が実装できた時点で終了
- 再計画条件:
  - 既存 component の流用が困難
  - utility の責務に置くべきか component の責務に置くべきかが途中で変わった
  - 新しい wrapper や state class が必要だと判明した
- 分岐条件:
  - **既存 class のみで実装可能**: 利用側のマークアップ変更だけ行う
  - **既存 utility はあるが意味クラスがない**: `components/` に薄いラッパーを追加する
  - **骨格自体が不足**: `utilities/` に共通骨格を追加し、必要最小限の `components/` を追加する
  - **トークン不足**: 命名規約を維持できる場合のみ `theme/` を拡張する

## 実装ルール

### 1. 既存部品の再利用を最優先する

- `.button-*`、`.badge-*`、`.alert-*`、`.card-*`、`.tab`、`.notification-*`、`.section-*` などの既存 component を優先して使う。
- 近い部品がある場合、別名の新規部品を作らず、既存 component に variant / size / state を追加する。

### 2. HTML / テンプレートへ生ユーティリティを散らしすぎない

- レイアウト調整や局所的な補助は許容する。
- ただし、配色・状態・部品骨格まで毎回ユーティリティ直書きで組み立てない。
- 同じ class 群が 2 箇所以上で出るなら `@utility` か `components` へ引き上げる。

### 3. 追加場所の判断基準を守る

- `theme/`: 新しい design token が本当に必要な場合のみ
- `utilities/`: 複数 component で再利用する骨格・size・variant
- `base/`: 要素標準化、フォーム共通状態、タイポグラフィなど横断土台
- `components/`: アプリ利用側が直接使う意味クラス

### 4. state 設計を先に揃える

- hover / focus-visible / active / open / disabled / readonly / invalid / valid / loading を先に洗い出す。
- state ごとの class 名、擬似クラス、ARIA 属性、data 属性のどれで表現するかを統一する。
- `:focus` だけで終わらせず、原則 `:focus-visible` を用いる。

### 5. フォームは既存ルールに合わせる

- text / search / number / email / password / url / textarea / select / date / time / datetime-local / week / month は、既存の form-field 系 utility と state を優先して使う。
- validation は `.is-invalid` / `.is-valid`、wrapper 系は `.form-group`, `.form-validating`, `.required-field` など既存規約へ寄せる。
- checkbox / radio / range のようなネイティブ再構築済み部品は、見た目だけ別実装しない。

### 6. wrapper 追加は必要性が明確な場合だけにする

- 擬似要素を input 自体へ描けないケースや、focus ring を親で出す必要があるケースに限定する。
- wrapper 追加時は、利用方法をコメントまたは実装例で残す。

### 7. responsive は既存 breakpoint に従う

- breakpoint 名や使い方は既存 `theme/breakpoints.css` と `@variant` 規約へ揃える。
- 同じ component で breakpoint ごとに責務が変わる場合、まず layout utility で吸収できるか確認する。

### 8. アニメーションは控えめにする

- motion は既存 `--ui-duration-*`、`--ease-*`、`--animate-*` を使う。
- hover の scale や transition は、意味がある場合に限定する。
- `prefers-reduced-motion: reduce` では停止または簡略化する。

### 9. 高コントラスト・強制色を壊さない

- `forced-colors` 対応済みの部品では、追加変更でも同等レベルの対応を維持する。
- data URI のアイコンや背景画像が読めなくなる場合は代替を用意するか無効化する。

### 10. 直値の使用条件を限定する

- 既存 token に存在しないが、単発でしか使わず utility 化も不要な値に限り許容する。
- 2 回以上出る見込みがある場合は token または utility 化を検討する。

## 推奨ワークフロー

### 新規 UI 作成

1. 要件から、必要な UI を **画面 / セクション / 部品 / 状態** に分解する。
2. `tailwind/components/` と `tailwind/utilities/` を確認し、再利用候補を列挙する。
3. 利用側マークアップを、まず既存 component class だけで組み立てる。
4. 足りない表現がある場合のみ、utility 追加か component 拡張かを判断する。
5. hover / focus-visible / disabled / error / success / loading / responsive を埋める。
6. reduced motion / forced colors / keyboard 操作の破綻がないか確認する。
7. 同種 UI が他にも出るなら、重複を utility か component に吸い上げる。
8. 変更ファイルを最小差分で出力する。

### 既存 UI 更新

1. 既存 class 構成と token 依存を読む。
2. 変更要求を **見た目変更 / 状態追加 / variant 追加 / layout 修正 / a11y 修正** に分解する。
3. 既存命名と責務を壊さない最小差分で反映する。
4. 既存 component と utility の意味が変わる変更は避け、必要なら新 variant を追加する。
5. 既存利用箇所へ波及する場合は、破壊的変更ではなく後方互換を優先する。

### 新しい component を追加する場合

1. 既存 component で代替できないことを確認する。
2. まず共通骨格を `utilities/` に置けるか判断する。
3. 利用側が直接使う最小限の意味クラスだけを `components/` に作る。
4. 色・余白・角丸・影は token から参照する。
5. active / hover / focus-visible / disabled / responsive / reduced-motion を揃える。
6. 近い既存 component と naming / state / variant 表現を合わせる。

## 禁止事項

- HTML / TSX 内へ大量の見た目ユーティリティを重複記述すること
- `!important` に頼ること
- token で管理すべき色・余白・影・duration を component へ直書きすること
- `outline: none` を入れて focus-visible を補わないこと
- `base/` に画面専用クラスを書くこと
- 類似 component を別名で乱立させること
- 未使用の将来拡張 variant / size / state を先回りで追加すること
- 既存 class の意味を黙って変更すること

## エラー処理（Recovery）

- エラー分類:
  - 再利用候補の見落とし
  - token 不足
  - utility / component の責務誤り
  - state 漏れ
  - アクセシビリティ不備
  - 既存 UI への破壊的影響
- リトライ:
  - まず component 追加を取り消し、既存 utility / component で再構成できないか 1 回だけ見直す
  - token 追加前に、既存 token の再利用余地を 1 回だけ見直す
- フォールバック:
  - 既存設計へ素直に乗らない要求は、追加 variant や wrapper で局所化する
  - 大規模な抽象化が必要な場合は、このスキルではなく上位の設計更新へ戻す

## チェックリスト

- [ ] 既存 component / utility / token の再利用を先に検討した
- [ ] 変更箇所が `theme` / `utilities` / `base` / `components` の責務に合っている
- [ ] 利用側は意味クラス中心で読みやすい
- [ ] hover / focus-visible / disabled / validation / loading の状態が揃っている
- [ ] `prefers-reduced-motion` と `forced-colors` の配慮を壊していない
- [ ] ネイティブ要素の意味・操作性を失っていない
- [ ] 既存 class の意味を破壊せず、最小差分で更新している
- [ ] 直値追加が本当に必要最小限である
- [ ] UTF-8（BOMなし）/ LF 前提で扱える内容になっている

## 入力形式

- 自然文:
  - 「既存の card / section / button を使って、検索結果一覧 UI を追加して」
  - 「フォームの validation 表現をこの Tailwind 規約に合わせて修正して」
  - 「badge に muted variant を追加して利用画面も更新して」
- 箇条書き:
  - 対象画面 / 対象部品
  - 期待する見た目
  - 必要な状態
  - 既存ファイル
  - 変更可否範囲
- 既存コード + 変更指示:
  - `tailwind/**`
  - `**/*.{html,tsx,jsx,vue}`
  - テストや Story 相当ファイル（存在する場合）

## 出力

- 変更ファイル:
  - `tailwind/theme/*.css`
  - `tailwind/utilities/**/*.css`
  - `tailwind/base/**/*.css`
  - `tailwind/components/**/*.css`
  - 利用側の画面 / 部品ファイル
- 出力内容:
  - 最小差分の実装
  - 必要なら利用例の class 構成
  - 必要なら追加 state / wrapper の説明

## 使用例

### 例1: 既存部品だけで画面を作る

**入力**:
> 既存の `card`、`section`、`button-primary`、`pagination` を使って一覧画面を実装して。新規 token や component は増やさない。

**出力**:
> 既存 component class のみで組み立てた画面マークアップと、必要最小限の layout 調整

### 例2: 既存 component に variant を追加する

**入力**:
> `badge` に `muted` 系の見た目を追加して。既存 variant の命名規則は維持し、利用側画面も更新して。

**出力**:
> `utilities/components/badges.css` と `components/badges.css` の最小差分、および利用側マークアップ更新

### 例3: フォーム UI を規約へ寄せる

**入力**:
> ばらばらな input / select / validation 表現を、この Tailwind の form 規約に揃えて更新して。キーボードフォーカスと disabled も見直して。

**出力**:
> 既存 form-field 系 utility と state class を使う形へ寄せた CSS / markup 差分

### 例4: 新しい部品を最小拡張で追加する

**入力**:
> 既存部品では足りないので、 dismiss 可能な info banner を追加して。alert と notification の命名・状態設計に合わせて。

**出力**:
> 既存 alert / notification の設計を踏襲した utility / component 追加と利用側の実装差分
