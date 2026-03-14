create table if not exists public.group_notifications (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  sender_name text,
  receiver_user_id uuid not null references auth.users(id) on delete cascade,
  receiver_name text,
  category text not null default 'payment_received_confirmation',
  method text not null check (method in ('upi', 'cash')),
  amount numeric(12, 2) not null check (amount > 0),
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'denied')),
  created_at timestamptz not null default timezone('utc', now()),
  responded_at timestamptz
);

create index if not exists idx_group_notifications_receiver_created
  on public.group_notifications(receiver_user_id, created_at desc);

alter table public.group_notifications enable row level security;

grant select, insert, update on public.group_notifications to authenticated;

drop policy if exists "participants can read notifications" on public.group_notifications;
drop policy if exists "sender can create notifications" on public.group_notifications;
drop policy if exists "receiver can update notifications" on public.group_notifications;

create policy "participants can read notifications"
  on public.group_notifications
  for select
  using (sender_user_id = auth.uid() or receiver_user_id = auth.uid());

create policy "sender can create notifications"
  on public.group_notifications
  for insert
  with check (
    sender_user_id = auth.uid()
    and public.is_group_member(group_id)
    and exists (
      select 1
      from public.group_members gm
      where gm.group_id = group_id and gm.user_id = receiver_user_id
    )
  );

create policy "receiver can update notifications"
  on public.group_notifications
  for update
  using (receiver_user_id = auth.uid())
  with check (receiver_user_id = auth.uid());
