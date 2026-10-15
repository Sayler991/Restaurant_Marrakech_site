-- =====================================================================
--  Restaurant Marrakech (Tlemcen) — contenu, réservations de table, messages, clients
--  Isolé dans le schéma « marrakech » du projet Supabase partagé.
--  Ne modifie AUCUN objet des schémas public / ibis / dupre. Idempotent.
--  Propriétaire : public.owners / public.is_owner() (déjà existants).
--  Après exécution : ajouter « marrakech » aux schémas exposés (PATCH /postgrest).
-- =====================================================================
create schema if not exists marrakech;
grant usage on schema marrakech to anon, authenticated, service_role;

-- 1. CONTENU + HISTORIQUE ---------------------------------------------
create table if not exists marrakech.site_content (
  id integer primary key default 1 check (id = 1),
  data jsonb not null check (jsonb_typeof(data) = 'object') check (octet_length(data::text) <= 524288),
  updated_at timestamptz not null default now(),
  updated_by uuid
);
create table if not exists marrakech.site_content_history (
  id bigint generated always as identity primary key,
  saved_at timestamptz not null default now(),
  saved_by uuid,
  data jsonb not null
);
create or replace function marrakech.site_content_before_update()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.data is distinct from old.data then
    insert into marrakech.site_content_history (saved_by, data) values (old.updated_by, old.data);
    delete from marrakech.site_content_history
     where id not in (select id from marrakech.site_content_history order by id desc limit 50);
  end if;
  new.updated_at := now(); new.updated_by := auth.uid(); new.id := old.id;
  return new;
end; $$;
drop trigger if exists trg_site_content_before_update on marrakech.site_content;
create trigger trg_site_content_before_update before update on marrakech.site_content
  for each row execute function marrakech.site_content_before_update();

-- 2. CLIENTS + DEMANDES (réservation de table / message) ---------------
create table if not exists marrakech.customers (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 2 and 80),
  phone text not null check (phone ~ '^\+?[0-9][0-9 .-]{7,18}[0-9]$'),
  phone_norm text generated always as (regexp_replace(phone, '[^0-9]', '', 'g')) stored,
  notes text check (notes is null or char_length(notes) <= 2000),
  created_at timestamptz not null default now()
);
create unique index if not exists customers_phone_norm_uq on marrakech.customers (phone_norm);

create table if not exists marrakech.requests (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('reservation','message')),
  status text not null default 'nouveau' check (status in ('nouveau','confirmé','honoré','annulé')),
  customer_id uuid references marrakech.customers(id) on delete set null,
  name text not null check (char_length(btrim(name)) between 2 and 80),
  phone text not null check (phone ~ '^\+?[0-9][0-9 .-]{7,18}[0-9]$'),
  email text check (email is null or (char_length(email) <= 120 and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')),
  day date,
  at_time text check (at_time is null or at_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'),
  guests smallint check (guests is null or guests between 1 and 30),
  occasion text check (occasion is null or char_length(occasion) <= 60),
  message text check (message is null or char_length(message) <= 1500),
  hp text,  -- pot de miel anti-robot (doit rester vide)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint resa_fields check (kind <> 'reservation' or (day is not null and at_time is not null and guests is not null)),
  constraint msg_fields check (kind <> 'message' or (message is not null and char_length(btrim(message)) >= 5))
);
create index if not exists requests_created_idx on marrakech.requests (created_at desc);
create index if not exists requests_kind_idx on marrakech.requests (kind, status);
create index if not exists requests_day_idx on marrakech.requests (day);

create or replace function marrakech.requests_before_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_data jsonb; v_norm text; v_cid uuid; v_today date; v_dow int; v_open text; v_min int; v_t int;
begin
  if public.is_owner() then new.updated_at := now(); return new; end if;
  if coalesce(new.hp, '') <> '' then raise exception 'Envoi refusé.' using errcode = 'P0001'; end if;
  new.status := 'nouveau'; new.created_at := now(); new.updated_at := now(); new.customer_id := null; new.hp := null;
  new.name := btrim(new.name); new.phone := btrim(new.phone);
  new.message := nullif(btrim(coalesce(new.message,'')),''); new.email := nullif(btrim(coalesce(new.email,'')),'');
  new.occasion := nullif(btrim(coalesce(new.occasion,'')),'');
  if new.kind <> 'reservation' then new.day := null; new.at_time := null; new.guests := null; new.occasion := null; end if;
  select data into v_data from marrakech.site_content where id = 1;
  if new.kind = 'reservation' then
    if coalesce((v_data -> 'booking' ->> 'open')::boolean, true) = false then
      raise exception 'Les réservations en ligne sont momentanément fermées : appelez-nous.' using errcode = 'P0001';
    end if;
    v_today := (now() at time zone 'Africa/Algiers')::date;
    if new.day < v_today or new.day > v_today + 60 then
      raise exception 'Date de réservation invalide (aujourd''hui à 60 jours).' using errcode = 'P0001';
    end if;
    -- horaires (maquette) : midi 11h00–15h30, soir 18h00–22h30, tous les jours
    v_t := split_part(new.at_time, ':', 1)::int * 60 + split_part(new.at_time, ':', 2)::int;
    if not ((v_t between 11*60 and 15*60+30) or (v_t between 18*60 and 22*60+30)) then
      raise exception 'Heure en dehors des horaires (midi 11h–15h30, soir 18h–22h30).' using errcode = 'P0001';
    end if;
    if new.day = v_today and v_t < extract(hour from (now() at time zone 'Africa/Algiers'))::int * 60 + extract(minute from (now() at time zone 'Africa/Algiers'))::int then
      raise exception 'Cette heure est déjà passée.' using errcode = 'P0001';
    end if;
  end if;
  if (select count(*) from marrakech.requests where created_at > now() - interval '1 minute') >= 20 then
    raise exception 'Trop de demandes en ce moment, réessayez dans une minute.' using errcode = 'P0001';
  end if;
  v_norm := regexp_replace(new.phone, '[^0-9]', '', 'g');
  if (select count(*) from marrakech.requests where regexp_replace(phone,'[^0-9]','','g') = v_norm and created_at > now() - interval '10 minutes') >= 3 then
    raise exception 'Vous avez déjà envoyé plusieurs demandes : nous vous rappelons rapidement.' using errcode = 'P0001';
  end if;
  insert into marrakech.customers (name, phone) values (new.name, new.phone)
    on conflict (phone_norm) do update set name = marrakech.customers.name
    returning id into v_cid;
  new.customer_id := v_cid;
  return new;
end; $$;
drop trigger if exists trg_requests_before_insert on marrakech.requests;
create trigger trg_requests_before_insert before insert on marrakech.requests
  for each row execute function marrakech.requests_before_insert();

create or replace function marrakech.touch_updated()
returns trigger language plpgsql set search_path = '' as $$ begin new.updated_at := now(); return new; end; $$;
drop trigger if exists trg_requests_before_update on marrakech.requests;
create trigger trg_requests_before_update before update on marrakech.requests
  for each row execute function marrakech.touch_updated();

create or replace view marrakech.requests_daily with (security_invoker = true) as
select (r.created_at at time zone 'Africa/Algiers')::date as day,
       count(*) as total,
       count(*) filter (where r.kind = 'reservation') as reservations,
       coalesce(sum(r.guests) filter (where r.kind = 'reservation' and r.status <> 'annulé'), 0) as guests,
       count(*) filter (where r.kind = 'message') as messages,
       count(*) filter (where r.status = 'honoré') as honored,
       count(*) filter (where r.status = 'annulé') as cancelled
from marrakech.requests r group by 1;

-- 3. DROITS + RLS -------------------------------------------------------
revoke all on all tables in schema marrakech from anon, authenticated;
revoke execute on all functions in schema marrakech from public, anon, authenticated;
grant select on marrakech.site_content to anon, authenticated;
grant insert (kind, name, phone, email, day, at_time, guests, occasion, message, hp) on marrakech.requests to anon, authenticated;
grant insert, update on marrakech.site_content to authenticated;
grant select on marrakech.site_content_history to authenticated;
grant select, update, delete on marrakech.requests to authenticated;
grant select, update, delete on marrakech.customers to authenticated;
grant select on marrakech.requests_daily to authenticated;
grant all on all tables in schema marrakech to service_role;

alter table marrakech.site_content enable row level security;
alter table marrakech.site_content_history enable row level security;
alter table marrakech.customers enable row level security;
alter table marrakech.requests enable row level security;
do $$ declare r record; begin
  for r in select policyname, tablename from pg_policies where schemaname = 'marrakech' loop
    execute format('drop policy if exists %I on marrakech.%I', r.policyname, r.tablename);
  end loop; end $$;
create policy "contenu : lecture publique" on marrakech.site_content for select to anon, authenticated using (true);
create policy "contenu : ajout patron" on marrakech.site_content for insert to authenticated with check (id = 1 and public.is_owner());
create policy "contenu : modification patron" on marrakech.site_content for update to authenticated
  using (id = 1 and public.is_owner()) with check (id = 1 and public.is_owner());
create policy "historique : lecture patron" on marrakech.site_content_history for select to authenticated using (public.is_owner());
create policy "demandes : envoi depuis le site" on marrakech.requests for insert to anon, authenticated with check (status = 'nouveau');
create policy "demandes : patron" on marrakech.requests for all to authenticated using (public.is_owner()) with check (public.is_owner());
create policy "clients : patron" on marrakech.customers for all to authenticated using (public.is_owner()) with check (public.is_owner());

do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'marrakech' and tablename = 'requests') then
    alter publication supabase_realtime add table marrakech.requests;
  end if; end $$;

-- 4. PHOTOS (admin) : bucket public « images », préfixe « up-marrakech_ » ; l'envoi est réservé au patron
--    par les politiques storage existantes du projet (aucun envoi anonyme pour ce site).
