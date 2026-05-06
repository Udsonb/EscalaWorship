-- ============================================================
-- ESCALAWORSHIP — Schema Supabase
-- Execute este arquivo no SQL Editor do Supabase
-- Painel: https://supabase.com → SQL Editor → New Query
-- ============================================================

-- Habilitar extensões úteis
create extension if not exists "uuid-ossp";

-- ============================================================
-- TABELA: ministerios
-- ============================================================
create table if not exists ministerios (
  id          uuid primary key default uuid_generate_v4(),
  nome        text not null,
  tipo        text default 'Louvor', -- Louvor, Multimídia, Dança
  codigo      text unique not null,  -- código de convite (ex: VIDA26)
  link_convite text,
  plano       text default 'gratuito',
  criado_em   timestamptz default now(),
  atualizado_em timestamptz default now()
);

-- ============================================================
-- TABELA: membros (ligados a auth.users do Supabase)
-- ============================================================
create table if not exists membros (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid references auth.users(id) on delete set null,
  ministerio_id uuid references ministerios(id) on delete cascade,
  nome        text not null,
  iniciais    text generated always as (
                upper(left(split_part(nome,' ',1),1) ||
                      coalesce(left(split_part(nome,' ',2),1),''))
              ) stored,
  email       text,
  telefone    text,
  funcao      text not null default '🎤 Vocal',
  permissao   text not null default 'participante', -- participante | editor | admin
  status      text not null default 'ativo',         -- ativo | inativo | indisponivel
  avatar_cor  text default 'av1',
  criado_em   timestamptz default now(),
  atualizado_em timestamptz default now()
);

-- ============================================================
-- TABELA: indisponibilidades
-- ============================================================
create table if not exists indisponibilidades (
  id            uuid primary key default uuid_generate_v4(),
  membro_id     uuid references membros(id) on delete cascade,
  ministerio_id uuid references ministerios(id) on delete cascade,
  data_inicio   date not null,
  data_fim      date not null,
  tipo          text default 'outro', -- viagem | saude | trabalho | ferias | outro
  motivo        text,                 -- visível só para admins
  criado_em     timestamptz default now(),
  constraint datas_validas check (data_fim >= data_inicio)
);

-- ============================================================
-- TABELA: musicas (repertório global do ministério)
-- ============================================================
create table if not exists musicas (
  id            uuid primary key default uuid_generate_v4(),
  ministerio_id uuid references ministerios(id) on delete cascade,
  titulo        text not null,
  artista       text,
  tom           text,    -- ex: "Dm - REm"
  bpm           int,
  pasta         text default 'Sem pasta',
  link_spotify  text,
  link_youtube  text,
  link_cifra    text,
  link_letra    text,
  ativo         boolean default true,
  criado_por    uuid references membros(id) on delete set null,
  criado_em     timestamptz default now(),
  atualizado_em timestamptz default now()
);

-- ============================================================
-- TABELA: escalas
-- ============================================================
create table if not exists escalas (
  id            uuid primary key default uuid_generate_v4(),
  ministerio_id uuid references ministerios(id) on delete cascade,
  titulo        text not null,
  data_evento   date not null,
  hora_evento   time not null default '09:00',
  status        text not null default 'rascunho', -- rascunho | planejada | publicada | realizada
  observacoes   text,
  criado_por    uuid references membros(id) on delete set null,
  criado_em     timestamptz default now(),
  atualizado_em timestamptz default now()
);

-- ============================================================
-- TABELA: escala_membros (quem está na escala)
-- ============================================================
create table if not exists escala_membros (
  id            uuid primary key default uuid_generate_v4(),
  escala_id     uuid references escalas(id) on delete cascade,
  membro_id     uuid references membros(id) on delete cascade,
  confirmacao   text not null default 'pendente', -- pendente | confirmado | recusado
  respondido_em timestamptz,
  unique(escala_id, membro_id)
);

-- ============================================================
-- TABELA: escala_slots (repertório da escala — posições 1-5+)
-- ============================================================
create table if not exists escala_slots (
  id            uuid primary key default uuid_generate_v4(),
  escala_id     uuid references escalas(id) on delete cascade,
  posicao       int not null,                   -- 1, 2, 3, 4, 5...
  tipo_especial text default '',                -- ofertorio | santa-ceia | abertura | encerramento
  musica_id     uuid references musicas(id) on delete set null, -- ref ao repertório global (opcional)
  -- campos inline (pode preencher sem ter a música no repertório)
  nome          text,
  artista       text,
  tom           text,
  bpm           int,
  link_spotify  text,
  link_youtube  text,
  link_cifra    text,
  escolhido_por uuid references membros(id) on delete set null,
  criado_em     timestamptz default now(),
  atualizado_em timestamptz default now(),
  unique(escala_id, posicao)
);

-- ============================================================
-- TABELA: sugestoes (sugestões de músicas por membros)
-- ============================================================
create table if not exists sugestoes (
  id            uuid primary key default uuid_generate_v4(),
  escala_id     uuid references escalas(id) on delete cascade,
  sugerido_por  uuid references membros(id) on delete cascade,
  nome          text not null,
  artista       text,
  link          text,
  status        text not null default 'pendente', -- pendente | aceita | recusada
  aprovado_por  uuid references membros(id) on delete set null,
  criado_em     timestamptz default now(),
  -- cada membro só pode ter 1 sugestão pendente por escala
  unique(escala_id, sugerido_por)
);

-- ============================================================
-- TABELA: avisos
-- ============================================================
create table if not exists avisos (
  id            uuid primary key default uuid_generate_v4(),
  ministerio_id uuid references ministerios(id) on delete cascade,
  titulo        text not null,
  mensagem      text not null,
  tipo          text default 'geral',  -- geral | urgente | info
  autor_id      uuid references membros(id) on delete set null,
  criado_em     timestamptz default now()
);

-- ============================================================
-- TABELA: chat_mensagens
-- ============================================================
create table if not exists chat_mensagens (
  id            uuid primary key default uuid_generate_v4(),
  ministerio_id uuid references ministerios(id) on delete cascade,
  autor_id      uuid references membros(id) on delete set null,
  mensagem      text not null,
  criado_em     timestamptz default now()
);

-- ============================================================
-- VIEWS ÚTEIS
-- ============================================================

-- Resumo de confirmações por escala
create or replace view vw_confirmacoes_resumo as
select
  e.id as escala_id,
  e.titulo,
  e.data_evento,
  count(*) filter (where em.confirmacao = 'confirmado') as confirmados,
  count(*) filter (where em.confirmacao = 'pendente')   as pendentes,
  count(*) filter (where em.confirmacao = 'recusado')   as recusados,
  count(*) as total
from escalas e
join escala_membros em on em.escala_id = e.id
group by e.id, e.titulo, e.data_evento;

-- Membros disponíveis em uma data (sem indisponibilidade)
create or replace view vw_membros_com_indisps as
select
  m.*,
  coalesce(
    array_agg(
      json_build_object(
        'id', i.id,
        'inicio', i.data_inicio,
        'fim', i.data_fim,
        'tipo', i.tipo,
        'motivo', i.motivo
      )
    ) filter (where i.id is not null),
    array[]::json[]
  ) as indisponibilidades
from membros m
left join indisponibilidades i on i.membro_id = m.id
group by m.id;

-- Músicas mais tocadas
create or replace view vw_musicas_mais_tocadas as
select
  coalesce(s.musica_id::text, s.nome) as chave,
  coalesce(mu.titulo, s.nome) as titulo,
  coalesce(mu.artista, s.artista) as artista,
  count(*) as vezes_tocada
from escala_slots s
left join musicas mu on mu.id = s.musica_id
where s.nome is not null and s.nome != ''
group by 1, 2, 3
order by vezes_tocada desc;

-- Membros mais escalados
create or replace view vw_membros_mais_escalados as
select
  m.id,
  m.nome,
  m.funcao,
  m.avatar_cor,
  m.iniciais,
  count(em.id) as vezes_escalado
from membros m
join escala_membros em on em.membro_id = m.id
group by m.id, m.nome, m.funcao, m.avatar_cor, m.iniciais
order by vezes_escalado desc;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Verifica se membro está indisponível em uma data
create or replace function membro_indisponivel(p_membro_id uuid, p_data date)
returns boolean language sql stable as $$
  select exists (
    select 1 from indisponibilidades
    where membro_id = p_membro_id
      and p_data between data_inicio and data_fim
  );
$$;

-- Gera código de convite único
create or replace function gerar_codigo_ministerio()
returns text language plpgsql as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
  i int;
begin
  for i in 1..6 loop
    result := result || substr(chars, floor(random()*length(chars)+1)::int, 1);
  end loop;
  return result;
end;
$$;

-- Trigger: atualiza updated_at automaticamente
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin new.atualizado_em = now(); return new; end;
$$;

create or replace trigger trg_ministerios_updated   before update on ministerios   for each row execute function set_updated_at();
create or replace trigger trg_membros_updated       before update on membros       for each row execute function set_updated_at();
create or replace trigger trg_musicas_updated       before update on musicas       for each row execute function set_updated_at();
create or replace trigger trg_escalas_updated       before update on escalas       for each row execute function set_updated_at();
create or replace trigger trg_escala_slots_updated  before update on escala_slots  for each row execute function set_updated_at();

-- Trigger: quando membro recebe indisponibilidade, status muda para 'indisponivel' se hoje estiver no período
create or replace function sync_status_membro()
returns trigger language plpgsql as $$
begin
  if new.data_inicio <= current_date and new.data_fim >= current_date then
    update membros set status = 'indisponivel' where id = new.membro_id;
  end if;
  return new;
end;
$$;

create or replace trigger trg_indisp_insert after insert on indisponibilidades
for each row execute function sync_status_membro();

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
-- Habilitar RLS em todas as tabelas
alter table ministerios         enable row level security;
alter table membros             enable row level security;
alter table indisponibilidades  enable row level security;
alter table musicas             enable row level security;
alter table escalas             enable row level security;
alter table escala_membros      enable row level security;
alter table escala_slots        enable row level security;
alter table sugestoes           enable row level security;
alter table avisos              enable row level security;
alter table chat_mensagens      enable row level security;

-- Helper: retorna o ministerio_id do usuário logado
create or replace function meu_ministerio_id()
returns uuid language sql stable security definer as $$
  select ministerio_id from membros where user_id = auth.uid() limit 1;
$$;

-- Helper: retorna meu membro_id
create or replace function meu_membro_id()
returns uuid language sql stable security definer as $$
  select id from membros where user_id = auth.uid() limit 1;
$$;

-- Helper: verifica se sou admin
create or replace function sou_admin()
returns boolean language sql stable security definer as $$
  select exists(select 1 from membros where user_id = auth.uid() and permissao = 'admin');
$$;

-- MINISTERIOS: ver o próprio; criar qualquer um autenticado
create policy "ver proprio ministerio" on ministerios for select
  using (id = meu_ministerio_id());
create policy "criar ministerio" on ministerios for insert
  with check (auth.uid() is not null);

-- MEMBROS: ver membros do mesmo ministério
create policy "ver membros do ministerio" on membros for select
  using (ministerio_id = meu_ministerio_id());
create policy "admin gerencia membros" on membros for all
  using (ministerio_id = meu_ministerio_id() and sou_admin());
create policy "membro edita proprio" on membros for update
  using (user_id = auth.uid());

-- INDISPONIBILIDADES: ver as do próprio ministério; admin vê todas, membro vê a própria
create policy "ver indisps do ministerio" on indisponibilidades for select
  using (ministerio_id = meu_ministerio_id());
create policy "membro declara propria indisp" on indisponibilidades for insert
  with check (membro_id = meu_membro_id());
create policy "admin gerencia indisps" on indisponibilidades for all
  using (ministerio_id = meu_ministerio_id() and sou_admin());

-- MÚSICAS: todos do ministério veem; editor/admin gerencia
create policy "ver musicas" on musicas for select
  using (ministerio_id = meu_ministerio_id());
create policy "editor adiciona musica" on musicas for insert
  with check (ministerio_id = meu_ministerio_id());
create policy "editor edita musica" on musicas for update
  using (ministerio_id = meu_ministerio_id());

-- ESCALAS: rascunho = só admin; outras = todos do ministério
create policy "ver escalas publicadas" on escalas for select
  using (
    ministerio_id = meu_ministerio_id() and (
      status != 'rascunho' or sou_admin()
    )
  );
create policy "admin gerencia escalas" on escalas for all
  using (ministerio_id = meu_ministerio_id() and sou_admin());

-- ESCALA_MEMBROS: todos veem; admin e o próprio membro editam confirmação
create policy "ver escala membros" on escala_membros for select
  using (exists(select 1 from escalas e where e.id = escala_id and e.ministerio_id = meu_ministerio_id()));
create policy "membro confirma presenca" on escala_membros for update
  using (membro_id = meu_membro_id());
create policy "admin gerencia escala membros" on escala_membros for all
  using (sou_admin());

-- SLOTS: membros escalados podem editar; admin sempre
create policy "ver slots" on escala_slots for select
  using (exists(select 1 from escalas e where e.id = escala_id and e.ministerio_id = meu_ministerio_id()));
create policy "membro escalado edita slot" on escala_slots for update
  using (
    exists(
      select 1 from escala_membros em
      where em.escala_id = escala_slots.escala_id
        and em.membro_id = meu_membro_id()
    )
  );
create policy "membro escalado insere slot" on escala_slots for insert
  with check (sou_admin());
create policy "admin gerencia slots" on escala_slots for all
  using (sou_admin());

-- SUGESTÕES: todos escalados veem; cada um cria a própria
create policy "ver sugestoes" on sugestoes for select
  using (exists(select 1 from escalas e where e.id = escala_id and e.ministerio_id = meu_ministerio_id()));
create policy "membro sugere" on sugestoes for insert
  with check (sugerido_por = meu_membro_id());
create policy "admin decide sugestao" on sugestoes for update
  using (sou_admin());

-- AVISOS e CHAT: todos do ministério
create policy "ver avisos" on avisos for select using (ministerio_id = meu_ministerio_id());
create policy "admin cria aviso" on avisos for insert with check (ministerio_id = meu_ministerio_id() and sou_admin());
create policy "ver chat" on chat_mensagens for select using (ministerio_id = meu_ministerio_id());
create policy "membro envia mensagem" on chat_mensagens for insert with check (ministerio_id = meu_ministerio_id());

-- ============================================================
-- REALTIME: habilitar para tabelas de colaboração
-- ============================================================
-- Execute no Supabase: Database → Replication → habilitar as tabelas abaixo
-- escala_slots, sugestoes, chat_mensagens, escala_membros

-- ============================================================
-- DADOS DE EXEMPLO (opcional — remova em produção)
-- ============================================================
do $$
declare
  min_id uuid := uuid_generate_v4();
  m1 uuid := uuid_generate_v4();
  m2 uuid := uuid_generate_v4();
  m3 uuid := uuid_generate_v4();
  m4 uuid := uuid_generate_v4();
  m5 uuid := uuid_generate_v4();
  e1 uuid := uuid_generate_v4();
  mu1 uuid := uuid_generate_v4();
  mu2 uuid := uuid_generate_v4();
  mu3 uuid := uuid_generate_v4();
begin

  insert into ministerios(id, nome, tipo, codigo) values
    (min_id, 'Igreja Vida Nova', 'Louvor', 'VIDA26');

  insert into membros(id, ministerio_id, nome, email, funcao, permissao, avatar_cor) values
    (m1, min_id, 'Ricardo Barbosa', 'rb@email.com', '🎸 Guitarra Base', 'admin',        'av1'),
    (m2, min_id, 'Carla Menezes',   'cm@email.com', '🎤 Vocal',          'participante', 'av2'),
    (m3, min_id, 'Thiago Santos',   'ts@email.com', '🥁 Bateria',        'participante', 'av3'),
    (m4, min_id, 'Lucas Pereira',   'lp@email.com', '🎹 Teclado',        'participante', 'av4'),
    (m5, min_id, 'Ana Ferreira',    'af@email.com', '🎤 Vocal',          'participante', 'av5');

  insert into musicas(id, ministerio_id, titulo, artista, tom, bpm, pasta, link_spotify, link_youtube, criado_por) values
    (mu1, min_id, 'Oceans (Where Feet May Fail)', 'Hillsong United', 'Dm - REm', 68, 'Adoração',
      'https://open.spotify.com/track/4hVON4gT66skGnRDELEfpn',
      'https://youtube.com/watch?v=dy9nwe9_xzw', m1),
    (mu2, min_id, 'Way Maker', 'Sinach', 'C - DO', 80, 'Louvor',
      '', 'https://youtube.com/watch?v=sR1gIBnH5JU', m1),
    (mu3, min_id, 'Goodness of God', 'Bethel Music', 'A - LA', 72, 'Adoração',
      '', 'https://youtube.com/watch?v=XFHLFkKnKGE', m1);

  insert into escalas(id, ministerio_id, titulo, data_evento, hora_evento, status, criado_por) values
    (e1, min_id, 'Culto Domingo Manhã', '2026-05-18', '09:00', 'publicada', m1);

  insert into escala_membros(escala_id, membro_id, confirmacao) values
    (e1, m1, 'confirmado'), (e1, m2, 'pendente'),
    (e1, m3, 'confirmado'), (e1, m5, 'pendente');

  insert into escala_slots(escala_id, posicao, nome, artista, tom, bpm, link_spotify, link_youtube, escolhido_por, musica_id) values
    (e1, 1, 'Oceans (Where Feet May Fail)', 'Hillsong United', 'Dm - REm', 68,
      'https://open.spotify.com/track/4hVON4gT66skGnRDELEfpn', 'https://youtube.com/watch?v=dy9nwe9_xzw', m1, mu1),
    (e1, 2, 'Way Maker', 'Sinach', 'C - DO', 80, '', 'https://youtube.com/watch?v=sR1gIBnH5JU', m2, mu2),
    (e1, 3, '', '', '', null, '', '', null, null),
    (e1, 4, '', '', '', null, '', '', null, null),
    (e1, 5, '', '', '', null, '', '', null, null);

  insert into sugestoes(escala_id, sugerido_por, nome, artista, status) values
    (e1, m2, 'Reckless Love', 'Cory Asbury', 'pendente'),
    (e1, m5, 'Gratidão', 'Tom Krüger', 'aceita');

  insert into avisos(ministerio_id, titulo, mensagem, tipo, autor_id) values
    (min_id, '⚠️ Ensaio sexta às 19h confirmado!',
     'Pessoal, ensaio confirmado. Chegarem 15min antes. Levar instrumentos.', 'urgente', m1),
    (min_id, 'ℹ️ Novos tons atualizados',
     'Oceans: Dm→Am. Reckless Love: G→A. Atualizem as cifragens.', 'info', m1);

  insert into chat_mensagens(ministerio_id, autor_id, mensagem) values
    (min_id, m1, 'Galera, alguém pode colocar o arranjo de Oceans no Drive?'),
    (min_id, m2, 'Posso sim! Coloco hoje à noite 🎶'),
    (min_id, m3, 'Confirmo presença no ensaio de sexta 🥁');

end $$;
