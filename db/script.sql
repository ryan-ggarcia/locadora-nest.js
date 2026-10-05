-- =========================================
-- BANCO DE DADOS - LOCADORA DE VEÍCULOS
-- Requer MySQL 8.0.16+ (CHECK constraints)
-- =========================================

CREATE DATABASE IF NOT EXISTS locadora
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE locadora;


-- =========================================
-- LIMPEZA (ordem inversa das dependências)
-- =========================================

DROP TABLE IF EXISTS tb_manutencao;
DROP TABLE IF EXISTS tb_locacao;
DROP TABLE IF EXISTS tb_veiculo;
DROP TABLE IF EXISTS tb_categoria;
DROP TABLE IF EXISTS tb_cliente;
DROP TABLE IF EXISTS tb_usuario;


-- =========================================
-- TABELA DE USUÁRIOS (funcionários que acessam a API)
-- =========================================

CREATE TABLE tb_usuario (
    usu_cod    INT AUTO_INCREMENT PRIMARY KEY,
    usu_nome   VARCHAR(100) NOT NULL,
    usu_email  VARCHAR(100) NOT NULL UNIQUE,
    usu_senha  VARCHAR(255) NOT NULL,                     -- hash bcrypt
    usu_perfil VARCHAR(20)  NOT NULL DEFAULT 'ATENDENTE',
    usu_ativo  BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_usu_perfil CHECK (usu_perfil IN ('ADMIN', 'ATENDENTE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =========================================
-- TABELA DE CLIENTES (quem aluga o veículo)
-- =========================================

CREATE TABLE tb_cliente (
    cli_cod            INT AUTO_INCREMENT PRIMARY KEY,
    cli_nome           VARCHAR(100) NOT NULL,
    cli_cpf            CHAR(11)     NOT NULL UNIQUE,      -- somente números
    cli_email          VARCHAR(100) NOT NULL,
    cli_telefone       VARCHAR(20),
    cli_datanascimento DATE         NOT NULL,
    cli_cnh            VARCHAR(11)  NOT NULL UNIQUE,
    cli_cnhvalidade    DATE         NOT NULL,
    cli_ativo          BOOLEAN      NOT NULL DEFAULT TRUE,
    cli_datacadastro   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =========================================
-- TABELA DE CATEGORIAS (define preço e regras)
-- =========================================

CREATE TABLE tb_categoria (
    cat_cod              INT AUTO_INCREMENT PRIMARY KEY,
    cat_nome             VARCHAR(50)   NOT NULL UNIQUE,
    cat_valordiaria      DECIMAL(10,2) NOT NULL,
    cat_kmlivrediaria    INT           NOT NULL,          -- km incluídos por diária
    cat_valorkmexcedente DECIMAL(10,2) NOT NULL,          -- valor por km acima do livre
    cat_idademinima      INT           NOT NULL DEFAULT 21,
    cat_ativo            BOOLEAN       NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_cat_valordiaria  CHECK (cat_valordiaria > 0),
    CONSTRAINT chk_cat_kmlivre      CHECK (cat_kmlivrediaria >= 0),
    CONSTRAINT chk_cat_valorkm      CHECK (cat_valorkmexcedente >= 0),
    CONSTRAINT chk_cat_idademinima  CHECK (cat_idademinima >= 18)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =========================================
-- TABELA DE VEÍCULOS
-- =========================================

CREATE TABLE tb_veiculo (
    vei_cod             INT AUTO_INCREMENT PRIMARY KEY,
    cat_cod             INT          NOT NULL,
    vei_placa           CHAR(7)      NOT NULL UNIQUE,     -- padrão Mercosul, sem hífen
    vei_marca           VARCHAR(50)  NOT NULL,
    vei_modelo          VARCHAR(80)  NOT NULL,
    vei_ano             INT          NOT NULL,
    vei_cor             VARCHAR(30),
    vei_kmatual         INT          NOT NULL DEFAULT 0,
    vei_kmultimarevisao INT          NOT NULL DEFAULT 0,
    vei_situacao        VARCHAR(20)  NOT NULL DEFAULT 'DISPONIVEL',

    CONSTRAINT fk_veiculo_categoria
        FOREIGN KEY (cat_cod) REFERENCES tb_categoria(cat_cod),

    CONSTRAINT chk_vei_situacao
        CHECK (vei_situacao IN ('DISPONIVEL', 'LOCADO', 'MANUTENCAO', 'INATIVO')),
    CONSTRAINT chk_vei_km
        CHECK (vei_kmatual >= 0 AND vei_kmultimarevisao >= 0
               AND vei_kmultimarevisao <= vei_kmatual),
    CONSTRAINT chk_vei_ano
        CHECK (vei_ano >= 1990)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =========================================
-- TABELA DE LOCAÇÕES
-- Ciclo de vida: RESERVADA -> ATIVA -> FINALIZADA
--                RESERVADA -> CANCELADA
-- =========================================

CREATE TABLE tb_locacao (
    loc_cod                 INT AUTO_INCREMENT PRIMARY KEY,
    cli_cod                 INT      NOT NULL,
    vei_cod                 INT      NOT NULL,
    usu_cod                 INT      NOT NULL,            -- funcionário que fez a reserva

    -- Datas
    loc_datareserva         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    loc_dataretirada        DATETIME NOT NULL,            -- agendada
    loc_dataprevista        DATETIME NOT NULL,            -- devolução prevista
    loc_dataretiradaefetiva DATETIME NULL,
    loc_datadevolucao       DATETIME NULL,
    loc_datacancelamento    DATETIME NULL,
    loc_motivocancelamento  VARCHAR(20) NULL,

    -- Quilometragem
    loc_kmretirada          INT NULL,
    loc_kmdevolucao         INT NULL,

    -- "Foto" dos preços da categoria no momento da reserva
    loc_valordiaria         DECIMAL(10,2) NOT NULL,
    loc_kmlivrediaria       INT           NOT NULL,
    loc_valorkmexcedente    DECIMAL(10,2) NOT NULL,
    loc_valorprevisto       DECIMAL(10,2) NOT NULL,

    -- Fechamento (preenchido na devolução ou no cancelamento)
    loc_qtddiarias          INT           NULL,
    loc_valordiarias        DECIMAL(10,2) NULL,
    loc_valorkmextra        DECIMAL(10,2) NULL,
    loc_valormulta          DECIMAL(10,2) NULL,
    loc_valortaxacancelamento DECIMAL(10,2) NULL,
    loc_valortotal          DECIMAL(10,2) NULL,

    loc_situacao            VARCHAR(20) NOT NULL DEFAULT 'RESERVADA',

    -- Garante no máximo UMA locação ATIVA por veículo
    loc_veiculoativo INT GENERATED ALWAYS AS
        (CASE WHEN loc_situacao = 'ATIVA' THEN vei_cod END) STORED,

    CONSTRAINT fk_locacao_cliente FOREIGN KEY (cli_cod) REFERENCES tb_cliente(cli_cod),
    CONSTRAINT fk_locacao_veiculo FOREIGN KEY (vei_cod) REFERENCES tb_veiculo(vei_cod),
    CONSTRAINT fk_locacao_usuario FOREIGN KEY (usu_cod) REFERENCES tb_usuario(usu_cod),

    CONSTRAINT uq_locacao_veiculoativo UNIQUE (loc_veiculoativo),

    CONSTRAINT chk_loc_situacao
        CHECK (loc_situacao IN ('RESERVADA', 'ATIVA', 'FINALIZADA', 'CANCELADA')),
    CONSTRAINT chk_loc_motivo
        CHECK (loc_motivocancelamento IS NULL
               OR loc_motivocancelamento IN ('CLIENTE', 'EMPRESA')),
    CONSTRAINT chk_loc_periodo
        CHECK (loc_dataprevista > loc_dataretirada),
    CONSTRAINT chk_loc_km
        CHECK (loc_kmdevolucao IS NULL OR loc_kmdevolucao >= loc_kmretirada),
    CONSTRAINT chk_loc_valores
        CHECK (loc_valordiaria > 0 AND loc_valorprevisto >= 0
               AND (loc_valortotal IS NULL OR loc_valortotal >= 0)
               AND (loc_valormulta IS NULL OR loc_valormulta >= 0)
               AND (loc_valorkmextra IS NULL OR loc_valorkmextra >= 0)),

    -- Cada situação exige um conjunto coerente de campos preenchidos
    CONSTRAINT chk_loc_estado CHECK (
        (loc_situacao = 'RESERVADA'
            AND loc_dataretiradaefetiva IS NULL
            AND loc_datadevolucao IS NULL
            AND loc_datacancelamento IS NULL)
        OR
        (loc_situacao = 'ATIVA'
            AND loc_dataretiradaefetiva IS NOT NULL
            AND loc_kmretirada IS NOT NULL
            AND loc_datadevolucao IS NULL
            AND loc_datacancelamento IS NULL)
        OR
        (loc_situacao = 'FINALIZADA'
            AND loc_dataretiradaefetiva IS NOT NULL
            AND loc_datadevolucao IS NOT NULL
            AND loc_kmdevolucao IS NOT NULL
            AND loc_qtddiarias IS NOT NULL
            AND loc_valortotal IS NOT NULL)
        OR
        (loc_situacao = 'CANCELADA'
            AND loc_dataretiradaefetiva IS NULL
            AND loc_datacancelamento IS NOT NULL
            AND loc_motivocancelamento IS NOT NULL
            AND loc_valortotal IS NOT NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Acelera a verificação de conflito de período por veículo
CREATE INDEX idx_locacao_periodo
    ON tb_locacao (vei_cod, loc_situacao, loc_dataretirada, loc_dataprevista);


-- =========================================
-- TABELA DE MANUTENÇÕES
-- =========================================

CREATE TABLE tb_manutencao (
    man_cod        INT AUTO_INCREMENT PRIMARY KEY,
    vei_cod        INT           NOT NULL,
    usu_cod        INT           NOT NULL,
    man_tipo       VARCHAR(20)   NOT NULL,
    man_descricao  VARCHAR(255)  NOT NULL,
    man_kmveiculo  INT           NOT NULL,
    man_datainicio DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    man_datafim    DATETIME      NULL,
    man_valor      DECIMAL(10,2) NULL,
    man_situacao   VARCHAR(20)   NOT NULL DEFAULT 'ABERTA',

    -- Garante no máximo UMA manutenção ABERTA por veículo
    man_veiculoaberta INT GENERATED ALWAYS AS
        (CASE WHEN man_situacao = 'ABERTA' THEN vei_cod END) STORED,

    CONSTRAINT fk_manutencao_veiculo FOREIGN KEY (vei_cod) REFERENCES tb_veiculo(vei_cod),
    CONSTRAINT fk_manutencao_usuario FOREIGN KEY (usu_cod) REFERENCES tb_usuario(usu_cod),

    CONSTRAINT uq_manutencao_veiculoaberta UNIQUE (man_veiculoaberta),

    CONSTRAINT chk_man_tipo
        CHECK (man_tipo IN ('PREVENTIVA', 'CORRETIVA')),
    CONSTRAINT chk_man_estado CHECK (
        (man_situacao = 'ABERTA'
            AND man_datafim IS NULL)
        OR
        (man_situacao = 'FINALIZADA'
            AND man_datafim IS NOT NULL
            AND man_datafim >= man_datainicio
            AND man_valor IS NOT NULL
            AND man_valor >= 0)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =========================================
-- DADOS PARA TESTES
-- Senha de todos os usuários: 123456
-- =========================================

INSERT INTO tb_usuario (usu_nome, usu_email, usu_senha, usu_perfil) VALUES
('Administrador', 'admin@locadora.com',
 '$2b$10$9BQGPMr55q3Ra2eU6lvyOe7V9eqgsd00AbqjoFIbOVTQ3Z8ctVTXm', 'ADMIN'),
('Atendente',     'atendente@locadora.com',
 '$2b$10$9BQGPMr55q3Ra2eU6lvyOe7V9eqgsd00AbqjoFIbOVTQ3Z8ctVTXm', 'ATENDENTE');


INSERT INTO tb_categoria
(cat_nome, cat_valordiaria, cat_kmlivrediaria, cat_valorkmexcedente, cat_idademinima) VALUES
('Econômico',     99.90, 150, 0.75, 18),
('Intermediário', 149.90, 200, 0.95, 21),
('SUV',           249.90, 250, 1.40, 25);


-- Cenários pensados para testar as regras (ver README)
INSERT INTO tb_cliente
(cli_nome, cli_cpf, cli_email, cli_telefone, cli_datanascimento, cli_cnh, cli_cnhvalidade, cli_ativo) VALUES
('Ana Souza',      '12345678901', 'ana@email.com',     '(18) 98888-0001', '1990-05-12', '00000000001', '2029-08-01', TRUE),  -- cliente "ok"
('Bruno Lima',     '12345678902', 'bruno@email.com',   '(18) 98888-0002', '2006-03-20', '00000000002', '2030-03-20', TRUE),  -- 20 anos: só Econômico
('Carla Mendes',   '12345678903', 'carla@email.com',   '(18) 98888-0003', '1988-11-02', '00000000003', '2025-12-31', TRUE),  -- CNH vencida
('Diego Rocha',    '12345678904', 'diego@email.com',   '(18) 98888-0004', '1995-07-15', '00000000004', '2031-01-10', FALSE), -- inativo
('Eduarda Castro', '12345678905', 'eduarda@email.com', '(18) 98888-0005', '1985-02-28', '00000000005', '2028-06-30', TRUE);  -- tem locação atrasada


INSERT INTO tb_veiculo
(cat_cod, vei_placa, vei_marca, vei_modelo, vei_ano, vei_cor, vei_kmatual, vei_kmultimarevisao, vei_situacao) VALUES
(1, 'ABC1D23', 'Fiat',      'Mobi',    2023, 'Branco', 15200, 10000, 'DISPONIVEL'),
(1, 'DEF4G56', 'Renault',   'Kwid',    2022, 'Prata',  29800, 20000, 'DISPONIVEL'),  -- faltam 200 km p/ revisão
(2, 'GHI7J89', 'Chevrolet', 'Onix',    2024, 'Preto',   8000,     0, 'LOCADO'),      -- locação atrasada
(3, 'JKL0M12', 'Jeep',      'Compass', 2024, 'Cinza',  12000, 10000, 'DISPONIVEL'),  -- tem reserva futura
(3, 'MNO3P45', 'Hyundai',   'Creta',   2021, 'Azul',   40500, 40000, 'MANUTENCAO'),
(2, 'PQR6S78', 'Volkswagen','Virtus',  2020, 'Branco', 90000, 80000, 'INATIVO');


-- Locação 1: FINALIZADA (Ana, Mobi) - 3 diárias, 400 km (dentro dos 450 livres)
INSERT INTO tb_locacao
(cli_cod, vei_cod, usu_cod, loc_datareserva, loc_dataretirada, loc_dataprevista,
 loc_dataretiradaefetiva, loc_datadevolucao, loc_kmretirada, loc_kmdevolucao,
 loc_valordiaria, loc_kmlivrediaria, loc_valorkmexcedente, loc_valorprevisto,
 loc_qtddiarias, loc_valordiarias, loc_valorkmextra, loc_valormulta, loc_valortotal,
 loc_situacao)
VALUES
(1, 1, 2, '2026-08-28 14:00:00', '2026-09-01 10:00:00', '2026-09-04 10:00:00',
 '2026-09-01 10:05:00', '2026-09-04 10:30:00', 14800, 15200,
 99.90, 150, 0.75, 299.70,
 3, 299.70, 0.00, 0.00, 299.70,
 'FINALIZADA');

-- Locação 2: ATIVA e ATRASADA (Eduarda, Onix) - datas relativas a hoje
INSERT INTO tb_locacao
(cli_cod, vei_cod, usu_cod, loc_datareserva, loc_dataretirada, loc_dataprevista,
 loc_dataretiradaefetiva, loc_kmretirada,
 loc_valordiaria, loc_kmlivrediaria, loc_valorkmexcedente, loc_valorprevisto,
 loc_situacao)
VALUES
(5, 3, 2,
 TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 6 DAY), '16:00:00'),
 TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 5 DAY), '10:00:00'),
 TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '10:00:00'),
 TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 5 DAY), '10:10:00'), 8000,
 149.90, 200, 0.95, 449.70,
 'ATIVA');

-- Locação 3: RESERVADA (Ana, Compass) - daqui a 3 dias, 2 diárias
INSERT INTO tb_locacao
(cli_cod, vei_cod, usu_cod, loc_dataretirada, loc_dataprevista,
 loc_valordiaria, loc_kmlivrediaria, loc_valorkmexcedente, loc_valorprevisto,
 loc_situacao)
VALUES
(1, 4, 2,
 TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 3 DAY), '09:00:00'),
 TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 5 DAY), '09:00:00'),
 249.90, 250, 1.40, 499.80,
 'RESERVADA');

-- Locação 4: CANCELADA pelo cliente com menos de 24h -> taxa de 1 diária
INSERT INTO tb_locacao
(cli_cod, vei_cod, usu_cod, loc_datareserva, loc_dataretirada, loc_dataprevista,
 loc_datacancelamento, loc_motivocancelamento,
 loc_valordiaria, loc_kmlivrediaria, loc_valorkmexcedente, loc_valorprevisto,
 loc_valortaxacancelamento, loc_valortotal,
 loc_situacao)
VALUES
(2, 1, 2, '2026-09-15 11:00:00', '2026-09-20 09:00:00', '2026-09-22 09:00:00',
 '2026-09-19 20:00:00', 'CLIENTE',
 99.90, 150, 0.75, 199.80,
 99.90, 99.90,
 'CANCELADA');


-- Manutenção finalizada (revisão do Compass aos 10.000 km)
INSERT INTO tb_manutencao
(vei_cod, usu_cod, man_tipo, man_descricao, man_kmveiculo,
 man_datainicio, man_datafim, man_valor, man_situacao)
VALUES
(4, 1, 'PREVENTIVA', 'Revisão dos 10.000 km', 10000,
 '2026-06-10 08:00:00', '2026-06-11 17:00:00', 450.00, 'FINALIZADA');

-- Manutenção aberta (Creta)
INSERT INTO tb_manutencao
(vei_cod, usu_cod, man_tipo, man_descricao, man_kmveiculo, man_datainicio)
VALUES
(5, 1, 'CORRETIVA', 'Troca da embreagem', 40500,
 TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '08:00:00'));


-- =========================================
-- CONSULTAS PARA TESTE
-- =========================================

SELECT * FROM tb_usuario;
SELECT * FROM tb_cliente;
SELECT * FROM tb_categoria;
SELECT * FROM tb_veiculo;
SELECT * FROM tb_locacao;
SELECT * FROM tb_manutencao;


-- Locações atrasadas (GET /locacoes/atrasadas)
SELECT l.loc_cod, c.cli_nome, v.vei_modelo, v.vei_placa, l.loc_dataprevista,
       TIMESTAMPDIFF(HOUR, l.loc_dataprevista, NOW()) AS horas_atraso
FROM tb_locacao l
JOIN tb_cliente c ON c.cli_cod = l.cli_cod
JOIN tb_veiculo v ON v.vei_cod = l.vei_cod
WHERE l.loc_situacao = 'ATIVA'
  AND l.loc_dataprevista < NOW();


-- Veículos disponíveis em um período (GET /veiculos/disponiveis)
-- Neste exemplo o Compass NÃO aparece, pois tem reserva que conflita.
SET @inicio = TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 4 DAY), '09:00:00');
SET @fim    = TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 6 DAY), '09:00:00');

SELECT v.*, c.cat_nome, c.cat_valordiaria
FROM tb_veiculo v
JOIN tb_categoria c ON c.cat_cod = v.cat_cod
WHERE c.cat_ativo = TRUE
  AND v.vei_situacao NOT IN ('MANUTENCAO', 'INATIVO')
  AND NOT EXISTS (
      SELECT 1
      FROM tb_locacao l
      WHERE l.vei_cod = v.vei_cod
        AND l.loc_situacao IN ('RESERVADA', 'ATIVA')
        AND l.loc_dataretirada < @fim
        AND (CASE
                 WHEN l.loc_situacao = 'ATIVA'
                     THEN GREATEST(l.loc_dataprevista, NOW())  -- atrasada "ocupa" até agora
                 ELSE l.loc_dataprevista
             END) > @inicio
  );


-- Faturamento por categoria em um período (GET /relatorios/faturamento)
SELECT c.cat_nome,
       COUNT(*)                                      AS qtd_locacoes,
       SUM(COALESCE(l.loc_valordiarias, 0))          AS total_diarias,
       SUM(COALESCE(l.loc_valorkmextra, 0))          AS total_km_extra,
       SUM(COALESCE(l.loc_valormulta, 0))            AS total_multas,
       SUM(COALESCE(l.loc_valortaxacancelamento, 0)) AS total_taxas_cancelamento,
       SUM(l.loc_valortotal)                         AS total_geral
FROM tb_locacao l
JOIN tb_veiculo   v ON v.vei_cod = l.vei_cod
JOIN tb_categoria c ON c.cat_cod = v.cat_cod
WHERE l.loc_situacao IN ('FINALIZADA', 'CANCELADA')
  AND COALESCE(l.loc_datadevolucao, l.loc_datacancelamento)
      BETWEEN '2026-09-01 00:00:00' AND '2026-09-30 23:59:59'
GROUP BY c.cat_nome;