-- Group member directory + add-by-email helpers

create or replace function public.get_group_members_with_email(_group_id uuid)
returns table (
  user_id uuid,
  display_name text,
  email text,
  role text,
  status text
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_group_member(_group_id) then
    raise exception 'Only group members can view member directory';
  end if;

  return query
  select
    gm.user_id,
    coalesce(
      nullif(gm.display_name, ''),
      nullif(au.raw_user_meta_data ->> 'full_name', ''),
      nullif(au.raw_user_meta_data ->> 'name', ''),
      split_part(coalesce(au.email::text, ''), '@', 1),
      'Member'
    ) as display_name,
    lower(coalesce(au.email::text, '')) as email,
    gm.role,
    gm.status
  from public.group_members gm
  left join auth.users au on au.id = gm.user_id
  where gm.group_id = _group_id
    and gm.status = 'active'
  order by
    case when gm.role = 'owner' then 0 else 1 end,
    lower(
      coalesce(
        nullif(gm.display_name, ''),
        nullif(au.raw_user_meta_data ->> 'full_name', ''),
        nullif(au.raw_user_meta_data ->> 'name', ''),
        split_part(coalesce(au.email::text, ''), '@', 1),
        'member'
      )
    );
end;
$$;

revoke all on function public.get_group_members_with_email(uuid) from public;
grant execute on function public.get_group_members_with_email(uuid) to authenticated;

create or replace function public.add_group_member_by_email(
  _group_id uuid,
  _invitee_email text
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  normalized_email text;
  invitee_user_id uuid;
  invitee_name text;
  invitee_upi text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_group_member(_group_id) then
    raise exception 'Only group members can add members';
  end if;

  normalized_email := lower(trim(coalesce(_invitee_email, '')));
  if normalized_email = '' or position('@' in normalized_email) = 0 then
    raise exception 'Enter a valid email address';
  end if;

  select
    au.id,
    coalesce(
      nullif(au.raw_user_meta_data ->> 'full_name', ''),
      nullif(au.raw_user_meta_data ->> 'name', ''),
      split_part(coalesce(au.email::text, ''), '@', 1),
      'Member'
    ),
    nullif(au.raw_user_meta_data ->> 'upi_id', '')
  into invitee_user_id, invitee_name, invitee_upi
  from auth.users au
  where lower(coalesce(au.email::text, '')) = normalized_email
  limit 1;

  if invitee_user_id is null then
    raise exception 'No registered user found with this email';
  end if;

  insert into public.group_members (group_id, user_id, display_name, upi_id, role, status)
  values (_group_id, invitee_user_id, invitee_name, invitee_upi, 'member', 'active')
  on conflict (group_id, user_id)
  do update
  set display_name = coalesce(nullif(excluded.display_name, ''), public.group_members.display_name),
      upi_id = coalesce(nullif(excluded.upi_id, ''), public.group_members.upi_id),
      status = 'active';

  insert into public.group_invitations (
    group_id,
    inviter_user_id,
    inviter_name,
    invitee_email,
    invitee_name,
    invitee_upi,
    status,
    responded_at
  )
  values (
    _group_id,
    auth.uid(),
    coalesce(auth.jwt() ->> 'email', 'Group member'),
    normalized_email,
    invitee_name,
    invitee_upi,
    'accepted',
    timezone('utc', now())
  );
end;
$$;

revoke all on function public.add_group_member_by_email(uuid, text) from public;
grant execute on function public.add_group_member_by_email(uuid, text) to authenticated;
