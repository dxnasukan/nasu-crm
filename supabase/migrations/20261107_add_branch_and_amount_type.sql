-- =====================================================================
-- ② 本支店区分 と ③ 見込み金額の区分（単発／継続）を案件に設定する
-- 実行場所：Supabase ダッシュボード → SQL Editor
-- 作成：2026-11-07
--
-- 前提（2026-11-07 に確認）：
-- ・prospects.branch（text）は以前から存在していた。62件中59件が空欄で、
--   値は「本社」「つくば出張所」「宇都宮営業課」が1件ずつ。これを本支店区分として使う
-- ・「宇都宮営業課」は本支店区分では「本社」に当たる（ユーザー確認済み）
-- ・prospects.amount_type は存在しない（新しく足す）
--
-- 影響：
-- ・branch が「宇都宮営業課」の1件が「本社」に変わる。それ以外の既存データは変わらない
-- ・今の画面は branch / amount_type を使っていないので、DB を先に変更しても問題ない
-- ・既存の案件の amount_type はすべて「単発」になる
-- ・行単位の権限（RLS）は変わらない
-- ・SQL Editor は全体を1つの処理として実行するので、途中でエラーになれば全部取り消される
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. 変更（この部分を実行する）
-- ---------------------------------------------------------------------

-- 本支店区分：既存の値を4区分にそろえてから、4区分以外は入れられないようにする
update public.prospects set branch = '本社' where branch = '宇都宮営業課';

alter table public.prospects
  drop constraint if exists prospects_branch_check,
  add constraint prospects_branch_check
    check (branch is null or branch in ('本社', '福島支店', '埼玉支店', 'つくば出張所'));

-- 見込み金額の区分：新しく足す（既存の案件は「単発」）
alter table public.prospects
  add column if not exists amount_type text not null default '単発';

alter table public.prospects
  drop constraint if exists prospects_amount_type_check,
  add constraint prospects_amount_type_check
    check (amount_type in ('単発', '継続'));

comment on column public.prospects.branch is '本支店区分（本社／福島支店／埼玉支店／つくば出張所）。担当課長の振り分けに使う';
comment on column public.prospects.amount_type is '見込み金額の区分（単発／継続）。継続は年額で入力する';


-- ---------------------------------------------------------------------
-- 2. 確認（変更のあとに実行する）
-- ---------------------------------------------------------------------
-- amount_type が1行出れば成功
-- select column_name, data_type, is_nullable, column_default
-- from information_schema.columns
-- where table_schema = 'public' and table_name = 'prospects'
--   and column_name in ('branch', 'amount_type');
--
-- 既存の案件の状態（本社2件・つくば出張所1件・空欄59件、区分はすべて「単発」になっているはず）
-- select amount_type, branch, count(*) from public.prospects group by 1, 2 order by 2;


-- ---------------------------------------------------------------------
-- 3. 元に戻すとき（通常は実行しない）
--    branch 列は以前からあったので消さない。制限だけ外す。
--    「宇都宮営業課」→「本社」の書き換えは元に戻さない（どの1件だったかは記録していないため）
-- ---------------------------------------------------------------------
-- alter table public.prospects
--   drop constraint if exists prospects_branch_check,
--   drop constraint if exists prospects_amount_type_check,
--   drop column if exists amount_type;
