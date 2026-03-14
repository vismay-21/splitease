-- Persist expense + split rows atomically so all group members see the same transactions.

alter table public.group_settlements
  drop constraint if exists group_settlements_method_check;

alter table public.group_settlements
  add constraint group_settlements_method_check
  check (method in ('self', 'upi', 'split'));

create or replace function public.create_group_expense_with_splits(
  _group_id uuid,
  _description text,
  _amount numeric,
  _paid_by_user_id uuid,
  _paid_by_name text,
  _owes_summary text,
  _split_rows jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  _caller uuid;
  _expense_id uuid;
begin
  _caller := auth.uid();
  if _caller is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_group_member(_group_id) then
    raise exception 'Only group members can add expenses';
  end if;

  if _amount is null or _amount <= 0 then
    raise exception 'Amount must be greater than zero';
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.group_id = _group_id and gm.user_id = _paid_by_user_id
  ) then
    raise exception 'Paid-by user must be in the group';
  end if;

  insert into public.group_expenses (
    group_id,
    description,
    amount,
    paid_by_user_id,
    paid_by_name,
    expense_date,
    owes_summary,
    created_by
  )
  values (
    _group_id,
    _description,
    _amount,
    _paid_by_user_id,
    nullif(_paid_by_name, ''),
    current_date,
    nullif(_owes_summary, ''),
    _caller
  )
  returning id into _expense_id;

  if _split_rows is null then
    _split_rows := '[]'::jsonb;
  end if;

  insert into public.group_settlements (
    group_id,
    payer_user_id,
    receiver_user_id,
    amount,
    method,
    status,
    notes
  )
  select
    _group_id,
    (item->>'debtor_user_id')::uuid,
    (item->>'creditor_user_id')::uuid,
    (item->>'amount')::numeric,
    'split',
    'pending',
    'expense_split:' || _expense_id::text
  from jsonb_array_elements(_split_rows) item
  where coalesce((item->>'debtor_user_id'), '') <> ''
    and coalesce((item->>'creditor_user_id'), '') <> ''
    and (item->>'debtor_user_id') <> (item->>'creditor_user_id')
    and coalesce((item->>'amount')::numeric, 0) > 0
    and exists (
      select 1
      from public.group_members gm
      where gm.group_id = _group_id and gm.user_id = (item->>'debtor_user_id')::uuid
    )
    and exists (
      select 1
      from public.group_members gm
      where gm.group_id = _group_id and gm.user_id = (item->>'creditor_user_id')::uuid
    );

  return _expense_id;
end;
$$;

grant execute on function public.create_group_expense_with_splits(
  uuid,
  text,
  numeric,
  uuid,
  text,
  text,
  jsonb
) to authenticated;
