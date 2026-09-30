-- =====================================================================
-- Expense Manager – Supabase database setup
-- Paste this whole file into Supabase → SQL Editor → New query → Run.
-- Safe to run again (it drops and re-creates the policies).
-- Everything the app stores is encrypted in the browser first; these
-- tables only ever hold encrypted text.
-- =====================================================================

-- 1) Private data: one row per user (their own books, notes, settings)
create table if not exists public.vaults (
  user_id    uuid primary key references auth.users on delete cascade,
  data       text not null,                         -- encrypted JSON
  updated_at timestamptz not null default now()
);

-- 2) Shared expense books: one row per shared book
create table if not exists public.shared_books (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references auth.users on delete cascade default auth.uid(),
  owner_email text,
  name        text not null,
  data        text not null,                        -- encrypted JSON
  updated_at  timestamptz not null default now()
);

-- 3) Who a shared book is shared with (by email) and what they may do
create table if not exists public.book_members (
  book_id uuid not null references public.shared_books on delete cascade,
  email   text not null,                            -- lower-case email of the invited person
  role    text not null check (role in ('reader', 'writer')),
  primary key (book_id, email)
);

-- Helpers used by the rules below (security definer avoids rule recursion)
create or replace function public.my_email() returns text
  language sql stable as $$ select lower(coalesce(auth.jwt() ->> 'email', '')) $$;

create or replace function public.is_book_owner(b uuid) returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (select 1 from shared_books where id = b and owner_id = auth.uid())
$$;

create or replace function public.book_role(b uuid) returns text
  language sql stable security definer set search_path = public as $$
  select role from book_members where book_id = b and email = public.my_email()
$$;

-- Row Level Security: nobody can see anything unless a rule below allows it
alter table public.vaults       enable row level security;
alter table public.shared_books enable row level security;
alter table public.book_members enable row level security;

-- vaults: only your own row
drop policy if exists "vault: own row" on public.vaults;
create policy "vault: own row" on public.vaults
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- shared_books
drop policy if exists "book: owner or member can read" on public.shared_books;
create policy "book: owner or member can read" on public.shared_books
  for select using (owner_id = auth.uid() or public.book_role(id) is not null);

drop policy if exists "book: create as owner" on public.shared_books;
create policy "book: create as owner" on public.shared_books
  for insert with check (owner_id = auth.uid());

drop policy if exists "book: owner or editor can update" on public.shared_books;
create policy "book: owner or editor can update" on public.shared_books
  for update using (owner_id = auth.uid() or public.book_role(id) = 'writer')
  with check (owner_id = auth.uid() or public.book_role(id) = 'writer');

drop policy if exists "book: owner can delete" on public.shared_books;
create policy "book: owner can delete" on public.shared_books
  for delete using (owner_id = auth.uid());

-- book_members
drop policy if exists "members: owner sees all, member sees own" on public.book_members;
create policy "members: owner sees all, member sees own" on public.book_members
  for select using (public.is_book_owner(book_id) or email = public.my_email());

drop policy if exists "members: owner adds" on public.book_members;
create policy "members: owner adds" on public.book_members
  for insert with check (public.is_book_owner(book_id));

drop policy if exists "members: owner changes" on public.book_members;
create policy "members: owner changes" on public.book_members
  for update using (public.is_book_owner(book_id)) with check (public.is_book_owner(book_id));

drop policy if exists "members: owner removes, or you leave" on public.book_members;
create policy "members: owner removes, or you leave" on public.book_members
  for delete using (public.is_book_owner(book_id) or email = public.my_email());

-- Live updates (Realtime) for these tables
do $$
begin
  begin alter publication supabase_realtime add table public.vaults;       exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.shared_books; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.book_members; exception when duplicate_object then null; end;
end $$;
