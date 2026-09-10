create table if not exists public.poll_votes (
  session_id text not null,
  voter_id text not null,
  choice text not null check (choice in ('topic', 'learner', 'content', 'interaction', 'delivery')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (session_id, voter_id),
  constraint poll_votes_session_length check (char_length(session_id) between 6 and 80),
  constraint poll_votes_voter_length check (char_length(voter_id) between 6 and 120)
);

create index if not exists poll_votes_session_idx
  on public.poll_votes (session_id);

alter table public.poll_votes enable row level security;

revoke all on table public.poll_votes from anon, authenticated;

create or replace function public.submit_poll_vote(
  p_session_id text,
  p_voter_id text,
  p_choice text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if char_length(p_session_id) not between 6 and 80 then
    raise exception 'invalid session';
  end if;
  if char_length(p_voter_id) not between 6 and 120 then
    raise exception 'invalid voter';
  end if;
  if p_choice not in ('topic', 'learner', 'content', 'interaction', 'delivery') then
    raise exception 'invalid choice';
  end if;

  insert into public.poll_votes (session_id, voter_id, choice)
  values (p_session_id, p_voter_id, p_choice)
  on conflict (session_id, voter_id)
  do update set
    choice = excluded.choice,
    updated_at = now();
end;
$$;

create or replace function public.get_poll_results(p_session_id text)
returns table(choice text, vote_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select v.choice, count(*)::bigint
  from public.poll_votes v
  where v.session_id = p_session_id
  group by v.choice;
$$;

revoke all on function public.submit_poll_vote(text, text, text) from public;
revoke all on function public.get_poll_results(text) from public;

grant execute on function public.submit_poll_vote(text, text, text) to service_role;
grant execute on function public.get_poll_results(text) to service_role;


