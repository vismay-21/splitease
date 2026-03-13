-- SpliTease groups schema + RLS (run in Supabase SQL Editor)

create extension if not exists pgcrypto;
create extension if not exists citext;

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  icon text not null default 'group',
  settlement_status text not null default 'Active',
  created_by uuid not null references auth.users(id) on delete cascade,
  total_expenses numeric(12, 2) not null default 0,
  total_owed numeric(12, 2) not null default 0,
  balance numeric(12, 2) not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text,
  upi_id text,
  role text not null default 'member',
  status text not null default 'active',
  balance numeric(12, 2) not null default 0,
  joined_at timestamptz not null default timezone('utc', now()),
  primary key (group_id, user_id)
);

create table if not exists public.group_invitations (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  inviter_user_id uuid not null references auth.users(id) on delete cascade,
  inviter_name text,
  invitee_email citext not null,
  invitee_name text,
  invitee_upi text,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default timezone('utc', now()),
  responded_at timestamptz
);

alter table public.group_invitations add column if not exists invitee_name text;
alter table public.group_invitations add column if not exists invitee_upi text;
alter table public.group_invitations
  drop constraint if exists group_invitations_group_id_invitee_email_status_key;

with ranked_pending as (
  select id,
         row_number() over (
           partition by group_id, invitee_email
           order by created_at desc, id desc
         ) as rn
  from public.group_invitations
  where status = 'pending'
)
update public.group_invitations gi
set status = 'cancelled',
    responded_at = timezone('utc', now())
from ranked_pending rp
where gi.id = rp.id and rp.rn > 1;

drop index if exists uq_group_invitations_pending;
create unique index uq_group_invitations_pending
  on public.group_invitations(group_id, invitee_email)
  where status = 'pending';

create table if not exists public.group_expenses (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  description text not null,
  amount numeric(12, 2) not null check (amount > 0),
  paid_by_user_id uuid not null references auth.users(id) on delete restrict,
  paid_by_name text,
  expense_date date not null default current_date,
  owes_summary text,
  bill_image_url text,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.group_settlements (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  payer_user_id uuid not null references auth.users(id) on delete restrict,
  receiver_user_id uuid not null references auth.users(id) on delete restrict,
  amount numeric(12, 2) not null check (amount > 0),
  method text not null check (method in ('self', 'upi')),
  status text not null default 'completed' check (status in ('pending', 'completed', 'failed')),
  upi_txn_ref text,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  settled_at timestamptz
);

create index if not exists idx_group_members_user_id on public.group_members(user_id);
create index if not exists idx_group_members_group_id on public.group_members(group_id);
create index if not exists idx_group_invitations_invitee_email on public.group_invitations(invitee_email);
create index if not exists idx_group_invitations_group_id on public.group_invitations(group_id);
create index if not exists idx_group_expenses_group_id on public.group_expenses(group_id);
create index if not exists idx_group_settlements_group_id on public.group_settlements(group_id);

create or replace function public.is_group_member(_group_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return exists (
    select 1
    from public.group_members gm
    where gm.group_id = _group_id and gm.user_id = auth.uid()
  );
end;
$$;

revoke all on function public.is_group_member(uuid) from public;
grant execute on function public.is_group_member(uuid) to authenticated;

create or replace function public.current_user_email()
returns text
language sql
stable
as $$
  select lower(coalesce((auth.jwt() ->> 'email'), ''));
$$;

create or replace function public.is_invited_to_group(_group_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return exists (
    select 1
    from public.group_invitations gi
    where gi.group_id = _group_id
      and lower(gi.invitee_email::text) = public.current_user_email()
      and gi.status in ('pending', 'accepted')
  );
end;
$$;

revoke all on function public.is_invited_to_group(uuid) from public;
grant execute on function public.is_invited_to_group(uuid) to authenticated;

alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_invitations enable row level security;
alter table public.group_expenses enable row level security;
alter table public.group_settlements enable row level security;

grant usage on schema public to anon, authenticated;
grant select on public.groups to authenticated;
grant select, insert, update, delete on public.group_members to authenticated;
grant select, insert, update on public.group_invitations to authenticated;
grant select, insert, update on public.group_expenses to authenticated;
grant select, insert, update on public.group_settlements to authenticated;

drop policy if exists "group members can read groups" on public.groups;
drop policy if exists "signed users can create groups" on public.groups;
drop policy if exists "group creator can update groups" on public.groups;
drop policy if exists "group creator can delete groups" on public.groups;

drop policy if exists "members can read group_members" on public.group_members;
drop policy if exists "creator can add members" on public.group_members;
drop policy if exists "members can update own membership" on public.group_members;
drop policy if exists "creator can update any membership" on public.group_members;
drop policy if exists "members can leave group" on public.group_members;
drop policy if exists "creator can remove members" on public.group_members;

drop policy if exists "invitees and group members can read invitations" on public.group_invitations;
drop policy if exists "group members can send invitations" on public.group_invitations;
drop policy if exists "invitees can accept or decline" on public.group_invitations;
drop policy if exists "inviter can cancel invitation" on public.group_invitations;

drop policy if exists "members can read group_expenses" on public.group_expenses;
drop policy if exists "members can create group_expenses" on public.group_expenses;
drop policy if exists "expense creator can update expense" on public.group_expenses;

drop policy if exists "members can read settlements" on public.group_settlements;
drop policy if exists "payer can create settlements" on public.group_settlements;
drop policy if exists "payer can update own settlements" on public.group_settlements;

-- groups policies
create policy "group members can read groups"
  on public.groups
  for select
  using (public.is_group_member(id) or public.is_invited_to_group(id));

create policy "signed users can create groups"
  on public.groups
  for insert
  with check (auth.uid() is not null and created_by = auth.uid());

create policy "group creator can update groups"
  on public.groups
  for update
  using (created_by = auth.uid())
  with check (created_by = auth.uid());

create policy "group creator can delete groups"
  on public.groups
  for delete
  using (created_by = auth.uid());

-- group_members policies
create policy "members can read group_members"
  on public.group_members
  for select
  using (public.is_group_member(group_id));

create policy "creator can add members"
  on public.group_members
  for insert
  with check (
    exists (
      select 1
      from public.groups g
      where g.id = group_id and g.created_by = auth.uid()
    )
    or (
      user_id = auth.uid()
      and public.is_invited_to_group(group_id)
    )
  );

create policy "members can update own membership"
  on public.group_members
  for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "creator can update any membership"
  on public.group_members
  for update
  using (
    exists (
      select 1
      from public.groups g
      where g.id = group_id and g.created_by = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.groups g
      where g.id = group_id and g.created_by = auth.uid()
    )
  );

create policy "members can leave group"
  on public.group_members
  for delete
  using (user_id = auth.uid());

create policy "creator can remove members"
  on public.group_members
  for delete
  using (
    exists (
      select 1
      from public.groups g
      where g.id = group_id and g.created_by = auth.uid()
    )
  );

-- group_invitations policies
create policy "invitees and group members can read invitations"
  on public.group_invitations
  for select
  using (
    lower(invitee_email::text) = public.current_user_email()
    or public.is_group_member(group_id)
  );

create policy "group members can send invitations"
  on public.group_invitations
  for insert
  with check (public.is_group_member(group_id) and inviter_user_id = auth.uid());

create policy "invitees can accept or decline"
  on public.group_invitations
  for update
  using (lower(invitee_email::text) = public.current_user_email())
  with check (lower(invitee_email::text) = public.current_user_email());

create policy "inviter can cancel invitation"
  on public.group_invitations
  for update
  using (inviter_user_id = auth.uid())
  with check (inviter_user_id = auth.uid());

-- group_expenses policies
create policy "members can read group_expenses"
  on public.group_expenses
  for select
  using (public.is_group_member(group_id));

create policy "members can create group_expenses"
  on public.group_expenses
  for insert
  with check (
    public.is_group_member(group_id)
    and created_by = auth.uid()
    and paid_by_user_id in (
      select gm.user_id from public.group_members gm where gm.group_id = group_id
    )
  );

create policy "expense creator can update expense"
  on public.group_expenses
  for update
  using (created_by = auth.uid())
  with check (created_by = auth.uid());

-- group_settlements policies
create policy "members can read settlements"
  on public.group_settlements
  for select
  using (
    public.is_group_member(group_id)
    or payer_user_id = auth.uid()
    or receiver_user_id = auth.uid()
  );

create policy "payer can create settlements"
  on public.group_settlements
  for insert
  with check (
    payer_user_id = auth.uid()
    and public.is_group_member(group_id)
  );

create policy "payer can update own settlements"
  on public.group_settlements
  for update
  using (payer_user_id = auth.uid())
  with check (payer_user_id = auth.uid());

-- Keep group totals in sync for quick dashboard reads.
create or replace function public.recalculate_group_totals(_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  expenses_total numeric(12, 2);
  settled_total numeric(12, 2);
begin
  select coalesce(sum(amount), 0)
    into expenses_total
    from public.group_expenses
   where group_id = _group_id;

  select coalesce(sum(amount), 0)
    into settled_total
    from public.group_settlements
   where group_id = _group_id and status = 'completed';

  update public.groups
     set total_expenses = expenses_total,
         total_owed = greatest(expenses_total - settled_total, 0),
         balance = expenses_total - settled_total
   where id = _group_id;
end;
$$;

create or replace function public.on_group_expenses_changed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.recalculate_group_totals(coalesce(new.group_id, old.group_id));
  return coalesce(new, old);
end;
$$;

create or replace function public.on_group_settlements_changed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.recalculate_group_totals(coalesce(new.group_id, old.group_id));
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_group_expenses_changed on public.group_expenses;
create trigger trg_group_expenses_changed
after insert or update or delete on public.group_expenses
for each row execute function public.on_group_expenses_changed();

drop trigger if exists trg_group_settlements_changed on public.group_settlements;
create trigger trg_group_settlements_changed
after insert or update or delete on public.group_settlements
for each row execute function public.on_group_settlements_changed();

-- Optional: helper function to bootstrap a group + owner membership quickly.
create or replace function public.create_group_with_owner(
  _name text,
  _icon text default 'group'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_group_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  insert into public.groups (name, icon, created_by)
  values (_name, coalesce(nullif(_icon, ''), 'group'), auth.uid())
  returning id into new_group_id;

  insert into public.group_members (group_id, user_id, display_name, role, status)
  values (new_group_id, auth.uid(), coalesce(auth.jwt() ->> 'email', 'Owner'), 'owner', 'active')
  on conflict (group_id, user_id) do nothing;

  return new_group_id;
end;
$$;

grant execute on function public.create_group_with_owner(text, text) to authenticated;

create or replace function public.add_group_expense_equal_split(
  _group_id uuid,
  _description text,
  _amount numeric,
  _paid_by_user_id uuid,
  _owes_summary text default null,
  _bill_image_url text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_expense_id uuid;
  member_count integer;
  share_per_member numeric(12, 2);
  payer_name text;
  generated_summary text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if _amount is null or _amount <= 0 then
    raise exception 'Amount must be greater than zero';
  end if;

  if not public.is_group_member(_group_id) then
    raise exception 'Only group members can add expenses';
  end if;

  select count(*)
    into member_count
    from public.group_members gm
   where gm.group_id = _group_id and gm.status = 'active';

  if member_count <= 0 then
    raise exception 'No active members found in this group';
  end if;

  select coalesce(gm.display_name, auth.jwt() ->> 'email', 'Member')
    into payer_name
    from public.group_members gm
   where gm.group_id = _group_id and gm.user_id = _paid_by_user_id
   limit 1;

  if payer_name is null then
    raise exception 'Payer is not a member of this group';
  end if;

  share_per_member := round(_amount / member_count::numeric, 2);

  if _owes_summary is null then
    select string_agg(
             format(
               '%s owes %s Rs %s',
               coalesce(gm.display_name, 'Member'),
               payer_name,
               to_char(share_per_member, 'FM999999990.00')
             ),
             ', '
           )
      into generated_summary
      from public.group_members gm
     where gm.group_id = _group_id
       and gm.status = 'active'
       and gm.user_id <> _paid_by_user_id;
  else
    generated_summary := _owes_summary;
  end if;

  insert into public.group_expenses (
    group_id,
    description,
    amount,
    paid_by_user_id,
    paid_by_name,
    expense_date,
    owes_summary,
    bill_image_url,
    created_by
  )
  values (
    _group_id,
    _description,
    _amount,
    _paid_by_user_id,
    payer_name,
    current_date,
    generated_summary,
    _bill_image_url,
    auth.uid()
  )
  returning id into new_expense_id;

  update public.group_members
     set balance = balance + case
       when user_id = _paid_by_user_id then (share_per_member * (member_count - 1))
       else (-share_per_member)
     end
   where group_id = _group_id and status = 'active';

  return new_expense_id;
end;
$$;

revoke all on function public.add_group_expense_equal_split(uuid, text, numeric, uuid, text, text) from public;
grant execute on function public.add_group_expense_equal_split(uuid, text, numeric, uuid, text, text) to authenticated;

create or replace function public.accept_group_invitation(_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  invite_row public.group_invitations%rowtype;
  current_email text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  current_email := public.current_user_email();

  select *
    into invite_row
    from public.group_invitations gi
   where gi.id = _invite_id
   limit 1;

  if not found then
    raise exception 'Invitation not found';
  end if;

  if lower(invite_row.invitee_email::text) <> current_email then
    raise exception 'Invitation does not belong to current user';
  end if;

  if invite_row.status not in ('pending', 'accepted') then
    raise exception 'Invitation is not pending';
  end if;

  insert into public.group_members (group_id, user_id, display_name, upi_id, role, status)
  values (
    invite_row.group_id,
    auth.uid(),
    coalesce(invite_row.invitee_name, auth.jwt() ->> 'email', 'Member'),
    invite_row.invitee_upi,
    'member',
    'active'
  )
  on conflict (group_id, user_id)
  do update
  set display_name = excluded.display_name,
      upi_id = coalesce(excluded.upi_id, public.group_members.upi_id),
      status = 'active';

  update public.group_invitations
     set status = 'accepted',
         responded_at = timezone('utc', now())
   where id = _invite_id;

    update public.group_invitations
      set status = 'cancelled',
        responded_at = timezone('utc', now())
    where group_id = invite_row.group_id
      and lower(invitee_email::text) = lower(invite_row.invitee_email::text)
      and status = 'pending'
      and id <> _invite_id;
end;
$$;

revoke all on function public.accept_group_invitation(uuid) from public;
grant execute on function public.accept_group_invitation(uuid) to authenticated;
