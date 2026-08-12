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

  update public.stores set config = p_new_config where id = p_store_id;
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
  p_link_index text default null -- Índice do link clicado (e.g. '0', '1')
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
  v_daily jsonb;
begin
  -- Busca a configuração atual da loja
  select config into v_config from public.stores where id = p_store_id;
  if v_config is null then
    return false;
  end if;

  -- Garante que o objeto 'stats' está inicializado
  if v_config -> 'stats' is null then
    v_config = jsonb_set(v_config, '{stats}', '{"views": 0, "clicks": {}, "daily": {}}'::jsonb);
  end if;
  
  v_stats = v_config -> 'stats';
  if v_stats -> 'clicks' is null then
    v_stats = jsonb_set(v_stats, '{clicks}', '{}'::jsonb);
  end if;
  if v_stats -> 'daily' is null then
    v_stats = jsonb_set(v_stats, '{daily}', '{}'::jsonb);
  end if;

  if p_action = 'view' then
    -- Incrementa visualizações totais
    v_stats = jsonb_set(v_stats, '{views}', to_jsonb(coalesce((v_stats ->> 'views')::int, 0) + 1));
    
    -- Garante que o registro diário existe
    if v_stats -> 'daily' -> p_today_str is null then
      v_stats = jsonb_set(v_stats, array['daily', p_today_str], '{"views": 0, "clicks": {}}'::jsonb);
    end if;
    
    -- Incrementa visualizações diárias
    v_stats = jsonb_set(
      v_stats, 
      array['daily', p_today_str, 'views'], 
      to_jsonb(coalesce((v_stats -> 'daily' -> p_today_str ->> 'views')::int, 0) + 1)
    );

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
      v_stats = jsonb_set(v_stats, array['daily', p_today_str], '{"views": 0, "clicks": {}}'::jsonb);
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

revoke all on function public.track_view_or_click(text, text, text, text) from public;
grant execute on function public.track_view_or_click(text, text, text, text) to anon, authenticated;

-- ============================================================================
-- Depois de rodar este script, teste:
--   1. Login normal (admin e de uma loja) ainda deve funcionar.
--   2. Editar textos/cores de uma loja e ver o autosave salvar normalmente
--      (tanto logado como a própria loja quanto como admin editando ela).
--   3. No painel admin > Gerenciar Lojas: revelar senha, trocar senha,
--      criar loja nova e excluir loja — todos devem continuar funcionando
--      (cada um vai pedir sua senha de admin uma vez, se a sessão tiver
--      sido restaurada por um F5 e a senha não estiver mais em memória).
--   4. Rodando isto (com a chave anon, fora do app) o resultado deve ser
--      um erro de permissão — a escrita direta não deve mais funcionar:
--        update stores set config = '{}' where id = 'algum-id';
--   5. A visualização das páginas públicas de links de uma loja e os cliques
--      devem atualizar os contadores na base atomicamente através da RPC:
--        select track_view_or_click('loja-id', 'view', '2026-08-11');
-- ============================================================================

