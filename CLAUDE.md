# ナスカン案件管理（nasu-crm）

那須環境技術センター向けの社内案件管理システム。営業の得意先・案件・活動履歴を管理し、案件会議用のサマリーを出力する。

## コミュニケーション

- **ユーザーへの応答はすべて日本語で行う。** チャットの本文だけでなく、確認の質問・選択肢ボタン・作業の要約（次のステップ欄など）もすべて日本語にする。
- 専門用語やコマンド名はそのままでよいが、何を聞いているのか・何をしたのかが日本語で分かるように書く。

## 最優先ルール

- **本番を壊さないことが最優先。** 現在安定運用中。
- **`main` ブランチ = 本番**（GitHub Pages で `main` がそのまま公開される）。
  - `main` への直接コミット・マージ・プッシュは、ユーザーが確認・許可するまで行わない。
  - 作業は `dev` ブランチ（または `dev` から切った作業ブランチ）で行う。
- **秘密情報をリポジトリに含めない。** リポジトリは Public。
  - フロントに置いてよいのは Supabase の **anon key のみ**（`index.html` の `SUPABASE_ANON_KEY`）。
  - `service_role` キー、DB パスワード、個人のメールアドレスやパスワード等は絶対にコミットしない。
  - 権限制御は Supabase の **RLS が本体**。フロントの `role === 'admin'` 判定はボタンの表示切り替えにすぎず、セキュリティ境界ではない。
- DB スキーマ・RLS ポリシーの変更はこのリポジトリの外（Supabase ダッシュボード）で行われる。コード側で新しいカラム・テーブルを前提にする変更は、事前に DB 側の対応が必要な旨をユーザーに伝える。
- 既存データとの互換性を壊さない（例：`activity_type` の保存値 `'訪問'` は表示だけ「打合せ」に変えてある。保存値は変更しない）。

## 構成

- **`index.html` 1ファイルのみ**（HTML / CSS / JS をすべて内包、約3,250行）。ビルド工程・パッケージ管理・テストはなし。
- 外部依存：`@supabase/supabase-js@2`（unpkg から CDN 読み込み、メジャーバージョンのみ指定）。
- バックエンド：Supabase（DB・Auth・RLS）。プロジェクト URL は `index.html` 冒頭の `SUPABASE_URL`。
- 公開 URL：`https://dxnasukan.github.io/nasu-crm`（パスワードリセットの `redirectTo` にも使用）。

### `index.html` の中のおおまかな配置

| 範囲（目安） | 内容 |
|---|---|
| `<style>` 冒頭〜 | CSS 変数（`:root`）、共通部品、印刷用 `@media print`、スマホ対応 `@media (max-width: 768px)`、ログイン画面 |
| `<body>` 前半 | パスワード設定画面 / ログイン画面 / リセット画面 → ヘッダー（ナビ）→ 各ページ（`#page-companies` / `#page-prospects` / `#page-activities` / `#page-meeting`） |
| `<body>` 中盤 | モーダル（得意先 `#company-modal` / 案件 `#prospect-modal` / 活動 `#activity-modal`） |
| `<script>` | Supabase 初期化 → 定数・状態 → 得意先 → 案件 → 活動履歴 → 共通（ユーザー・選択UI・`esc`）→ 案件会議 → 削除処理 → 認証 → 初期ロード |

## 画面

- **案件**（ログイン後のデフォルト）：一覧＋詳細の2ペイン。検索、自分の担当／自分の課／課／担当未設定／ステータスで絞り込み。詳細に活動履歴とステータス変更履歴。
- **案件会議**：失注・対象外（ステータス 8, 9）を除いた案件の一覧。重要度・新規/保持・リピート/スポット・種別・担当・部・課で絞り込み。最終活動日（`STALE_DAYS = 30` 日超で警告）、見込み額の合計・並び替え。印刷（A4横）／CSV（BOM付き UTF-8）／Excel（HTML テーブル形式の `.xls`）出力。
- **得意先**：一覧＋詳細の2ペイン。新規登録・編集・削除は admin のみ表示。ナビ上は控えめな扱い。
- **活動履歴**：ページ（`#page-activities`）は存在するが、現在ヘッダーのナビにはボタンがない。活動の追加・編集は主に案件詳細／得意先詳細から行う。

## データモデル（コードから読み取れる範囲）

| テーブル | 主なカラム・備考 |
|---|---|
| `users` | `id`（= Auth ユーザー ID）, `name`, `department`, `section`, `role`（`'admin'` で管理者） |
| `companies` | `name`, `segment`（官公庁/民間/その他）, `kmc_code`, `status`（active/inactive）, `assigned_to`→users, `notes`。**削除は物理削除** |
| `prospects` | `title`, `company_id`, `status`(1〜9), `expected_amount`, `assigned_to`, `prospect_type`（新規/保持）, `contract_type`（リピート/スポット）, `importance`（A/B/C）, `market_size`（A/B/C = 大/中/小）, `timing_label`, `notes`, `updated_at`, `deleted_at`（**論理削除**） |
| `prospect_categories` | `prospect_id`, `category`（案件種別。保存時に delete → insert で置き換え） |
| `prospect_histories` | `prospect_id`, `changed_by`, `status_from`, `status_to`, `changed_at`（ステータス変更履歴。フロントから insert） |
| `activities` | `company_id`, `prospect_id`, `activity_type`, `activity_date`, `summary`, `next_action`, `assigned_to`, `deleted_at`（**論理削除**）。活動保存時に案件の `updated_at` を更新 |

- 一覧取得では `deleted_at IS NULL` を必ず付けている。新しいクエリでも同様にすること。
- ステータス：1 情報収集中 / 2 アプローチ中 / 3 ヒアリング / 4 設計・積算中 / 5 見積提出 / 6 交渉 / 7 内示・受注確定 / 8 失注 / 9 対象外（`STATUS_LABELS`）。

## 認証

- Supabase Auth（メール＋パスワード）。`signInWithPassword` / `signOut` / `resetPasswordForEmail` / `updateUser`。
- 招待・パスワードリセットのリンクは PKCE（`?code=` → `exchangeCodeForSession`）と旧方式（`#access_token=...&type=invite|recovery` → `setSession`）の両方に対応し、パスワード設定画面を表示する。設定後はサインアウトしてログイン画面へ戻す。
- リロード時は `getSession()` でセッション復元（招待・リセット中はスキップ）。
- 認証まわりは壊すと全員がログインできなくなるため、変更時は特に慎重に。

## コーディング上の注意

- ユーザー入力を HTML に埋め込むときは必ず `esc()`（改行を残すなら `escNl()`）を通す。描画はテンプレート文字列＋`innerHTML` が基本。
- イベントはインライン `onclick` 等で、関数はグローバル定義。関数名を変えるときは HTML 側の呼び出しも検索して直す。
- 既存のスタイル（CSS 変数、`.btn` / `.badge` / `.status-N` / `.importance-X` 等）に合わせる。
- スマホ表示（768px 以下）と印刷レイアウトにも影響がないか確認する。
- 選択肢（ステータス・種別・活動種別など）はフォーム・フィルター・定数の複数箇所に重複して書かれている。追加・変更時は全箇所をそろえる。
- UI の文言・コメントは日本語。

## 動作確認

- ビルド不要。`index.html` をローカルの静的サーバー（例：`npx serve` や `python -m http.server`）で開けば動く。ただし **接続先は本番の Supabase** なので、ローカル確認でもデータの作成・更新・削除は本番データに反映される点に注意。
- パスワードリセット等の `redirectTo` は本番 URL 固定のため、メール経由のフローはローカルでは確認しづらい。

## Git 運用

- 作業ブランチ：`dev`。`main` へは、ユーザーの確認・許可を得てからマージ（PR 推奨）。
- コミット前に差分に秘密情報（`service_role`、`eyJ...` の anon 以外のキー、パスワード等）が含まれていないか確認する。
