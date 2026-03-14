alter table public.group_notifications
  drop constraint if exists group_notifications_method_check;

alter table public.group_notifications
  add constraint group_notifications_method_check
  check (method in ('upi', 'cash', 'request'));
