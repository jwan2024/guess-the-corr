-- Alphabet Correlations: one row per player name, holding their saved guesses and final score.
-- Paste into Supabase > SQL Editor and press Run. Safe to run again.

drop table if exists public.scores;  -- from the earlier one-row-per-game draft

create table if not exists public.players (
  id          text primary key check (id = lower(id)),          -- lower-cased name, so "Jess" and "jess" are one player
  name        text not null check (char_length(name) between 1 and 24 and lower(name) = id),
  seed        bigint not null,
  guesses     jsonb not null check (jsonb_typeof(guesses) = 'array' and jsonb_array_length(guesses) = 26),
  finished    boolean not null default false,
  mse         double precision check (mse between 0 and 4),
  mae         double precision check (mae between 0 and 2),
  score       integer check (score between 0 and 2600),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists players_board on public.players (seed, finished, mse);

-- Guesses are permanent once made, and a finished run is locked.
create or replace function public.players_guard() returns trigger
language plpgsql as $$
declare i int;
begin
  for i in 0..25 loop
    if new.guesses->>i is not null and (jsonb_typeof(new.guesses->i) <> 'number' or abs((new.guesses->>i)::numeric) > 1) then
      raise exception 'guess % must be a number between -1 and 1', i;
    end if;
  end loop;
  if tg_op = 'INSERT' then
    new.finished := false; new.mse := null; new.mae := null; new.score := null;
    new.created_at := now(); new.updated_at := now();
    return new;
  end if;
  if old.finished then raise exception 'this run is finished and locked'; end if;
  if new.id <> old.id or new.name <> old.name or new.seed <> old.seed or new.created_at <> old.created_at then
    raise exception 'name and quiz cannot change';
  end if;
  for i in 0..25 loop
    if old.guesses->>i is not null and (new.guesses->i) is distinct from (old.guesses->i) then
      raise exception 'guess % is already locked in', i;
    end if;
  end loop;
  if new.finished and (new.mse is null or exists (select 1 from jsonb_array_elements(new.guesses) g where g = 'null'::jsonb)) then
    raise exception 'a run can only finish with all 26 guesses and a score';
  end if;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists players_guard on public.players;
create trigger players_guard before insert or update on public.players
for each row execute function public.players_guard();

-- The public key may read the board, create a player, and add guesses. No deletes.
alter table public.players enable row level security;
revoke all on public.players from anon;
grant select, insert, update on public.players to anon;

drop policy if exists "read players" on public.players;
create policy "read players" on public.players for select to anon using (true);
drop policy if exists "create player" on public.players;
create policy "create player" on public.players for insert to anon with check (true);
drop policy if exists "save guesses" on public.players;
create policy "save guesses" on public.players for update to anon using (true) with check (true);
