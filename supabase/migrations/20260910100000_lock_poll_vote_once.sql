drop function if exists public.submit_poll_vote(text, text, text);

create function public.submit_poll_vote(
  p_session_id text,
  p_voter_id text,
  p_choice text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  affected_rows integer;
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
  on conflict (session_id, voter_id) do nothing;

  get diagnostics affected_rows = row_count;
  return affected_rows = 1;
end;
$$;

revoke all on function public.submit_poll_vote(text, text, text) from public;
grant execute on function public.submit_poll_vote(text, text, text) to service_role;

