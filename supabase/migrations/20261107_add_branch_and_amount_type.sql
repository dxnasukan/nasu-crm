-- =====================================================================
-- ② 本支店区分 と ③ 見込み金額の区分（単発／継続）を案件に追加する
-- 実行場所：Supabase ダッシュボード → SQL Editor
-- 作成：2026-11-07
--
-- ・項目を「足す」だけの変更。既存のデータや今の画面には影響しない
--   （今の画面は新しい項目を使わないので、DB を先に変更しても問題ない）
-- ・既存の案件は、本支店区分＝空欄（あとで担当者が入力）、金額の区分＝「単発」になる
-- ・行単位の権限（RLS）は変わらない
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. 変更（この部分を実行する）
-- ---------------------------------------------------------------------
alter table public.prospects
  add column if not exists branch text,
  add column if not exists amount_type text not null default '単発';

alter table public.prospects
  drop constraint if exists prospects_branch_check,
  add constraint prospects_branch_check
    check (branch is null or branch in ('本社', '福島支店', '埼玉支店', 'つくば出張所'));

alter table public.prospects
  drop constraint if exists prospects_amount_type_check,
  add constraint prospects_amount_type_check
    check (amount_type in ('単発', '継続'));

comment on column public.prospects.branch is '本支店区分（本社／福島支店／埼玉支店／つくば出張所）。担当課長の振り分けに使う';
comment on column public.prospects.amount_type is '見込み金額の区分（単発／継続）。継続は年額で入力する';


-- ---------------------------------------------------------------------
-- 2. 確認（変更のあとに実行する。2行出れば成功）
-- ---------------------------------------------------------------------
-- select column_name, data_type, is_nullable, column_default
-- from information_schema.columns
-- where table_schema = 'public' and table_name = 'prospects'
--   and column_name in ('branch', 'amount_type');
--
-- 既存の案件がどうなったかの確認（本支店区分はすべて空欄、区分はすべて「単発」になっているはず）
-- select amount_type, branch, count(*) from public.prospects group by 1, 2;


-- ---------------------------------------------------------------------
-- 3. 元に戻すとき（通常は実行しない。入力された本支店区分・区分は消える）
-- ---------------------------------------------------------------------
-- alter table public.prospects
--   drop constraint if exists prospects_branch_check,
--   drop constraint if exists prospects_amount_type_check,
--   drop column if exists branch,
--   drop column if exists amount_type;
