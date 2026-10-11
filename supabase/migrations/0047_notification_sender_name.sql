-- Keep the sender's display name with an in-app notification so the recipient
-- sees the trainer/member who sent it instead of a hard-coded "Admin" label.
alter table public.notifications
  add column if not exists sender_name text;

comment on column public.notifications.sender_name is
  'Display name of the user who sent the notification; null for system notifications.';
