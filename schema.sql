-- =========================================================
-- FLEMINGCORE — SCHEMA COMPLETO
-- Versão corrigida com todas as mudanças aplicadas
-- Confirmado como correto em 07/08/2026
-- =========================================================

-- =========================================================
-- FARMÁCIA
-- =========================================================
CREATE TABLE public.farmacia (
    id_farmacia        SERIAL PRIMARY KEY,
    nome               VARCHAR(100)    NOT NULL,
    cnpj               CHAR(14)        NOT NULL UNIQUE,
    endereco           TEXT,
    ivf_atual          NUMERIC(5,2),
    data_calculo_ivf   TIMESTAMP,
    selo_ativo         BOOLEAN         DEFAULT FALSE,
    indice_anvisa_ready NUMERIC(5,2),
    total_desperdicio_evitado      NUMERIC(14,2) DEFAULT 0,
    total_medicamentos_preservados INT           DEFAULT 0,
    created_at         TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_farmacia_nome ON public.farmacia(nome);

-- =========================================================
-- DISTRIBUIDOR
-- Ideia 22 — Experiência do Distribuidor
-- =========================================================
CREATE TABLE public.distribuidor (
    id_distribuidor  SERIAL PRIMARY KEY,
    nome             VARCHAR(100) NOT NULL,
    cnpj             CHAR(14)     NOT NULL UNIQUE,
    regiao_atuacao   VARCHAR(100),
    email_contato    VARCHAR(100),
    created_at       TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_distribuidor_regiao ON public.distribuidor(regiao_atuacao);

-- =========================================================
-- MEDICAMENTO (CATÁLOGO GLOBAL)
-- =========================================================
CREATE TABLE public.medicamento (
    id_medicamento  SERIAL PRIMARY KEY,
    nome            VARCHAR(100) NOT NULL,
    codigo_barras   VARCHAR(50)  UNIQUE,
    fabricante      VARCHAR(100),
    principio_ativo VARCHAR(100),
    categoria       VARCHAR(100),
    preco_referencia NUMERIC(12,2),
    created_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_medicamento_nome       ON public.medicamento(nome);
CREATE INDEX idx_medicamento_fabricante ON public.medicamento(fabricante);
CREATE INDEX idx_medicamento_principio  ON public.medicamento(principio_ativo);

-- =========================================================
-- STATUS REGULATÓRIO
-- Ideia 13 — Verificação de Status Regulatório ANVISA
-- =========================================================
CREATE TABLE public.status_regulatorio (
    id_status      SERIAL PRIMARY KEY,
    id_medicamento INT          NOT NULL,
    situacao       VARCHAR(30)  NOT NULL,
    fonte          VARCHAR(100),
    data_consulta  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_status_medicamento
        FOREIGN KEY (id_medicamento)
        REFERENCES public.medicamento(id_medicamento)
        ON DELETE CASCADE,
    CONSTRAINT chk_status_situacao
        CHECK (situacao IN ('LIBERADO','SUSPENSO','CONTROLADO','EM_ANALISE','PROIBIDO'))
);
CREATE INDEX idx_status_medicamento ON public.status_regulatorio(id_medicamento);

-- =========================================================
-- EVENTOS REGULATÓRIOS
-- Ideia 13 — histórico de recalls e alertas publicados
-- =========================================================
CREATE TABLE public.evento_regulatorio (
    id_evento     SERIAL PRIMARY KEY,
    id_status     INT     NOT NULL,
    descricao     TEXT    NOT NULL,
    data_evento   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    origem        VARCHAR(100),
    CONSTRAINT fk_evento_status
        FOREIGN KEY (id_status)
        REFERENCES public.status_regulatorio(id_status)
        ON DELETE CASCADE
);
CREATE INDEX idx_evento_status ON public.evento_regulatorio(id_status);

-- =========================================================
-- USUÁRIO
-- tipo_usuario: FARMACEUTICO | EUROFARMA | DISTRIBUIDOR | ADMIN
-- id_farmacia é NULL para EUROFARMA, DISTRIBUIDOR e ADMIN
-- id_distribuidor é NULL para todos exceto DISTRIBUIDOR
-- =========================================================
CREATE TABLE public.usuario (
    id_usuario                    SERIAL PRIMARY KEY,
    nome                          VARCHAR(100) NOT NULL,
    email                         VARCHAR(100) NOT NULL UNIQUE,
    firebase_uid                  VARCHAR(120) UNIQUE,
    cargo                         VARCHAR(30)  NOT NULL,
    tipo_usuario                  VARCHAR(30)  NOT NULL,
    token_fcm                     VARCHAR(255),
    tempo_medio_resolucao_moderado INT,
    data_calculo_padrao           TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    id_farmacia                   INT,
    id_distribuidor               INT,
    created_at                    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_usuario_farmacia
        FOREIGN KEY (id_farmacia)
        REFERENCES public.farmacia(id_farmacia)
        ON DELETE RESTRICT,
    CONSTRAINT fk_usuario_distribuidor
        FOREIGN KEY (id_distribuidor)
        REFERENCES public.distribuidor(id_distribuidor)
        ON DELETE RESTRICT,
    CONSTRAINT chk_usuario_cargo
        CHECK (cargo IN ('ADMIN','FARMACEUTICO','GERENTE','OPERADOR')),
    CONSTRAINT chk_usuario_tipo
        CHECK (tipo_usuario IN ('FARMACEUTICO','EUROFARMA','DISTRIBUIDOR','ADMIN'))
);
CREATE INDEX idx_usuario_farmacia     ON public.usuario(id_farmacia);
CREATE INDEX idx_usuario_distribuidor ON public.usuario(id_distribuidor);

-- =========================================================
-- HISTÓRICO DE ATIVIDADES
-- =========================================================
CREATE TABLE public.historico_atividades (
    id_historico SERIAL PRIMARY KEY,
    id_farmacia  INT          NOT NULL,
    id_usuario   INT,
    tipo_acao    VARCHAR(50)  NOT NULL,
    descricao    TEXT         NOT NULL,
    data_hora    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_historico_farmacia
        FOREIGN KEY (id_farmacia)
        REFERENCES public.farmacia(id_farmacia)
        ON DELETE CASCADE,
    CONSTRAINT fk_historico_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES public.usuario(id_usuario)
        ON DELETE SET NULL
);
CREATE INDEX idx_historico_data     ON public.historico_atividades(data_hora);
CREATE INDEX idx_historico_farmacia ON public.historico_atividades(id_farmacia);

-- =========================================================
-- LOTES
-- data_ultima_movimentacao: usada pela Ideia 17
-- preco_unitario: usado pelas Ideias 04 e 16
-- =========================================================
CREATE TABLE public.lote (
    id_lote                  SERIAL PRIMARY KEY,
    numero_lote              VARCHAR(50)  NOT NULL,
    validade                 DATE         NOT NULL,
    quantidade               INT          NOT NULL CHECK (quantidade >= 0),
    data_cadastro            TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    origem                   VARCHAR(100),
    preco_unitario           NUMERIC(12,2),
    data_ultima_movimentacao DATE,
    id_medicamento           INT          NOT NULL,
    id_farmacia              INT          NOT NULL,
    updated_at               TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_lote_medicamento
        FOREIGN KEY (id_medicamento)
        REFERENCES public.medicamento(id_medicamento)
        ON DELETE RESTRICT,
    CONSTRAINT fk_lote_farmacia
        FOREIGN KEY (id_farmacia)
        REFERENCES public.farmacia(id_farmacia)
        ON DELETE CASCADE
);
CREATE INDEX idx_lote_validade          ON public.lote(validade);
CREATE INDEX idx_lote_farmacia          ON public.lote(id_farmacia);
CREATE INDEX idx_lote_medicamento       ON public.lote(id_medicamento);
CREATE INDEX idx_lote_farmacia_validade ON public.lote(id_farmacia, validade);
CREATE INDEX idx_lote_ultima_mov        ON public.lote(data_ultima_movimentacao);

-- =========================================================
-- ENTRADAS DE ESTOQUE
-- =========================================================
CREATE TABLE public.entrada_estoque (
    id_entrada          SERIAL PRIMARY KEY,
    data_entrada        DATE    NOT NULL,
    quantidade_recebida INT     NOT NULL CHECK (quantidade_recebida > 0),
    tipo                VARCHAR(30) NOT NULL,
    id_lote             INT     NOT NULL,
    id_farmacia         INT     NOT NULL,
    CONSTRAINT fk_entrada_lote
        FOREIGN KEY (id_lote)
        REFERENCES public.lote(id_lote)
        ON DELETE CASCADE,
    CONSTRAINT fk_entrada_farmacia
        FOREIGN KEY (id_farmacia)
        REFERENCES public.farmacia(id_farmacia)
        ON DELETE CASCADE,
    CONSTRAINT chk_entrada_tipo
        CHECK (tipo IN ('COMPRA','DEVOLUCAO','TRANSFERENCIA','AJUSTE'))
);
CREATE INDEX idx_entrada_lote          ON public.entrada_estoque(id_lote);
CREATE INDEX idx_entrada_farmacia_data ON public.entrada_estoque(id_farmacia, data_entrada);

-- =========================================================
-- VENDAS
-- cliente_cpf e cliente_telefone: Ideia 02 — Rastreabilidade PDV
-- =========================================================
CREATE TABLE public.venda (
    id_venda            SERIAL PRIMARY KEY,
    data_venda          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    quantidade          INT          NOT NULL CHECK (quantidade > 0),
    preco_unitario_venda NUMERIC(12,2) NOT NULL,
    valor_total         NUMERIC(14,2) GENERATED ALWAYS AS (quantidade * preco_unitario_venda) STORED,
    desconto            NUMERIC(12,2) DEFAULT 0 CHECK (desconto >= 0),
    forma_pagamento     VARCHAR(30),
    origem              VARCHAR(50),
    cliente_cpf         CHAR(11),
    cliente_telefone    VARCHAR(20),
    id_lote             INT          NOT NULL,
    id_farmacia         INT          NOT NULL,
    CONSTRAINT fk_venda_lote
        FOREIGN KEY (id_lote)
        REFERENCES public.lote(id_lote)
        ON DELETE RESTRICT,
    CONSTRAINT fk_venda_farmacia
        FOREIGN KEY (id_farmacia)
        REFERENCES public.farmacia(id_farmacia)
        ON DELETE RESTRICT,
    CONSTRAINT chk_venda_pagamento
        CHECK (forma_pagamento IN ('DINHEIRO','PIX','CARTAO','BOLETO'))
);
CREATE INDEX idx_venda_data         ON public.venda(data_venda);
CREATE INDEX idx_venda_lote         ON public.venda(id_lote);
CREATE INDEX idx_venda_farmacia     ON public.venda(id_farmacia);
CREATE INDEX idx_venda_farmacia_data ON public.venda(id_farmacia, data_venda);

-- =========================================================
-- ALERTAS
-- tipo: vencimento | regulatorio | discrepancia | esquecido | campanha_vacinacao
-- status: ABERTO | RESOLVIDO | IGNORADO
-- acao_tomada: promocao | devolucao | monitoramento
-- sobra_projetada e valor_financeiro_risco: Ideia 04
-- motivo_discrepancia: Ideia 15
-- acao_tomada: Ideias 05 e 06
-- =========================================================
CREATE TABLE public.alerta (
    id_alerta             SERIAL PRIMARY KEY,
    tipo                  VARCHAR(30)  NOT NULL
        CHECK (tipo IN ('vencimento','regulatorio','discrepancia','esquecido','campanha_vacinacao')),
    severidade            VARCHAR(20)
        CHECK (severidade IN ('BAIXA','MEDIA','ALTA','CRITICA')),
    mensagem              TEXT,
    status                VARCHAR(20)  NOT NULL DEFAULT 'ABERTO'
        CHECK (status IN ('ABERTO','RESOLVIDO','IGNORADO')),
    data_alerta           TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    data_resolucao        TIMESTAMP,
    score                 NUMERIC(5,2),
    recomendacao          TEXT,
    motivo_discrepancia   TEXT,
    valor_financeiro_risco NUMERIC(12,2),
    sobra_projetada       INT,
    acao_tomada           VARCHAR(20)
        CHECK (acao_tomada IN ('promocao','devolucao','monitoramento')),
    id_lote               INT          NOT NULL,
    id_farmacia           INT          NOT NULL,
    CONSTRAINT fk_alerta_lote
        FOREIGN KEY (id_lote)
        REFERENCES public.lote(id_lote)
        ON DELETE CASCADE,
    CONSTRAINT fk_alerta_farmacia
        FOREIGN KEY (id_farmacia)
        REFERENCES public.farmacia(id_farmacia)
        ON DELETE CASCADE
);
CREATE INDEX idx_alerta_farmacia ON public.alerta(id_farmacia);
CREATE INDEX idx_alerta_status   ON public.alerta(status);
CREATE INDEX idx_alerta_tipo     ON public.alerta(tipo);

-- =========================================================
-- SOLICITAÇÕES DE DEVOLUÇÃO
-- Ideia 06 — Canal de Devolução com o Distribuidor
-- status: PENDENTE | ENVIADA | APROVADA | RECUSADA
-- =========================================================
CREATE TABLE public.solicitacoes_devolucao (
    id_solicitacao   SERIAL PRIMARY KEY,
    id_lote          INT          NOT NULL,
    id_farmacia      INT          NOT NULL,
    id_usuario       INT,
    status           VARCHAR(20)  NOT NULL DEFAULT 'PENDENTE'
        CHECK (status IN ('PENDENTE','ENVIADA','APROVADA','RECUSADA')),
    quantidade       INT          NOT NULL CHECK (quantidade > 0),
    motivo           TEXT,
    data_solicitacao TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP,
    CONSTRAINT fk_devolucao_lote
        FOREIGN KEY (id_lote)
        REFERENCES public.lote(id_lote)
        ON DELETE CASCADE,
    CONSTRAINT fk_devolucao_farmacia
        FOREIGN KEY (id_farmacia)
        REFERENCES public.farmacia(id_farmacia)
        ON DELETE CASCADE,
    CONSTRAINT fk_devolucao_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES public.usuario(id_usuario)
        ON DELETE SET NULL
);
CREATE INDEX idx_devolucao_farmacia ON public.solicitacoes_devolucao(id_farmacia, status);

-- =========================================================
-- MÍNIMOS DE ESTOQUE
-- Ideia 19 — Índice de Vulnerabilidade Farmacêutica
-- doencas_associadas: mapeamento surto → categoria de medicamento
-- =========================================================
CREATE TABLE public.minimos_estoque (
    id_minimo            SERIAL PRIMARY KEY,
    categoria            VARCHAR(100) NOT NULL,
    quantidade_minima    INT          NOT NULL CHECK (quantidade_minima >= 0),
    doencas_associadas   TEXT,
    created_at           TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- CAMPANHAS DE VACINAÇÃO
-- Ideia 20 — Previsão de Demanda por Campanhas
-- regiao: nacional ou regional — necessário para filtrar por farmácia
-- =========================================================
CREATE TABLE public.campanhas_vacinacao (
    id_campanha      SERIAL PRIMARY KEY,
    nome             VARCHAR(100) NOT NULL,
    categoria_alvo   VARCHAR(100),
    regiao           VARCHAR(50),
    data_inicio      DATE         NOT NULL,
    data_fim         DATE,
    created_at       TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_campanha_data   ON public.campanhas_vacinacao(data_inicio);
CREATE INDEX idx_campanha_regiao ON public.campanhas_vacinacao(regiao);

-- =========================================================
-- DOSES MÉDIAS DE TRATAMENTO
-- Ideia 21 — Impacto Social em Tempo Real
-- =========================================================
CREATE TABLE public.doses_medias_tratamento (
    id_dose              SERIAL PRIMARY KEY,
    categoria            VARCHAR(100)   NOT NULL,
    doses_por_tratamento NUMERIC(8,2)   NOT NULL,
    created_at           TIMESTAMP      DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- SAZONALIDADE REGIONAL
-- Ideia 03 — Score Ajustado por Sazonalidade Regional
-- =========================================================
CREATE TABLE public.sazonalidade_regional (
    id_sazonalidade SERIAL PRIMARY KEY,
    regiao          VARCHAR(50)  NOT NULL,
    categoria       VARCHAR(100) NOT NULL,
    mes             INT          NOT NULL CHECK (mes BETWEEN 1 AND 12),
    fator_ajuste    NUMERIC(5,2) NOT NULL,
    created_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_sazonalidade_regiao ON public.sazonalidade_regional(regiao, categoria);
