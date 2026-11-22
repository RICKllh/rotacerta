# Etapa 1: Modelagem do banco RotaCerta

**Tempo:** 2 sessões de 20 a 30 minutos
**Você vai precisar de:** MySQL 8 e MySQL Workbench instalados no Windows
**Arquivo de gabarito:** `01_criar_tabelas.sql` (o script completo, já testado)

---

## Parte 0. Instalar o MySQL (só na primeira vez, uns 15 minutos)

1. Acesse https://dev.mysql.com/downloads/installer/ e baixe o **MySQL Installer for Windows** (o arquivo maior, "mysql-installer-community").
2. Na tela de login, clique em **"No thanks, just start my download"**.
3. Abra o instalador e escolha **"Full"** (ou "Custom" marcando *MySQL Server 8* e *MySQL Workbench 8*).
4. Siga clicando em **Next / Execute**. Quando pedir uma senha para o usuário **root**, crie uma e **anote** (você vai usar sempre).
5. No final, abra o **MySQL Workbench**, clique na conexão **"Local instance MySQL80"** e digite a senha.

Pronto: a tela grande no meio é onde você escreve os comandos. Para rodar, use:
- **Ctrl + Shift + Enter**: roda tudo que está na tela (ou o que estiver selecionado)
- **Ctrl + Enter**: roda só o comando onde o cursor está

> Dica: salve seu trabalho com Ctrl + S num arquivo chamado `01_criar_tabelas.sql`. É esse arquivo que vai para o GitHub.

---

## Parte 1. Entender a ideia antes de digitar (5 minutos)

Um banco de dados é um conjunto de **tabelas** que conversam entre si. Antes de criar, o profissional **modela**: decide quais tabelas existem e como se ligam. Isso é exatamente o que um Product Owner faz quando entende "quais informações o negócio precisa guardar".

Abra a imagem `diagrama_er.png`. Cada caixa é uma tabela. As linhas mostram as ligações:

| Bloco | Tabelas | Pergunta de negócio que responde |
|---|---|---|
| Azul | cidades, clientes | Quem contrata e onde fica? |
| Verde | centros_distribuicao, estoque_cd | De onde a carga sai e o que está guardado? |
| Laranja | caminhoes, manutencoes, motoristas | Com que recursos fazemos o transporte? |
| Roxo | rotas, viagens | Que caminho foi feito, por quem e quando? |
| Vermelho | pedidos, ocorrencias | O que o cliente pediu e o que deu errado? |

A ligação mais importante: **um pedido vai dentro de uma viagem**, e **uma viagem pode levar vários pedidos** (é assim que se aproveita o caminhão).

### 4 palavras que você vai usar o projeto inteiro

- **PRIMARY KEY (PK), chave primária:** o "RG" de cada linha. Nunca se repete. Ex.: `id_cliente`.
- **FOREIGN KEY (FK), chave estrangeira:** uma coluna que aponta para o RG de outra tabela. Ex.: `pedidos.id_cliente` aponta para `clientes.id_cliente`. O banco **não deixa** cadastrar pedido para um cliente que não existe.
- **CHECK:** uma regra de negócio dentro da tabela. Ex.: peso precisa ser maior que zero.
- **UNIQUE:** proíbe repetição. Ex.: dois caminhões com a mesma placa.

---

## Parte 2. Criar o banco (5 minutos)

Digite e rode (Ctrl + Shift + Enter):

```sql
DROP DATABASE IF EXISTS rotacerta;

CREATE DATABASE rotacerta
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE rotacerta;
```

**Por quê?**
- `DROP DATABASE IF EXISTS` apaga o banco se ele já existir. Assim você pode rodar o script quantas vezes quiser começando do zero. (Cuidado: em empresa de verdade, isso nunca se roda em produção!)
- `utf8mb4` garante que "São Paulo" e "Vitória" fiquem com acento certo.
- `USE rotacerta` diz: "a partir de agora, trabalhe dentro deste banco".

Clique no ícone de atualizar (🔄) no painel **SCHEMAS** à esquerda: o banco `rotacerta` aparece.

---

## Parte 3. As 3 primeiras tabelas, digitando com calma (15 minutos)

### 3.1 Cidades

```sql
CREATE TABLE cidades (
  id_cidade   INT          AUTO_INCREMENT PRIMARY KEY,
  nome        VARCHAR(80)  NOT NULL,
  uf          CHAR(2)      NOT NULL,
  CONSTRAINT uq_cidade_uf UNIQUE (nome, uf),
  CONSTRAINT ck_cidade_uf CHECK (uf IN ('SP', 'RJ', 'MG', 'ES'))
);
```

Linha por linha:
- `INT AUTO_INCREMENT PRIMARY KEY`: número inteiro que o MySQL preenche sozinho (1, 2, 3...).
- `VARCHAR(80)`: texto de até 80 letras. `CHAR(2)`: texto de tamanho fixo, sempre 2 (a sigla do estado).
- `NOT NULL`: campo obrigatório.
- `CONSTRAINT uq_cidade_uf UNIQUE (nome, uf)`: não pode existir duas vezes "Santos, SP". Repare que damos **nome** à regra (`uq_...`). Quando der erro, o MySQL mostra esse nome e você sabe na hora qual regra foi quebrada.
- `CHECK (uf IN (...))`: a RotaCerta só atende o Sudeste. Qualquer outro estado é recusado.

> Padrão de nomes que usamos: `uq_` = único, `ck_` = check, `fk_` = chave estrangeira, `idx_` = índice. Recrutador técnico repara nesses detalhes.

### 3.2 Clientes

```sql
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
```

Novidades:
- `DATE`: só a data (ano-mês-dia).
- `BOOLEAN ... DEFAULT TRUE`: verdadeiro/falso. Se você não informar, o cliente entra como ativo.
- `FOREIGN KEY (id_cidade) REFERENCES cidades (id_cidade)`: a primeira ligação entre tabelas. Por isso **cidades tem que ser criada antes de clientes**: não dá para apontar para algo que ainda não existe.

### 3.3 Centros de distribuição

```sql
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
```

Palete é a unidade padrão de armazém em logística. A capacidade do CD é medida em paletes.

**Fim da primeira sessão.** Salve o arquivo (Ctrl + S).

---

## Parte 4. As outras 8 tabelas (segunda sessão, 20 minutos)

Agora você já entendeu o padrão. Abra `01_criar_tabelas.sql`, copie as tabelas de 4 a 11 **uma por vez**, cole no seu arquivo e rode cada uma. Antes de rodar, leia e tente responder a pergunta da tabela:

| Tabela | O que tem de novo | Pergunte-se |
|---|---|---|
| `estoque_cd` | **Chave primária composta** `PRIMARY KEY (id_cd, id_cliente)`: uma linha por CD + cliente. `ON UPDATE CURRENT_TIMESTAMP` grava sozinho a hora da última mudança. | Por que não precisa de um `id` próprio? |
| `caminhoes` | `ENUM('VUC','Toco','Truck','Carreta')`: só aceita esses valores. `DECIMAL(10,2)`: número com 2 casas decimais, o tipo certo para peso e dinheiro. | Por que a placa é UNIQUE? |
| `manutencoes` | `data_fim NULL`: se estiver vazio, o caminhão ainda está na oficina. CHECK com duas colunas: o fim não pode ser antes do início. | Como saber quais caminhões estão parados agora? |
| `motoristas` | `cnh_validade`: a base da regra da Etapa 3 ("não escalar motorista com CNH vencida"). | Por que guardar a categoria da CNH? (Carreta exige categoria E.) |
| `rotas` | UNIQUE de duas colunas: só existe **uma** rota de cada CD para cada cidade. `prazo_horas` é o SLA. | O que é SLA? (o prazo prometido ao cliente) |
| `viagens` | Três FKs na mesma tabela. Colunas "previsto" x "real": é a diferença entre elas que gera os indicadores. | Que pergunta dá para responder comparando `saida_prevista` e `saida_real`? |
| `pedidos` | `id_viagem NULL`: o pedido chega antes de ser colocado num caminhão. `prazo_entrega` x `data_entrega` = entregue no prazo ou não (o **OTD** da Etapa 4). | Por que `valor_frete` e `valor_mercadoria` são colunas separadas? |
| `ocorrencias` | `custo`: o prejuízo de uma avaria ou extravio. | Que tipo de ocorrência mais custa dinheiro? |

> **Ordem importa:** sempre crie a tabela "pai" antes da "filha". Por isso `viagens` vem antes de `pedidos`, e `pedidos` antes de `ocorrencias`.

### Os índices

No final do script há 6 linhas `CREATE INDEX`. Um índice funciona como o **índice remissivo de um livro**: em vez de ler a tabela inteira, o MySQL vai direto ao ponto. Criamos índices nas colunas que mais vão aparecer nos relatórios (status, datas, validade da CNH). PK, UNIQUE e FK já ganham índice automático.

Rode o bloco de índices e, por fim:

```sql
SHOW TABLES;
```

Deve aparecer **11 tabelas**. ✅

---

## Parte 5. Teste as regras: tente quebrar o banco (5 minutos)

Esta é a parte divertida, e um ótimo print para o LinkedIn. Rode **um comando de cada vez** (Ctrl + Enter) e veja o erro na aba **Output** lá embaixo:

```sql
-- 1) Funciona:
INSERT INTO cidades (nome, uf) VALUES ('São Paulo', 'SP');

-- 2) Erro: Curitiba é do PR, fora do Sudeste
INSERT INTO cidades (nome, uf) VALUES ('Curitiba', 'PR');
-- Esperado: Check constraint 'ck_cidade_uf' is violated.

-- 3) Erro: São Paulo/SP já existe
INSERT INTO cidades (nome, uf) VALUES ('São Paulo', 'SP');
-- Esperado: Duplicate entry 'São Paulo-SP' for key 'cidades.uq_cidade_uf'

-- 4) Erro: a cidade 99 não existe
INSERT INTO clientes (razao_social, cnpj, segmento, id_cidade, data_cadastro)
VALUES ('Teste Ltda', '12345678000199', 'Varejo', 99, '2025-01-01');
-- Esperado: Cannot add or update a child row: a foreign key constraint fails
```

Cada erro é o banco **protegendo a qualidade dos dados**. Em vez de "a planilha tem lixo", o lixo nem entra.

Para limpar o teste, rode o script inteiro de novo (o `DROP DATABASE` do começo zera tudo).

---

## Parte 6. Gerar o seu próprio diagrama no Workbench (opcional, 5 minutos)

O `diagrama_er.png` já está pronto, mas fazer o seu é um bom exercício:

1. Menu **Database > Reverse Engineer...**
2. Next, digite a senha, marque o banco **rotacerta**, Next até o fim.
3. O Workbench desenha as tabelas. Arraste as caixas para organizar.
4. **File > Export > Export as PNG**.

---

## Checklist da etapa

- [ ] MySQL e Workbench instalados
- [ ] Banco `rotacerta` criado com 11 tabelas
- [ ] Testei os 4 comandos da Parte 5 e vi os erros
- [ ] Arquivo `01_criar_tabelas.sql` salvo
- [ ] Sei explicar com minhas palavras: PK, FK, CHECK e UNIQUE

**Próxima etapa:** encher o banco com 1 ano de dados fictícios (cidades do Sudeste, clientes, frota, milhares de pedidos).
