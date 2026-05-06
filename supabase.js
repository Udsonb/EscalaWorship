/**
 * EscalaWorship — supabase.js
 * Camada de dados: substitui localStorage, usa Supabase como backend.
 *
 * CONFIGURAÇÃO:
 *   1. Crie um projeto em https://supabase.com
 *   2. Rode o schema.sql no SQL Editor
 *   3. Substitua SUPABASE_URL e SUPABASE_ANON_KEY abaixo
 *      (Painel → Project Settings → API)
 */

// ============================================================
// CONFIG — ALTERE AQUI
// ============================================================
const SUPABASE_URL      = 'https://SEU-PROJETO.supabase.co';
const SUPABASE_ANON_KEY = 'SUA-ANON-KEY-AQUI';

// ============================================================
// CLIENTE
// ============================================================
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ============================================================
// AUTH
// ============================================================
export const Auth = {

  /** Login com Google OAuth */
  async loginGoogle() {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: window.location.origin }
    });
    if (error) throw error;
  },

  /** Login com email + senha */
  async loginEmail(email, senha) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password: senha });
    if (error) throw error;
    return data;
  },

  /** Cadastro com email + senha */
  async registrar(email, senha, nome) {
    const { data, error } = await supabase.auth.signUp({
      email, password: senha,
      options: { data: { nome } }
    });
    if (error) throw error;
    return data;
  },

  /** Logout */
  async logout() {
    await supabase.auth.signOut();
  },

  /** Sessão atual */
  async sessao() {
    const { data } = await supabase.auth.getSession();
    return data.session;
  },

  /** Escuta mudanças de auth */
  onMudanca(callback) {
    supabase.auth.onAuthStateChange((_event, session) => callback(session));
  }
};

// ============================================================
// MINISTÉRIOS
// ============================================================
export const Ministerios = {

  async buscarPorCodigo(codigo) {
    const { data, error } = await supabase
      .from('ministerios')
      .select('*')
      .eq('codigo', codigo.toUpperCase())
      .single();
    if (error) throw error;
    return data;
  },

  async criar(nome, tipo = 'Louvor') {
    // Gera código único via function do banco
    const { data: cod } = await supabase.rpc('gerar_codigo_ministerio');
    const { data, error } = await supabase
      .from('ministerios')
      .insert({ nome, tipo, codigo: cod })
      .select()
      .single();
    if (error) throw error;
    return data;
  },

  async meu() {
    const { data, error } = await supabase
      .from('ministerios')
      .select('*')
      .single();
    if (error) throw error;
    return data;
  }
};

// ============================================================
// MEMBROS
// ============================================================
export const Membros = {

  async listar(ministerioId) {
    const { data, error } = await supabase
      .from('vw_membros_com_indisps')
      .select('*')
      .eq('ministerio_id', ministerioId)
      .order('nome');
    if (error) throw error;
    return data;
  },

  async buscarPorUser(userId) {
    const { data, error } = await supabase
      .from('membros')
      .select('*')
      .eq('user_id', userId)
      .single();
    if (error && error.code !== 'PGRST116') throw error;
    return data;
  },

  async criar(ministerioId, dados) {
    const { data, error } = await supabase
      .from('membros')
      .insert({ ministerio_id: ministerioId, ...dados })
      .select()
      .single();
    if (error) throw error;
    return data;
  },

  async atualizar(id, dados) {
    const { data, error } = await supabase
      .from('membros')
      .update(dados)
      .eq('id', id)
      .select()
      .single();
    if (error) throw error;
    return data;
  },

  async vincularUser(membroId, userId) {
    return this.atualizar(membroId, { user_id: userId });
  },

  async estaIndisponivel(membroId, data) {
    const { data: result } = await supabase
      .rpc('membro_indisponivel', { p_membro_id: membroId, p_data: data });
    return result;
  }
};

// ============================================================
// INDISPONIBILIDADES
// ============================================================
export const Indisponibilidades = {

  async listarPorMembro(membroId) {
    const { data, error } = await supabase
      .from('indisponibilidades')
      .select('*')
      .eq('membro_id', membroId)
      .order('data_inicio');
    if (error) throw error;
    return data;
  },

  async declarar(ministerioId, membroId, inicio, fim, tipo, motivo) {
    const { data, error } = await supabase
      .from('indisponibilidades')
      .insert({
        ministerio_id: ministerioId,
        membro_id: membroId,
        data_inicio: inicio,
        data_fim: fim,
        tipo,
        motivo
      })
      .select()
      .single();
    if (error) throw error;
    // Atualiza status do membro se o período inclui hoje
    const hoje = new Date().toISOString().split('T')[0];
    if (inicio <= hoje && fim >= hoje) {
      await Membros.atualizar(membroId, { status: 'indisponivel' });
    }
    return data;
  },

  async remover(id, membroId) {
    const { error } = await supabase
      .from('indisponibilidades')
      .delete()
      .eq('id', id);
    if (error) throw error;
    // Verifica se ainda tem indisps ativas
    const restantes = await this.listarPorMembro(membroId);
    const hoje = new Date().toISOString().split('T')[0];
    const aindaIndisp = restantes.some(i => i.data_inicio <= hoje && i.data_fim >= hoje);
    if (!aindaIndisp) {
      await Membros.atualizar(membroId, { status: 'ativo' });
    }
  }
};

// ============================================================
// MÚSICAS
// ============================================================
export const Musicas = {

  async listar(ministerioId, busca = '') {
    let query = supabase
      .from('musicas')
      .select('*')
      .eq('ministerio_id', ministerioId)
      .eq('ativo', true)
      .order('titulo');
    if (busca) {
      query = query.or(`titulo.ilike.%${busca}%,artista.ilike.%${busca}%`);
    }
    const { data, error } = await query;
    if (error) throw error;
    return data;
  },

  async criar(ministerioId, criadoPor, dados) {
    const { data, error } = await supabase
      .from('musicas')
      .insert({ ministerio_id: ministerioId, criado_por: criadoPor, ...dados })
      .select()
      .single();
    if (error) throw error;
    return data;
  },

  async atualizar(id, dados) {
    const { data, error } = await supabase
      .from('musicas')
      .update(dados)
      .eq('id', id)
      .select()
      .single();
    if (error) throw error;
    return data;
  },

  async maisTopadas(ministerioId) {
    const { data, error } = await supabase
      .from('vw_musicas_mais_tocadas')
      .select('*')
      .limit(10);
    if (error) throw error;
    return data;
  }
};

// ============================================================
// ESCALAS
// ============================================================
export const Escalas = {

  async listar(ministerioId) {
    const { data, error } = await supabase
      .from('escalas')
      .select(`
        *,
        escala_membros(count),
        escala_slots(count)
      `)
      .eq('ministerio_id', ministerioId)
      .order('data_evento');
    if (error) throw error;
    return data;
  },

  async buscar(id) {
    const { data, error } = await supabase
      .from('escalas')
      .select(`
        *,
        escala_membros(
          id, confirmacao, respondido_em,
          membros(id, nome, iniciais, funcao, avatar_cor)
        ),
        escala_slots(
          id, posicao, tipo_especial, nome, artista, tom, bpm,
          link_spotify, link_youtube, link_cifra,
          escolhido_por, musica_id,
          membros!escolhido_por(id, nome, iniciais)
        ),
        sugestoes(
          id, nome, artista, link, status, criado_em,
          membros!sugerido_por(id, nome, iniciais),
          aprovador:membros!aprovado_por(id, nome)
        )
      `)
      .eq('id', id)
      .single();
    if (error) throw error;
    // Ordena slots por posição
    if (data.escala_slots) {
      data.escala_slots.sort((a, b) => a.posicao - b.posicao);
    }
    return data;
  },

  async criar(ministerioId, criadoPor, dados) {
    const { data: escala, error } = await supabase
      .from('escalas')
      .insert({ ministerio_id: ministerioId, criado_por: criadoPor, ...dados })
      .select()
      .single();
    if (error) throw error;

    // Cria 5 slots vazios automaticamente
    const slots = Array.from({ length: 5 }, (_, i) => ({
      escala_id: escala.id,
      posicao: i + 1,
      tipo_especial: i === 2 ? 'ofertorio' : '' // posição 3 = ofertório por padrão
    }));
    await supabase.from('escala_slots').insert(slots);

    return escala;
  },

  async atualizar(id, dados) {
    const { data, error } = await supabase
      .from('escalas')
      .update(dados)
      .eq('id', id)
      .select()
      .single();
    if (error) throw error;
    return data;
  },

  async publicar(id) {
    return this.atualizar(id, { status: 'publicada' });
  }
};

// ============================================================
// ESCALA MEMBROS
// ============================================================
export const EscalaMembros = {

  async adicionar(escalaId, membroId) {
    const { data, error } = await supabase
      .from('escala_membros')
      .insert({ escala_id: escalaId, membro_id: membroId, confirmacao: 'pendente' })
      .select()
      .single();
    if (error) throw error;
    return data;
  },

  async remover(escalaId, membroId) {
    const { error } = await supabase
      .from('escala_membros')
      .delete()
      .eq('escala_id', escalaId)
      .eq('membro_id', membroId);
    if (error) throw error;
  },

  async confirmar(escalaId, membroId, confirmacao) {
    const { data, error } = await supabase
      .from('escala_membros')
      .update({ confirmacao, respondido_em: new Date().toISOString() })
      .eq('escala_id', escalaId)
      .eq('membro_id', membroId)
      .select()
      .single();
    if (error) throw error;
    return data;
  }
};

// ============================================================
// SLOTS (Repertório da Escala)
// ============================================================
export const Slots = {

  async atualizar(slotId, dados, escolhidoPor) {
    const { data, error } = await supabase
      .from('escala_slots')
      .update({ ...dados, escolhido_por: escolhidoPor })
      .eq('id', slotId)
      .select()
      .single();
    if (error) throw error;
    return data;
  },

  async adicionarPosicao(escalaId) {
    // Descobre próxima posição
    const { data: slots } = await supabase
      .from('escala_slots')
      .select('posicao')
      .eq('escala_id', escalaId)
      .order('posicao', { ascending: false })
      .limit(1);
    const proxPos = slots?.length ? slots[0].posicao + 1 : 1;
    const { data, error } = await supabase
      .from('escala_slots')
      .insert({ escala_id: escalaId, posicao: proxPos })
      .select()
      .single();
    if (error) throw error;
    return data;
  }
};

// ============================================================
// SUGESTÕES
// ============================================================
export const Sugestoes = {

  async sugerir(escalaId, sugeridoPor, nome, artista, link = '') {
    const { data, error } = await supabase
      .from('sugestoes')
      .insert({ escala_id: escalaId, sugerido_por: sugeridoPor, nome, artista, link })
      .select()
      .single();
    if (error) throw error;
    return data;
  },

  async decidir(sugestaoId, status, aprovadoPor) {
    const { data, error } = await supabase
      .from('sugestoes')
      .update({ status, aprovado_por: status === 'aceita' ? aprovadoPor : null })
      .eq('id', sugestaoId)
      .select()
      .single();
    if (error) throw error;
    return data;
  }
};

// ============================================================
// AVISOS
// ============================================================
export const Avisos = {

  async listar(ministerioId) {
    const { data, error } = await supabase
      .from('avisos')
      .select('*, membros!autor_id(nome)')
      .eq('ministerio_id', ministerioId)
      .order('criado_em', { ascending: false });
    if (error) throw error;
    return data;
  },

  async criar(ministerioId, autorId, titulo, mensagem, tipo = 'geral') {
    const { data, error } = await supabase
      .from('avisos')
      .insert({ ministerio_id: ministerioId, autor_id: autorId, titulo, mensagem, tipo })
      .select()
      .single();
    if (error) throw error;
    return data;
  }
};

// ============================================================
// CHAT
// ============================================================
export const Chat = {

  async historico(ministerioId, limite = 50) {
    const { data, error } = await supabase
      .from('chat_mensagens')
      .select('*, membros!autor_id(id, nome, iniciais, avatar_cor)')
      .eq('ministerio_id', ministerioId)
      .order('criado_em', { ascending: false })
      .limit(limite);
    if (error) throw error;
    return (data || []).reverse();
  },

  async enviar(ministerioId, autorId, mensagem) {
    const { data, error } = await supabase
      .from('chat_mensagens')
      .insert({ ministerio_id: ministerioId, autor_id: autorId, mensagem })
      .select()
      .single();
    if (error) throw error;
    return data;
  },

  /** Escuta novas mensagens em tempo real */
  escutar(ministerioId, callback) {
    return supabase
      .channel(`chat:${ministerioId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'chat_mensagens',
        filter: `ministerio_id=eq.${ministerioId}`
      }, payload => callback(payload.new))
      .subscribe();
  }
};

// ============================================================
// REALTIME: Slots (atualização colaborativa ao vivo)
// ============================================================
export const Realtime = {

  escutarSlots(escalaId, callback) {
    return supabase
      .channel(`slots:${escalaId}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'escala_slots',
        filter: `escala_id=eq.${escalaId}`
      }, payload => callback(payload))
      .subscribe();
  },

  escutarConfirmacoes(escalaId, callback) {
    return supabase
      .channel(`confirms:${escalaId}`)
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'escala_membros',
        filter: `escala_id=eq.${escalaId}`
      }, payload => callback(payload.new))
      .subscribe();
  },

  escutarSugestoes(escalaId, callback) {
    return supabase
      .channel(`sugestoes:${escalaId}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'sugestoes',
        filter: `escala_id=eq.${escalaId}`
      }, payload => callback(payload))
      .subscribe();
  },

  cancelar(channel) {
    if (channel) supabase.removeChannel(channel);
  }
};

// ============================================================
// RELATÓRIOS
// ============================================================
export const Relatorios = {

  async membrosEscalados(ministerioId) {
    const { data, error } = await supabase
      .from('vw_membros_mais_escalados')
      .select('*')
      .eq('ministerio_id', ministerioId)
      .limit(10);
    if (error) throw error;
    return data;
  },

  async musicasMaisTocadas() {
    const { data, error } = await supabase
      .from('vw_musicas_mais_tocadas')
      .select('*')
      .limit(10);
    if (error) throw error;
    return data;
  },

  async resumoMes(ministerioId, ano, mes) {
    const inicio = `${ano}-${String(mes).padStart(2,'0')}-01`;
    const fim    = `${ano}-${String(mes).padStart(2,'0')}-31`;
    const { data, error } = await supabase
      .from('vw_confirmacoes_resumo')
      .select('*')
      .gte('data_evento', inicio)
      .lte('data_evento', fim);
    if (error) throw error;
    return data;
  }
};
