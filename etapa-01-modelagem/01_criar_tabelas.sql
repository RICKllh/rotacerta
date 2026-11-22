-- =====================================================================
-- RotaCerta | Banco de dados de uma transportadora fictícia
-- Etapa 1: Modelagem (criação do banco e das tabelas)
-- Compatível com MySQL 8.0.16 ou superior
-- =====================================================================

-- Apaga o banco se ele já existir (permite rodar o script de novo do zero)
DROP DATABASE IF EXISTS rotacerta;

-- Cria o banco com suporte completo a acentos e emojis
CREATE DATABASE rotacerta
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE rotacerta;

-- ---------------------------------------------------------------------
-- 1. CIDADES: cidades do Sudeste atendidas pela transportadora
-- ---------------------------------------------------------------------
CREATE TABLE cidades (
  id_cidade   INT          AUTO_INCREMENT PRIMARY KEY,
  nome        VARCHAR(80)  NOT NULL,
  uf          CHAR(2)      NOT NULL,
  CONSTRAINT uq_cidade_uf UNIQUE (nome, uf),
  CONSTRAINT ck_cidade_uf CHECK (uf IN ('SP', 'RJ', 'MG', 'ES'))
);

-- ---------------------------------------------------------------------
-- 2. CLIENTES: empresas que contratam o frete
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
  id_cliente     INT           AUTO_INCREMENT PRIMARY KEY,
  razao_social   VARCHAR(120)  NOT NULL,
  cnpj           CHAR(14)      NOT NULL,
  segmento       VARCHAR(30)   NOT NULL,
  id_cidade      INT           NOT NULL,
  data_cadastro  DATE          NOT NULL,
  ativo          BOOLEAN       NOT NULL DEFAULT TRUE,
  CONSTRAINT uq_cliente_cnpj UNIQUE (cnpj),
  CONSTRAINT ck_cliente_segmento
    CHECK (segmento IN ('Varejo', 'Indústria', 'E-commerce', 'Atacado', 'Farmacêutico')),
  CONSTRAINT fk_cliente_cidade
    FOREIGN KEY (id_cidade) REFERENCES cidades (id_cidade)
);

-- ---------------------------------------------------------------------
-- 3. CENTROS DE DISTRIBUIÇÃO (CDs): armazéns de onde as cargas saem
-- ---------------------------------------------------------------------
CREATE TABLE centros_distribuicao (
  id_cd                INT          AUTO_INCREMENT PRIMARY KEY,
  nome                 VARCHAR(60)  NOT NULL,
  id_cidade            INT          NOT NULL,
  capacidade_paletes   INT          NOT NULL,
  CONSTRAINT uq_cd_nome UNIQUE (nome),
  CONSTRAINT ck_cd_capacidade CHECK (capacidade_paletes > 0),
  CONSTRAINT fk_cd_cidade
    FOREIGN KEY (id_cidade) REFERENCES cidades (id_cidade)
);

-- ---------------------------------------------------------------------
-- 4. ESTOQUE NO ARMAZÉM: quanto de cada cliente está guardado em cada CD
--    (chave primária composta: um registro por CD + cliente)
-- ---------------------------------------------------------------------
CREATE TABLE estoque_cd (
  id_cd          INT            NOT NULL,
  id_cliente     INT            NOT NULL,
  paletes        INT            NOT NULL DEFAULT 0,
  peso_kg        DECIMAL(10,2)  NOT NULL DEFAULT 0,
  atualizado_em  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                                ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id_cd, id_cliente),
  CONSTRAINT ck_estoque_paletes CHECK (paletes >= 0),
  CONSTRAINT ck_estoque_peso    CHECK (peso_kg >= 0),
  CONSTRAINT fk_estoque_cd
    FOREIGN KEY (id_cd) REFERENCES centros_distribuicao (id_cd),
  CONSTRAINT fk_estoque_cliente
    FOREIGN KEY (id_cliente) REFERENCES clientes (id_cliente)
);

-- ---------------------------------------------------------------------
-- 5. CAMINHÕES: a frota própria
-- ---------------------------------------------------------------------
CREATE TABLE caminhoes (
  id_caminhao     INT            AUTO_INCREMENT PRIMARY KEY,
  placa           CHAR(7)        NOT NULL,
  modelo          VARCHAR(40)    NOT NULL,
  tipo            ENUM('VUC', 'Toco', 'Truck', 'Carreta') NOT NULL,
  capacidade_kg   DECIMAL(10,2)  NOT NULL,
  ano_fabricacao  SMALLINT       NOT NULL,
  consumo_km_l    DECIMAL(4,2)   NOT NULL,
  status          ENUM('disponivel', 'em_viagem', 'manutencao')
                                 NOT NULL DEFAULT 'disponivel',
  id_cd_base      INT            NOT NULL,
  CONSTRAINT uq_caminhao_placa UNIQUE (placa),
  CONSTRAINT ck_caminhao_capacidade CHECK (capacidade_kg > 0),
  CONSTRAINT ck_caminhao_ano  CHECK (ano_fabricacao BETWEEN 2000 AND 2030),
  CONSTRAINT ck_caminhao_consumo CHECK (consumo_km_l > 0),
  CONSTRAINT fk_caminhao_cd
    FOREIGN KEY (id_cd_base) REFERENCES centros_distribuicao (id_cd)
);

-- ---------------------------------------------------------------------
-- 6. MANUTENÇÕES: histórico de manutenção de cada caminhão
-- ---------------------------------------------------------------------
CREATE TABLE manutencoes (
  id_manutencao  INT            AUTO_INCREMENT PRIMARY KEY,
  id_caminhao    INT            NOT NULL,
  tipo           ENUM('preventiva', 'corretiva') NOT NULL,
  data_inicio    DATE           NOT NULL,
  data_fim       DATE           NULL,          -- NULL = ainda na oficina
  custo          DECIMAL(10,2)  NOT NULL DEFAULT 0,
  descricao      VARCHAR(200)   NULL,
  CONSTRAINT ck_manut_datas CHECK (data_fim IS NULL OR data_fim >= data_inicio),
  CONSTRAINT ck_manut_custo CHECK (custo >= 0),
  CONSTRAINT fk_manut_caminhao
    FOREIGN KEY (id_caminhao) REFERENCES caminhoes (id_caminhao)
);

-- ---------------------------------------------------------------------
-- 7. MOTORISTAS
-- ---------------------------------------------------------------------
CREATE TABLE motoristas (
  id_motorista   INT          AUTO_INCREMENT PRIMARY KEY,
  nome           VARCHAR(100) NOT NULL,
  cpf            CHAR(11)     NOT NULL,
  cnh_numero     CHAR(11)     NOT NULL,
  cnh_categoria  ENUM('C', 'D', 'E') NOT NULL,
  cnh_validade   DATE         NOT NULL,
  data_admissao  DATE         NOT NULL,
  ativo          BOOLEAN      NOT NULL DEFAULT TRUE,
  CONSTRAINT uq_motorista_cpf UNIQUE (cpf),
  CONSTRAINT uq_motorista_cnh UNIQUE (cnh_numero)
);

-- ---------------------------------------------------------------------
-- 8. ROTAS: trajeto de um CD até uma cidade de destino
-- ---------------------------------------------------------------------
CREATE TABLE rotas (
  id_rota            INT           AUTO_INCREMENT PRIMARY KEY,
  id_cd_origem       INT           NOT NULL,
  id_cidade_destino  INT           NOT NULL,
  distancia_km       DECIMAL(7,1)  NOT NULL,
  prazo_horas        SMALLINT      NOT NULL,   -- prazo padrão (SLA) da rota
  pedagio            DECIMAL(8,2)  NOT NULL DEFAULT 0,
  CONSTRAINT uq_rota UNIQUE (id_cd_origem, id_cidade_destino),
  CONSTRAINT ck_rota_distancia CHECK (distancia_km > 0),
  CONSTRAINT ck_rota_prazo     CHECK (prazo_horas > 0),
  CONSTRAINT fk_rota_cd
    FOREIGN KEY (id_cd_origem) REFERENCES centros_distribuicao (id_cd),
  CONSTRAINT fk_rota_cidade
    FOREIGN KEY (id_cidade_destino) REFERENCES cidades (id_cidade)
);

-- ---------------------------------------------------------------------
-- 9. VIAGENS: um caminhão + um motorista fazendo uma rota
-- ---------------------------------------------------------------------
CREATE TABLE viagens (
  id_viagem          INT           AUTO_INCREMENT PRIMARY KEY,
  id_rota            INT           NOT NULL,
  id_caminhao        INT           NOT NULL,
  id_motorista       INT           NOT NULL,
  saida_prevista     DATETIME      NOT NULL,
  saida_real         DATETIME      NULL,
  chegada_real       DATETIME      NULL,
  km_rodados         DECIMAL(7,1)  NULL,
  custo_combustivel  DECIMAL(10,2) NULL,
  custo_pedagio      DECIMAL(10,2) NULL,
  status             ENUM('planejada', 'em_andamento', 'concluida', 'cancelada')
                                   NOT NULL DEFAULT 'planejada',
  CONSTRAINT ck_viagem_datas
    CHECK (chegada_real IS NULL OR saida_real IS NULL OR chegada_real > saida_real),
  CONSTRAINT ck_viagem_km CHECK (km_rodados IS NULL OR km_rodados > 0),
  CONSTRAINT fk_viagem_rota
    FOREIGN KEY (id_rota) REFERENCES rotas (id_rota),
  CONSTRAINT fk_viagem_caminhao
    FOREIGN KEY (id_caminhao) REFERENCES caminhoes (id_caminhao),
  CONSTRAINT fk_viagem_motorista
    FOREIGN KEY (id_motorista) REFERENCES motoristas (id_motorista)
);

-- ---------------------------------------------------------------------
-- 10. PEDIDOS DE FRETE: o que o cliente contratou
--     Vários pedidos podem ir juntos na mesma viagem.
-- ---------------------------------------------------------------------
CREATE TABLE pedidos (
  id_pedido          INT            AUTO_INCREMENT PRIMARY KEY,
  id_cliente         INT            NOT NULL,
  id_cd_origem       INT            NOT NULL,
  id_cidade_destino  INT            NOT NULL,
  id_viagem          INT            NULL,      -- NULL = ainda não escalado
  data_pedido        DATETIME       NOT NULL,
  prazo_entrega      DATETIME       NOT NULL,  -- data/hora limite (SLA)
  data_entrega       DATETIME       NULL,      -- NULL = ainda não entregue
  peso_kg            DECIMAL(10,2)  NOT NULL,
  paletes            SMALLINT       NOT NULL,
  valor_mercadoria   DECIMAL(12,2)  NOT NULL,
  valor_frete        DECIMAL(10,2)  NOT NULL,
  status             ENUM('aguardando', 'em_transito', 'entregue', 'atrasado', 'cancelado')
                                    NOT NULL DEFAULT 'aguardando',
  CONSTRAINT ck_pedido_peso    CHECK (peso_kg > 0),
  CONSTRAINT ck_pedido_paletes CHECK (paletes > 0),
  CONSTRAINT ck_pedido_valores CHECK (valor_mercadoria >= 0 AND valor_frete >= 0),
  CONSTRAINT ck_pedido_prazo   CHECK (prazo_entrega > data_pedido),
  CONSTRAINT ck_pedido_entrega CHECK (data_entrega IS NULL OR data_entrega > data_pedido),
  CONSTRAINT fk_pedido_cliente
    FOREIGN KEY (id_cliente) REFERENCES clientes (id_cliente),
  CONSTRAINT fk_pedido_cd
    FOREIGN KEY (id_cd_origem) REFERENCES centros_distribuicao (id_cd),
  CONSTRAINT fk_pedido_cidade
    FOREIGN KEY (id_cidade_destino) REFERENCES cidades (id_cidade),
  CONSTRAINT fk_pedido_viagem
    FOREIGN KEY (id_viagem) REFERENCES viagens (id_viagem)
);

-- ---------------------------------------------------------------------
-- 11. OCORRÊNCIAS: problemas registrados durante a entrega
-- ---------------------------------------------------------------------
CREATE TABLE ocorrencias (
  id_ocorrencia  INT            AUTO_INCREMENT PRIMARY KEY,
  id_pedido      INT            NOT NULL,
  tipo           ENUM('atraso', 'avaria', 'cliente_ausente',
                      'endereco_incorreto', 'extravio') NOT NULL,
  data_hora      DATETIME       NOT NULL,
  descricao      VARCHAR(200)   NULL,
  custo          DECIMAL(10,2)  NOT NULL DEFAULT 0,  -- prejuízo/indenização
  CONSTRAINT ck_ocorrencia_custo CHECK (custo >= 0),
  CONSTRAINT fk_ocorrencia_pedido
    FOREIGN KEY (id_pedido) REFERENCES pedidos (id_pedido)
);

-- ---------------------------------------------------------------------
-- ÍNDICES: aceleram as buscas e os relatórios mais usados
-- (o MySQL já cria índice sozinho para PRIMARY KEY, UNIQUE e FOREIGN KEY)
-- ---------------------------------------------------------------------
CREATE INDEX idx_pedidos_status_prazo ON pedidos (status, prazo_entrega);
CREATE INDEX idx_pedidos_data         ON pedidos (data_pedido);
CREATE INDEX idx_viagens_saida        ON viagens (saida_prevista);
CREATE INDEX idx_viagens_status       ON viagens (status);
CREATE INDEX idx_motoristas_cnh_val   ON motoristas (cnh_validade);
CREATE INDEX idx_ocorrencias_tipo     ON ocorrencias (tipo, data_hora);

-- Conferência: lista as 11 tabelas criadas
SHOW TABLES;
