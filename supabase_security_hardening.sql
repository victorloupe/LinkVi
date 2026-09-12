-- ============================================================================
-- LinksVi — Endurecimento de segurança da tabela `stores`
-- ============================================================================
-- Rode este script inteiro no SQL Editor do Supabase (Project > SQL Editor > New query).
-- Ele é seguro de rodar mais de uma vez (idempotente).
--
-- O QUE ESTE SCRIPT RESOLVE
-- Hoje qualquer pessoa com a chave "anon" do projeto (que fica exposta no
-- HTML/JS do site, isso é normal) consegue rodar:
--   GET /rest/v1/stores?select=id,password
-- e baixar a senha de TODAS as lojas de uma vez, sem passar pelo login do
-- painel. Depois deste script, a coluna `password` deixa de ser legível
-- diretamente — login e a função "Exibir senha" do admin passam a usar
-- funções no banco (RPC) que fazem a checagem no lado do servidor e nunca
-- devolvem a senha em texto puro para quem não provou conhecer a senha certa.
--
-- ATUALIZAÇÃO: agora este script TAMBÉM fecha as escritas (INSERT/UPDATE/
-- DELETE). Antes, qualquer um com a chave anon podia criar, editar ou
-- apagar lojas direto pela API REST, sem passar pelo painel — mesmo com o
-- login do app funcionando normalmente, porque a chave anon por si só dava
-- acesso de escrita na tabela. A partir de agora, toda escrita passa por
-- uma função (RPC) que exige a senha certa (da própria loja, ou do admin
-- para ações administrativas), e o acesso direto de escrita na tabela é
-- revogado da chave anon.
-- ============================================================================

-- 1) Garante que a tabela existe com RLS ligado (não altera dados existentes)
alter table if exists public.stores enable row level security;

-- 2) Restringe a leitura pública da coluna `password`.
--    `id` e `config` continuam públicos (são necessários para a página
--    pública de cada loja funcionar sem login).
revoke select on public.stores from anon, authenticated;
grant select (id, config) on public.stores to anon, authenticated;

-- 3) Função de login: recebe usuário + senha, faz a comparação dentro do
--    banco e devolve só o `id` da loja quando bate — nunca a senha.
create or replace function public.login_store(p_username text, p_password text)
returns table(id text)
language sql
security definer
set search_path = public
as $$
  select s.id
  from public.stores s
  where s.password = p_password
    and (
      (p_username = 'contato@linksvi.com.br' and s.id in ('contato@linksvi.com.br', 'contato@linkvi.com.br'))
      or s.id = p_username
    )
  limit 1;
$$;

revoke all on function public.login_store(text, text) from public;
grant execute on function public.login_store(text, text) to anon, authenticated;

-- 4) Função para o admin revelar a senha de uma loja específica: só
--    devolve algo se quem chamou souber a senha atual do admin.
create or replace function public.admin_reveal_password(p_admin_password text, p_target_id text)
returns text
language sql
security definer
set search_path = public
as $$
  select target.password
  from public.stores target
  where target.id = p_target_id
    and exists (
      select 1
      from public.stores admin_row
      where admin_row.id in ('contato@linksvi.com.br', 'contato@linkvi.com.br')
        and admin_row.password = p_admin_password
    );
$$;

revoke all on function public.admin_reveal_password(text, text) from public;
grant execute on function public.admin_reveal_password(text, text) to anon, authenticated;

-- 5) Salvar a configuração de uma loja (autosave do painel). Autorizado se
--    a senha bate com a da PRÓPRIA loja, ou com a do admin (o admin pode
--    editar qualquer loja, como já acontece hoje). Devolve true/false —
--    o app trata `false` como "senha errada", sem derrubar a sessão.
create or replace function public.update_store_config(p_store_id text, p_password text, p_new_config jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_authorized boolean;
  v_existing_stats jsonb;
  v_final_config jsonb;
begin
  select exists(
    select 1 from public.stores s
    where s.id = p_store_id and s.password = p_password
  ) or exists(
    select 1 from public.stores admin_row
    where admin_row.id in ('contato@linksvi.com.br', 'contato@linkvi.com.br')
      and admin_row.password = p_password
  ) into v_authorized;

  if not v_authorized then
    return false;
  end if;

  -- Preserva as estatísticas em tempo real existentes no banco (evita sobrescrever métricas dos visitantes com dados antigos em memória)
  select config -> 'stats' into v_existing_stats from public.stores where id = p_store_id;
  
  if v_existing_stats is not null then
    v_final_config = jsonb_set(p_new_config, '{stats}', v_existing_stats);
  else
    v_final_config = p_new_config;
  end if;

  update public.stores set config = v_final_config where id = p_store_id;
  return true;
end;
$$;

revoke all on function public.update_store_config(text, text, jsonb) from public;
grant execute on function public.update_store_config(text, text, jsonb) to anon, authenticated;

-- 6) Criar uma loja nova — só o admin pode.
create or replace function public.create_store(p_admin_password text, p_store_id text, p_store_password text, p_config jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_admin boolean;
begin
  select exists(
    select 1 from public.stores admin_row
    where admin_row.id in ('contato@linksvi.com.br', 'contato@linkvi.com.br')
      and admin_row.password = p_admin_password
  ) into v_is_admin;

  if not v_is_admin then
    return false;
  end if;

  insert into public.stores (id, password, config) values (p_store_id, p_store_password, p_config);
  return true;
end;
$$;

revoke all on function public.create_store(text, text, text, jsonb) from public;
grant execute on function public.create_store(text, text, text, jsonb) to anon, authenticated;

-- 7) Trocar a senha de uma loja — só o admin pode.
create or replace function public.update_store_password(p_admin_password text, p_target_id text, p_new_password text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_admin boolean;
begin
  select exists(
    select 1 from public.stores admin_row
    where admin_row.id in ('contato@linksvi.com.br', 'contato@linkvi.com.br')
      and admin_row.password = p_admin_password
  ) into v_is_admin;

  if not v_is_admin then
    return false;
  end if;

  update public.stores set password = p_new_password where id = p_target_id;
  return true;
end;
$$;

revoke all on function public.update_store_password(text, text, text) from public;
grant execute on function public.update_store_password(text, text, text) to anon, authenticated;

-- 8) Apagar uma loja — só o admin pode.
create or replace function public.delete_store(p_admin_password text, p_target_id text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_admin boolean;
begin
  select exists(
    select 1 from public.stores admin_row
    where admin_row.id in ('contato@linksvi.com.br', 'contato@linkvi.com.br')
      and admin_row.password = p_admin_password
  ) into v_is_admin;

  if not v_is_admin then
    return false;
  end if;

  delete from public.stores where id = p_target_id;
  return true;
end;
$$;

revoke all on function public.delete_store(text, text) from public;
grant execute on function public.delete_store(text, text) to anon, authenticated;

-- 9) Agora que toda escrita passa pelas funções acima, tira o acesso de
--    escrita direto na tabela. Isso é o que realmente fecha o buraco:
--    sem isso, alguém ainda poderia ignorar as funções e escrever direto
--    via REST usando só a chave anon.
revoke insert, update, delete on public.stores from anon, authenticated;

-- 10) Função para registrar visualizações e cliques de forma anônima e atômica.
--     Como os acessos de escrita direta na tabela stores foram revogados, os
--     visitantes não conseguem atualizar as estatísticas diretamente. Esta função
--     roda com privilégios de criador (security definer) e permite o incremento.
create or replace function public.track_view_or_click(
  p_store_id text,
  p_action text, -- 'view' ou 'click'
  p_today_str text, -- 'YYYY-MM-DD'
  p_link_index text default null, -- ID único do link ou índice (e.g. 'lnk_123' ou '0')
  p_referrer text default null -- Origem do tráfego (e.g. 'instagram', 'tiktok', 'whatsapp', 'direct', etc.)
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_config jsonb;
  v_stats jsonb;
  v_clicks jsonb;
  v_sources jsonb;
  v_daily jsonb;
  v_ref_clean text;
begin
  -- Ignora rastreamento em testes, localhost e endereços locais
  if p_referrer is not null and (
    lower(p_referrer) like '%127.0.0.1%' or
    lower(p_referrer) like '%localhost%' or
    lower(p_referrer) like '192.168.%' or
    lower(p_referrer) like '10.%' or
    lower(p_referrer) in ('test', 'preview')
  ) then
    return true; -- Silenciosamente ignora o teste sem inflar métricas
  end if;

  -- Busca a configuração atual da loja
  select config into v_config from public.stores where id = p_store_id;
  if v_config is null then
    return false;
  end if;

  -- Garante que o objeto 'stats' está inicializado
  if v_config -> 'stats' is null then
    v_config = jsonb_set(v_config, '{stats}', '{"views": 0, "clicks": {}, "sources": {}, "daily": {}}'::jsonb);
  end if;
  
  v_stats = v_config -> 'stats';
  if v_stats -> 'clicks' is null then
    v_stats = jsonb_set(v_stats, '{clicks}', '{}'::jsonb);
  end if;
  if v_stats -> 'sources' is null then
    v_stats = jsonb_set(v_stats, '{sources}', '{}'::jsonb);
  end if;
  if v_stats -> 'daily' is null then
    v_stats = jsonb_set(v_stats, '{daily}', '{}'::jsonb);
  end if;

  if p_action = 'view' then
    -- Incrementa visualizações totais
    v_stats = jsonb_set(v_stats, '{views}', to_jsonb(coalesce((v_stats ->> 'views')::int, 0) + 1));
    
    -- Garante que o registro diário existe
    if v_stats -> 'daily' -> p_today_str is null then
      v_stats = jsonb_set(v_stats, array['daily', p_today_str], '{"views": 0, "clicks": {}, "sources": {}}'::jsonb);
    end if;
    
    -- Incrementa visualizações diárias
    v_stats = jsonb_set(
      v_stats, 
      array['daily', p_today_str, 'views'], 
      to_jsonb(coalesce((v_stats -> 'daily' -> p_today_str ->> 'views')::int, 0) + 1)
    );

    -- Rastreamento de canal/origem (se informado)
    if p_referrer is not null and length(trim(p_referrer)) > 0 then
      v_ref_clean = lower(trim(p_referrer));
      v_sources = v_stats -> 'sources';
      v_sources = jsonb_set(
        v_sources,
        array[v_ref_clean],
        to_jsonb(coalesce((v_sources ->> v_ref_clean)::int, 0) + 1)
      );
      v_stats = jsonb_set(v_stats, '{sources}', v_sources);

      if v_stats -> 'daily' -> p_today_str -> 'sources' is null then
        v_stats = jsonb_set(v_stats, array['daily', p_today_str, 'sources'], '{}'::jsonb);
      end if;

      v_stats = jsonb_set(
        v_stats,
        array['daily', p_today_str, 'sources', v_ref_clean],
        to_jsonb(coalesce((v_stats -> 'daily' -> p_today_str -> 'sources' ->> v_ref_clean)::int, 0) + 1)
      );
    end if;

  elsif p_action = 'click' and p_link_index is not null then
    -- Incrementa cliques totais no link
    v_clicks = v_stats -> 'clicks';
    v_clicks = jsonb_set(
      v_clicks, 
      array[p_link_index], 
      to_jsonb(coalesce((v_clicks ->> p_link_index)::int, 0) + 1)
    );
    v_stats = jsonb_set(v_stats, '{clicks}', v_clicks);

    -- Garante que o registro diário existe
    if v_stats -> 'daily' -> p_today_str is null then
      v_stats = jsonb_set(v_stats, array['daily', p_today_str], '{"views": 0, "clicks": {}, "sources": {}}'::jsonb);
    end if;
    -- Garante que o objeto de cliques diários existe
    if v_stats -> 'daily' -> p_today_str -> 'clicks' is null then
      v_stats = jsonb_set(v_stats, array['daily', p_today_str, 'clicks'], '{}'::jsonb);
    end if;

    -- Incrementa cliques diários no link
    v_stats = jsonb_set(
      v_stats, 
      array['daily', p_today_str, 'clicks', p_link_index], 
      to_jsonb(coalesce((v_stats -> 'daily' -> p_today_str -> 'clicks' ->> p_link_index)::int, 0) + 1)
    );
  end if;

  -- Remove chaves diárias antigas mantendo apenas os últimos 90 dias de estatísticas.
  -- Isso evita o crescimento indefinido do JSONB na coluna 'config', mantendo
  -- o carregamento da página pública sempre leve e rápido para os visitantes.
  select jsonb_object_agg(key, value) into v_daily
  from (
    select key, value
    from jsonb_each(v_stats -> 'daily')
    order by key desc
    limit 90
  ) x;
  v_stats = jsonb_set(v_stats, '{daily}', coalesce(v_daily, '{}'::jsonb));

  -- Atualiza o config de volta na tabela
  v_config = jsonb_set(v_config, '{stats}', v_stats);
  update public.stores set config = v_config where id = p_store_id;

  return true;
end;
$$;

revoke all on function public.track_view_or_click(text, text, text, text, text) from public;
grant execute on function public.track_view_or_click(text, text, text, text, text) to anon, authenticated;

-- 11) Função utilitária para expurgar acessos de teste (127.0.0.1 / localhost) do banco
create or replace function public.clean_store_test_data(p_store_id text, p_password text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_authorized boolean;
  v_config jsonb;
  v_stats jsonb;
  v_daily jsonb;
  v_sources jsonb;
  v_test_views int := 0;
begin
  select exists(
    select 1 from public.stores s
    where s.id = p_store_id and s.password = p_password
  ) or exists(
    select 1 from public.stores admin_row
    where admin_row.id in ('contato@linksvi.com.br', 'contato@linkvi.com.br')
      and admin_row.password = p_password
  ) into v_authorized;

  if not v_authorized then
    return false;
  end if;

  select config into v_config from public.stores where id = p_store_id;
  if v_config is null or v_config -> 'stats' is null then
    return true;
  end if;

  v_stats = v_config -> 'stats';

  -- Remove fontes de teste do consolidado
  if v_stats -> 'sources' is not null then
    v_sources = v_stats -> 'sources';
    v_test_views = coalesce((v_sources ->> '127.0.0.1')::int, 0) 
                 + coalesce((v_sources ->> 'localhost')::int, 0);
    v_sources = v_sources - '127.0.0.1' - 'localhost' - 'test';
    v_stats = jsonb_set(v_stats, '{sources}', v_sources);
    
    if v_test_views > 0 then
      v_stats = jsonb_set(v_stats, '{views}', to_jsonb(greatest(0, coalesce((v_stats ->> 'views')::int, 0) - v_test_views)));
    end if;
  end if;

  -- Limpa fontes de teste do diário
  if v_stats -> 'daily' is not null then
    select jsonb_object_agg(d_key, d_val) into v_daily
    from (
      select 
        day_key as d_key,
        case 
          when day_val -> 'sources' is not null and ((day_val -> 'sources' ? '127.0.0.1') or (day_val -> 'sources' ? 'localhost')) then
            jsonb_set(
              jsonb_set(
                day_val, 
                '{views}', 
                to_jsonb(greatest(0, coalesce((day_val ->> 'views')::int, 0) - coalesce((day_val -> 'sources' ->> '127.0.0.1')::int, 0) - coalesce((day_val -> 'sources' ->> 'localhost')::int, 0)))
              ),
              '{sources}',
              (day_val -> 'sources') - '127.0.0.1' - 'localhost' - 'test'
            )
          else day_val
        end as d_val
      from jsonb_each(v_stats -> 'daily') as t(day_key, day_val)
    ) s;
    v_stats = jsonb_set(v_stats, '{daily}', coalesce(v_daily, '{}'::jsonb));
  end if;

  v_config = jsonb_set(v_config, '{stats}', v_stats);
  update public.stores set config = v_config where id = p_store_id;
  return true;
end;
$$;

revoke all on function public.clean_store_test_data(text, text) from public;
grant execute on function public.clean_store_test_data(text, text) to anon, authenticated;

-- ============================================================================
-- Depois de rodar este script, teste:
--   1. Login normal (admin e de uma loja) ainda deve funcionar.
--   2. Editar textos/cores de uma loja e ver o autosave salvar normalmente.
--   3. Visualizações em 127.0.0.1 / localhost / preview não são registradas.
-- ============================================================================

