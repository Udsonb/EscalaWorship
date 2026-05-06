# EscalaWorship 🎵
**App de gestão de ministério de louvor — PWA + Supabase**

---

## 🗂 Arquivos

```
escalaworship/
├── index.html    ← App completo (frontend)
├── supabase.js   ← Camada de dados (funções reutilizáveis)
├── schema.sql    ← Banco de dados (rode 1x no Supabase)
├── manifest.json ← PWA config
├── sw.js         ← Service Worker (offline)
└── README.md     ← Este arquivo
```

---

## 🚀 Setup em 15 minutos

### PASSO 1 — Criar projeto Supabase
1. https://supabase.com → New project
2. Nome: `escalaworship` | Região: **South America (São Paulo)**
3. Aguarde ~2 min

### PASSO 2 — Criar banco
1. SQL Editor → New query
2. Cole o conteúdo de `schema.sql` → Run ▶

### PASSO 3 — Pegar chaves
Project Settings → API → copie:
- **Project URL** ex: `https://xyzabc.supabase.co`
- **anon/public key** ex: `eyJhbGci...`

### PASSO 4 — Configurar o app
No `index.html`, procure e altere:
```javascript
const SUPA_URL = 'https://SEU-PROJETO.supabase.co';
const SUPA_KEY = 'SUA-ANON-KEY';
```

### PASSO 5 — Hospedar
**Netlify (mais fácil):** arraste a pasta em https://netlify.com/drop → pronto!

**Vercel:** `npm i -g vercel && vercel --prod`

---

## 📱 Instalar no Android

1. Abra no **Chrome Android**
2. Menu ⋮ → **"Adicionar à tela inicial"**
3. Ou aguarde o banner automático aparecer no rodapé

**iOS:** Safari → Compartilhar → "Adicionar à Tela de Início"

---

## ⚡ Ativar Realtime

Supabase → Database → Replication → habilite:
- `chat_mensagens`, `escala_slots`, `escala_membros`, `sugestoes`

---

## 🔐 RLS já configurado

- Membros só veem o próprio ministério
- Rascunhos visíveis só para admins
- 1 sugestão pendente por membro/escala
- Indisponibilidade bloqueia o membro automaticamente

---

## 🗄️ Estrutura do banco

```
ministerios        ← ministério + código de convite
membros            ← linked to auth.users
indisponibilidades ← períodos de ausência
musicas            ← repertório global
escalas            ← cultos/eventos
escala_membros     ← quem está + confirmação
escala_slots       ← setlist posições 1-5+
sugestoes          ← sugestões por membros
avisos             ← comunicados
chat_mensagens     ← chat em tempo real

Views: vw_confirmacoes_resumo, vw_membros_com_indisps,
       vw_musicas_mais_tocadas, vw_membros_mais_escalados
```

---

## 📊 Queries úteis

```sql
-- Membros disponíveis para uma data
select nome, funcao from membros
where not membro_indisponivel(id, '2026-05-18');

-- Setlist de uma escala
select posicao, nome, artista, tom from escala_slots
where escala_id = 'ID' order by posicao;

-- Frequência mensal
select m.nome, count(*) as escalas
from escala_membros em
join membros m on m.id = em.membro_id
join escalas e on e.id = em.escala_id
where e.data_evento >= '2026-05-01'
  and em.confirmacao = 'confirmado'
group by m.nome order by escalas desc;
```

---

## 🆓 Plano gratuito Supabase

| Recurso | Gratuito |
|---|---|
| Banco | 500 MB |
| Usuários | 50k/mês |
| API | Ilimitado |
| Realtime | 200 conexões |

Suficiente para ministérios de até ~200 membros.
