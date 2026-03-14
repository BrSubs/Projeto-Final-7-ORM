-- ==========================================================
-- SCRIPT ÚNICO: TEMA 9 – LOJA VIRTUAL SIMPLIFICADA
-- ==========================================================



-- ==========================================================
-- LIMPEZA DE AMBIENTE (garantir a execução )
-- ==========================================================

-- Removendo Views e Views Materializadas
DROP VIEW IF EXISTS vw_lista_pedidos_clientes CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_faturamento_por_produto CASCADE;

-- Removendo Tabelas
DROP TABLE IF EXISTS Pagamentos CASCADE;
DROP TABLE IF EXISTS Item_Pedidos CASCADE;
DROP TABLE IF EXISTS Pedidos CASCADE;
DROP TABLE IF EXISTS Cupons CASCADE;
DROP TABLE IF EXISTS Produtos CASCADE;
DROP TABLE IF EXISTS Enderecos CASCADE;
DROP TABLE IF EXISTS Config_Frete CASCADE;
DROP TABLE IF EXISTS Cliente CASCADE;
DROP TABLE IF EXISTS Categorias CASCADE;

-- Removendo Funções das Triggers e Procedures para limpeza completa
DROP FUNCTION IF EXISTS fn_ajusta_email_cliente() CASCADE;
DROP FUNCTION IF EXISTS fn_atualiza_estoque() CASCADE;
DROP PROCEDURE IF EXISTS pr_cancelar_pedido(INT);



-- ===============================
-- Criação do schema/tabelas (DDL)
-- Definição de PK, FK e constraints de integridade;
-- ===============================


CREATE TABLE Categorias (
    id SERIAL PRIMARY KEY,
    nome_categoria VARCHAR(100) NOT NULL
);

CREATE TABLE Cliente (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    email VARCHAR(254) NOT NULL UNIQUE, -- Garante que não existam emails duplicados
    cpf CHAR(11) NOT NULL UNIQUE         -- Garante que não existam CPFs duplicados
);

CREATE TABLE Config_Frete (
    id SERIAL PRIMARY KEY,
    cidade VARCHAR(100),
    uf CHAR(2) NOT NULL,
    cep_inicio CHAR(8) NOT NULL,
    cep_fim CHAR(8) NOT NULL,
    -- CHECK para impedir valores negativos no valor_base e prazo_dias
    valor_base DECIMAL(10,2) NOT NULL CONSTRAINT ck_valor_frete CHECK (valor_base >= 0),
    prazo_dias INTEGER NOT NULL CONSTRAINT ck_prazo_frete CHECK (prazo_dias > 0)       
);

CREATE TABLE Enderecos (
    id SERIAL PRIMARY KEY,
    logradouro VARCHAR(150) NOT NULL,
    cep CHAR(8) NOT NULL,
    cidade VARCHAR(100) NOT NULL,
    uf CHAR(2) NOT NULL,
    id_cliente INTEGER NOT NULL,
    -- Remove endereços automaticamente se o cliente for apagado
    CONSTRAINT fk_cliente_endereco FOREIGN KEY (id_cliente) REFERENCES Cliente(id) ON DELETE CASCADE
);

CREATE TABLE Produtos (
    sku VARCHAR(50) PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    -- Impede preço menor ou igual a zero e estoque negativo
    preco DECIMAL(10,2) NOT NULL CONSTRAINT ck_preco_positivo CHECK (preco > 0),
    estoque INTEGER NOT NULL CONSTRAINT ck_estoque_minimo CHECK (estoque >= 0),
    -- DEFAULT: Todo produto novo entra como ativo (TRUE) por padrão
    status BOOLEAN DEFAULT TRUE, -- Ativo por padrão
    id_categoria INTEGER,
    CONSTRAINT fk_categoria_produto FOREIGN KEY (id_categoria) REFERENCES Categorias(id) ON DELETE SET NULL
);

CREATE TABLE Cupons (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) NOT NULL UNIQUE,
    -- CHECK para validar tipos de desconto
    tipo_desconto VARCHAR(20) NOT NULL CHECK (tipo_desconto IN ('VALOR', 'PERCENTUAL')),
    -- CHECK para vanor nao negativo
    valor DECIMAL(10,2) NOT NULL CHECK (valor > 0),
    data_validade DATE NOT NULL,
    -- CHECK para validar uso_max nao seja negativo
    uso_max INTEGER NOT NULL CHECK (uso_max > 0),
    -- DEFAULT: Inicia a contagem de usos do cupom em zero
    uso_atual INTEGER DEFAULT 0,
    id_categoria_elegivel INTEGER,
    CONSTRAINT fk_categoria_cupom FOREIGN KEY (id_categoria_elegivel) REFERENCES Categorias(id) ON DELETE SET NULL
);

CREATE TABLE Pedidos (
    id SERIAL PRIMARY KEY,
    -- DEFAULT: Registra automaticamente o momento da venda
    data_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valor_frete DECIMAL(10,2) DEFAULT 0 CHECK (valor_frete >= 0),
    valor_desconto DECIMAL(10,2) DEFAULT 0 CHECK (valor_desconto >= 0),
    valor_total DECIMAL(10,2) NOT NULL CHECK (valor_total >= 0),
    -- CHECK para validar fluxo de status
    status VARCHAR(20) NOT NULL DEFAULT 'CRIADO' 
        CONSTRAINT ck_status_pedido CHECK (status IN ('CRIADO', 'PAGO', 'ENVIADO', 'ENTREGUE', 'CANCELADO')),
    codigo_rastreio VARCHAR(50),
    id_cliente INTEGER NOT NULL,
    id_endereco INTEGER NOT NULL,
    id_cupom INTEGER,
    CONSTRAINT fk_cliente_pedido FOREIGN KEY (id_cliente) REFERENCES Cliente(id) ON DELETE RESTRICT,
    CONSTRAINT fk_endereco_pedido FOREIGN KEY (id_endereco) REFERENCES Enderecos(id) ON DELETE RESTRICT,
    CONSTRAINT fk_cupom_pedido FOREIGN KEY (id_cupom) REFERENCES Cupons(id) ON DELETE SET NULL
);

CREATE TABLE Item_Pedidos (
    id SERIAL PRIMARY KEY,
    -- CHECK para garantir quantidade mínima de 1
    quantidade INTEGER NOT NULL CONSTRAINT ck_quantidade_item CHECK (quantidade >= 1),
    preco_unitario_aplicado DECIMAL(10,2) NOT NULL,
    sku_produto VARCHAR(50) NOT NULL,
    id_pedido INTEGER NOT NULL,
    CONSTRAINT fk_produto_item FOREIGN KEY (sku_produto) REFERENCES Produtos(sku) ON DELETE RESTRICT,
    -- Remove os itens automaticamente se o pedido for apagado
    CONSTRAINT fk_pedido_item FOREIGN KEY (id_pedido) REFERENCES Pedidos(id) ON DELETE CASCADE
);

CREATE TABLE Pagamentos (
    id SERIAL PRIMARY KEY,
    data_pagamento TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- CHECK para validar formas de pagamento permitidas
    forma_pagamento VARCHAR(20) NOT NULL 
        CONSTRAINT ck_forma_pagamento CHECK (forma_pagamento IN ('PIX', 'CREDITO', 'DEBITO', 'BOLETO')),
    valor_pago DECIMAL(10,2) NOT NULL CHECK (valor_pago > 0),
    id_pedido INTEGER NOT NULL,
    CONSTRAINT fk_pedido_pagamento FOREIGN KEY (id_pedido) REFERENCES Pedidos(id) ON DELETE CASCADE
);


-- ===============================
-- Criação de views
-- ===============================


-- Finalidade: Consulta que une as tabelas Pedidos e Clientes para listar os pedidos dos clientes.
CREATE OR REPLACE VIEW vw_lista_pedidos_clientes AS
SELECT 
    p.id AS cod_pedido,
    c.nome AS nome_cliente,
    p.valor_total,
    p.status
FROM Pedidos p
JOIN Cliente c ON p.id_cliente = c.id;


-- ===============================
-- View Materializada
-- ===============================


-- Finalidade: somar a quantidade de produtos vedidos por sku e multiplicar a quantidade pelo preço para encontrar o faturamento.
CREATE MATERIALIZED VIEW mv_faturamento_por_produto AS
SELECT 
    sku_produto, 
    SUM(quantidade) AS total_vendido,
    SUM(quantidade * preco_unitario_aplicado) AS receita_total
FROM Item_Pedidos
GROUP BY sku_produto;


-- ===============================
-- Triggers
-- ===============================


-- TRIGGER BEFORE: Garante que o e-mail do cliente estará em letras minúsculas antes de salvar.
CREATE OR REPLACE FUNCTION fn_ajusta_email_cliente() RETURNS TRIGGER AS $$
BEGIN
    NEW.email = LOWER(NEW.email);
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_limpa_email
BEFORE INSERT ON Cliente
FOR EACH ROW EXECUTE FUNCTION fn_ajusta_email_cliente();

-- TRIGGER AFTER: Diminui o estoque do produto correto após um novo pedido.
CREATE OR REPLACE FUNCTION fn_atualiza_estoque() RETURNS TRIGGER AS $$
BEGIN
    UPDATE Produtos 
    SET estoque = estoque - NEW.quantidade
    WHERE sku = NEW.sku_produto;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_baixa_estoque
AFTER INSERT ON Item_Pedidos
FOR EACH ROW EXECUTE FUNCTION fn_atualiza_estoque();


-- ===============================
-- 4) STORED PROCEDURE
-- ===============================


-- Finalidade: Rotina para cancelar um pedido e mudar seu status.
CREATE OR REPLACE PROCEDURE pr_cancelar_pedido(p_id_pedido INT) AS $$
BEGIN
    UPDATE Pedidos 
    SET status = 'CANCELADO' 
    WHERE id = p_id_pedido;
END; $$ LANGUAGE plpgsql;


-- ===============================
-- Inserções e consultas de teste (DML);
-- ===============================

-- ===============================
-- Inserções
-- ===============================


INSERT INTO Categorias (nome_categoria) VALUES ('Eletrônicos'), ('Vestuário'), ('Livros'), ('Beleza');

INSERT INTO Cliente (nome, email, cpf) VALUES 
('João Silva', 'joao@email.com', '11122233344'),
('Maria Oliveira', 'maria@email.com', '55566677788'),
('Carlos Souza', 'carlos@email.com', '99900011122');

INSERT INTO Enderecos (logradouro, cep, cidade, uf, id_cliente) VALUES 
('Rua das Flores, 123', '60000000', 'Fortaleza', 'CE', 1),
('Av. Central, 456', '20000000', 'Rio de Janeiro', 'RJ', 2),
('Rua do Porto, 789', '01000000', 'São Paulo', 'SP', 3);

INSERT INTO Config_Frete (cidade, uf, cep_inicio, cep_fim, valor_base, prazo_dias) VALUES 
('Fortaleza', 'CE', '60000000', '60999999', 15.00, 3),
('Rio de Janeiro', 'RJ', '20000000', '23999999', 25.00, 5),
('São Paulo', 'SP', '01000000', '09999999', 20.00, 4);

INSERT INTO Produtos (sku, nome, preco, estoque, id_categoria) VALUES 
('SMART-01', 'Smartphone X', 1500.00, 10, 1),
('TSHIRT-02', 'Camiseta Polo', 89.90, 50, 2),
('BOOK-03', 'Aprenda SQL', 59.90, 20, 3);

INSERT INTO Cupons (codigo, tipo_desconto, valor, data_validade, uso_max, id_categoria_elegivel) VALUES 
('BEMVINDO10', 'PERCENTUAL', 10.00, '2026-12-31', 100, NULL),
('TECH20', 'VALOR', 20.00, '2026-06-30', 50, 1),
('CASA15', 'PERCENTUAL', 15.00, '2026-03-05', 25, 2);

INSERT INTO Pedidos (valor_frete, valor_desconto, valor_total, status, id_cliente, id_endereco, id_cupom) VALUES 
(15.00, 0.00, 1515.00, 'PAGO', 1, 1, NULL),
(25.00, 10.00, 104.90, 'PAGO', 2, 2, 1),
(20.00, 5.00, 74.90, 'PAGO', 3, 3, 2);

INSERT INTO Item_Pedidos (quantidade, preco_unitario_aplicado, sku_produto, id_pedido) VALUES 
(1, 1500.00, 'SMART-01', 1),
(1, 89.90, 'TSHIRT-02', 2),
(1, 59.90, 'BOOK-03', 3);

INSERT INTO Pagamentos (forma_pagamento, valor_pago, id_pedido) VALUES 
('PIX', 1515.00, 1),
('CREDITO', 104.90, 2),
('BOLETO', 74.90, 3);

-- atuliza a view materializada apos a insercao de dados
REFRESH MATERIALIZED VIEW mv_faturamento_por_produto;


-- ===============================
-- Consultas (SELECT)
-- ===============================


-- 1. Listar todos os produtos com o nome de sua categoria
SELECT p.sku, p.nome AS produto, c.nome_categoria AS categoria 
FROM Produtos p JOIN Categorias c ON p.id_categoria = c.id;

-- 2. Detalhar itens do pedido com nome do cliente e produto
SELECT ped.id AS nro_pedido, cli.nome AS cliente, prod.nome AS produto, item.quantidade
FROM Pedidos ped
JOIN Cliente cli ON ped.id_cliente = cli.id
JOIN Item_Pedidos item ON ped.id = item.id_pedido
JOIN Produtos prod ON item.sku_produto = prod.sku;

-- 3. Categorias e quantidade de produtos
SELECT c.nome_categoria AS categoria, COUNT(p.sku) AS total_produtos
FROM Categorias c LEFT JOIN Produtos p ON c.id = p.id_categoria
GROUP BY c.nome_categoria;

-- 4. Filtra pagamentos via PIX com nome do cliente
SELECT cli.nome AS cliente, pag.valor_pago, pag.forma_pagamento
FROM Pagamentos pag
JOIN Pedidos ped ON pag.id_pedido = ped.id
JOIN Cliente cli ON ped.id_cliente = cli.id
WHERE pag.forma_pagamento = 'PIX';

-- 5. Filtra pedidos com valor acima de 100
SELECT id AS pedido_id, valor_total, status 
FROM Pedidos WHERE valor_total > 100.00;


-- ==========================================================
-- Uso de EXPLAIN e EXPLAIN ANALYZE em consultas relevantes.
-- ==========================================================


-- CONSULTA 1: Busca por CPF (Filtro WHERE)
EXPLAIN ANALYZE SELECT nome FROM Cliente WHERE cpf = '11122233344'; -- Antes
CREATE INDEX idx_cliente_cpf ON Cliente(cpf); -- Melhoria
EXPLAIN ANALYZE SELECT nome FROM Cliente WHERE cpf = '11122233344';

-- CONSULTA 2: Itens do Pedido (JOIN)
EXPLAIN ANALYZE SELECT p.id, i.sku_produto FROM Pedidos p JOIN Item_Pedidos i ON p.id = i.id_pedido; -- Antes
CREATE INDEX idx_item_pedido_id ON Item_Pedidos(id_pedido); -- Melhoria
EXPLAIN ANALYZE SELECT p.id, i.sku_produto FROM Pedidos p JOIN Item_Pedidos i ON p.id = i.id_pedido;

-- CONSULTA 3: Faturamento (Agregação)
EXPLAIN ANALYZE SELECT sku_produto, SUM(quantidade) FROM Item_Pedidos GROUP BY sku_produto; -- Antes
EXPLAIN ANALYZE SELECT * FROM mv_faturamento_por_produto; -- Depois (View Materializada evita reprocessar cálculos de soma)

-- TESTE FINAL
CALL pr_cancelar_pedido(1);
SELECT id, status FROM Pedidos WHERE id = 1;