-- Nazara: Supabase SQL Editor mein poora paste karke RUN karein

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  username text unique not null,
  bio text default '',
  avatar_url text default ''
);
create table posts (
  id bigserial primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  image_url text not null,
  caption text default '',
  created_at timestamptz default now()
);
create table likes (
  post_id bigint references posts(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  primary key (post_id, user_id)
);
create table comments (
  id bigserial primary key,
  post_id bigint references posts(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  text text not null,
  created_at timestamptz default now()
);
create table follows (
  follower_id uuid references profiles(id) on delete cascade,
  following_id uuid references profiles(id) on delete cascade,
  primary key (follower_id, following_id)
);
create table messages (
  id bigserial primary key,
  sender_id uuid references profiles(id) on delete cascade,
  receiver_id uuid references profiles(id) on delete cascade,
  text text not null,
  created_at timestamptz default now()
);

-- signup par profile khud ban jaye
create function handle_new_user() returns trigger as $$
begin
  insert into profiles (id, username)
  values (new.id, coalesce(new.raw_user_meta_data->>'username', split_part(new.email,'@',1)));
  return new;
end; $$ language plpgsql security definer;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

alter table profiles enable row level security;
alter table posts enable row level security;
alter table likes enable row level security;
alter table comments enable row level security;
alter table follows enable row level security;
alter table messages enable row level security;

create policy "read all" on profiles for select using (true);
create policy "edit own" on profiles for update using (auth.uid() = id);
create policy "read all" on posts for select using (true);
create policy "add own" on posts for insert with check (auth.uid() = user_id);
create policy "delete own" on posts for delete using (auth.uid() = user_id);
create policy "read all" on likes for select using (true);
create policy "add own" on likes for insert with check (auth.uid() = user_id);
create policy "delete own" on likes for delete using (auth.uid() = user_id);
create policy "read all" on comments for select using (true);
create policy "add own" on comments for insert with check (auth.uid() = user_id);
create policy "delete own" on comments for delete using (auth.uid() = user_id);
create policy "read all" on follows for select using (true);
create policy "add own" on follows for insert with check (auth.uid() = follower_id);
create policy "delete own" on follows for delete using (auth.uid() = follower_id);
create policy "read mine" on messages for select using (auth.uid() in (sender_id, receiver_id));
create policy "send own" on messages for insert with check (auth.uid() = sender_id);

-- photos storage
insert into storage.buckets (id, name, public) values ('media','media',true);
create policy "media read" on storage.objects for select using (bucket_id = 'media');
create policy "media upload" on storage.objects for insert to authenticated with check (bucket_id = 'media');

-- live chat
alter publication supabase_realtime add table messages;
