-- Balagh: allow anonymous report submission from the public web page.
-- Safe to run more than once. It only ADDS things. It does not change or drop
-- any existing table, policy, user or data.
-- Run in: Supabase dashboard > your project > SQL Editor > New query > paste > Run.

-- 1) Remember where a report came from ('app' for staff, 'web' for the public page).
alter table public.reports add column if not exists submitted_via text default 'app';

-- 2) One controlled door for anonymous submissions (no direct table access for anon).
create or replace function public.submit_web_report(p jsonb)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v jsonb;
  fid uuid;
  img text;
  no_out integer;
  sev text;
  base text := 'https://acjppgaihurqhyvulyuf.supabase.co/storage/v1/object/public/report-photos/web_';
begin
  fid := (p->>'factory_id')::uuid;
  if not exists (select 1 from public.factories where id = fid) then
    raise exception 'unknown factory';
  end if;
  img := p->>'image_url';
  if img is null or left(img, length(base)) <> base or length(img) > 300 then
    raise exception 'bad image';
  end if;
  sev := coalesce(p->>'severity', 'Medium');
  if sev not in ('Low', 'Medium', 'High') then sev := 'Medium'; end if;
  if coalesce(length(p->>'location'), 0) = 0 or length(p->>'location') > 120
     or coalesce(length(p->>'type'), 0) = 0 or length(p->>'type') > 120
     or length(coalesce(p->>'description', '')) > 2000
     or length(coalesce(p->>'reporter', '')) > 80
     or length(coalesce(p->>'responsibility', '')) > 120 then
    raise exception 'bad fields';
  end if;
  -- simple flood guard: at most 60 web reports per hour overall
  if (select count(*) from public.reports
        where submitted_via = 'web' and created_at > now() - interval '1 hour') >= 60 then
    raise exception 'too many reports, try later';
  end if;

  v := jsonb_build_object(
    'id', coalesce(p->>'id', gen_random_uuid()::text),
    'created_at', now(),
    'updated_at', now(),
    'factory_id', fid,
    'location', p->>'location',
    'type', p->>'type',
    'responsibility', coalesce(p->>'responsibility', ''),
    'severity', sev,
    'description', coalesce(p->>'description', ''),
    'impacts', coalesce(p->'impacts', '[]'::jsonb),
    'reporter', coalesce(nullif(p->>'reporter', ''), 'Web'),
    'status', 'Open',
    'lat', p->'lat',
    'lng', p->'lng',
    'image_url', img,
    'submitted_via', 'web'
  );

  execute 'insert into public.reports (id, created_at, updated_at, factory_id, location, type, responsibility, severity, description, impacts, reporter, status, lat, lng, image_url, submitted_via) '
       || 'select id, created_at, updated_at, factory_id, location, type, responsibility, severity, description, impacts, reporter, status, lat, lng, image_url, submitted_via '
       || 'from jsonb_populate_record(null::public.reports, $1) returning factory_no'
  into no_out using v;
  return no_out;
end;
$$;

revoke all on function public.submit_web_report(jsonb) from public;
grant execute on function public.submit_web_report(jsonb) to anon, authenticated;

-- 3) Let anonymous visitors upload ONLY a photo named web_*.jpg/png/webp into report-photos.
drop policy if exists "web anon photo upload" on storage.objects;
create policy "web anon photo upload" on storage.objects
  for insert to anon
  with check (
    bucket_id = 'report-photos'
    and name like 'web\_%'
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

-- Cap photo size at 10 MB (only lowers an unset or larger limit).
update storage.buckets set file_size_limit = 10485760
 where id = 'report-photos' and (file_size_limit is null or file_size_limit > 10485760);

-- Done. You should see "Success. No rows returned".
