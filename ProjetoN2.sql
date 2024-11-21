CREATE DATABASE GerenciadorDeEstoque;

USE GerenciadorDeEstoque;

CREATE TABLE Categorias (
    IDCategoria INT PRIMARY KEY AUTO_INCREMENT,
    NomeCategoria VARCHAR(60) NOT NULL,
    DescricaoCategoria TEXT NOT NULL
);

CREATE TABLE Produtos (
    IDProduto INT PRIMARY KEY AUTO_INCREMENT,
    NomeProduto VARCHAR(60) NOT NULL,
    DescricaoProduto TEXT,
    QuantidadeEstoque INT DEFAULT 0,
    PrecoCompra FLOAT NOT NULL,
    PrecoVenda FLOAT NOT NULL,
    CategoriaProduto INT,
    CONSTRAINT fk_categoria FOREIGN KEY (CategoriaProduto) REFERENCES Categorias(IDCategoria)
);

DELIMITER //
CREATE PROCEDURE CadastroCategoria(
IN NomeCategoria VARCHAR(60), 
IN DescricaoCategoria TEXT
    )
BEGIN 
INSERT INTO Categorias (NomeCategoria, DescricaoCategoria)
VALUES
(NomeCategoria, DescricaoCategoria);
END //
DELIMITER; 

DELIMITER //
CREATE PROCEDURE CadastroProduto(
IN NomeProduto VARCHAR(60), 
IN DescricaoProduto TEXT,
IN QuantidadeEstoque INT,
IN PrecoCompra FLOAT, 
IN PrecoVenda FLOAT, 
IN CategoriaProduto INT
)
BEGIN
    INSERT INTO Produtos 
    (NomeProduto, DescricaoProduto, QuantidadeEstoque, PrecoCompra, PrecoVenda, CategoriaProduto)
    VALUES 
    (NomeProduto, DescricaoProduto, QuantidadeEstoque, PrecoCompra, PrecoVenda, CategoriaProduto);
END //
DELIMITER ;

Call CadastroCategoria(
'Eletronicos', 
'Todos objetos que utilizam energia'
);

CALL CadastroProduto(
    'Notebook',
    'Notebook Dell Inspiron 15',
    10,
    2500.00,
    3000.00,
    1
);

DELIMITER //
CREATE PROCEDURE DeletarProduto(
IN IDProduto INT
)
BEGIN
	DELETE FROM Produtos where idProduto = IDProduto;
END //
DELIMITER ; 

DELIMITER //
CREATE PROCEDURE DeletarCategoria(
IN IDCategoria INT
)
BEGIN
	DELETE FROM Categorias where idCategoria = IDCategoria;
END //
DELIMITER ; 

DELIMITER //
CREATE PROCEDURE EditarProduto(
IN IDProduto INT,                 
IN NovoNomeProduto VARCHAR(60),  
IN NovaDescricaoProduto TEXT,    
IN NovaQuantidadeEstoque INT,   
IN NovoPrecoCompra FLOAT,        
IN NovoPrecoVenda FLOAT,          
IN NovaCategoriaProduto INT       
)
BEGIN
    UPDATE Produtos
    SET 
        NomeProduto = COALESCE(NovoNomeProduto, NomeProduto),
        DescricaoProduto = COALESCE(NovaDescricaoProduto, DescricaoProduto),
        QuantidadeEstoque = COALESCE(NovaQuantidadeEstoque, QuantidadeEstoque),
        PrecoCompra = COALESCE(NovoPrecoCompra, PrecoCompra),
        PrecoVenda = COALESCE(NovoPrecoVenda, PrecoVenda),
        CategoriaProduto = COALESCE(NovaCategoriaProduto, CategoriaProduto)
    WHERE IDProduto = IDProduto; 
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE EditarCategoria(
IN IDCategoria INT, 
IN NovoNomeCategoria VARCHAR(60), 
IN NovaDescricaoCategoria TEXT
)
BEGIN 
    UPDATE Categorias
    SET 
        NomeCategoria = COALESCE(NovoNomeCategoria, NomeCategoria),
        DescricaoCategoria = COALESCE(NovaDescricaoCategoria, DescricaoCategoria)
    WHERE IDCategoria = IDCategoria;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE ConsultarProdutos(
IN NomeProduto VARCHAR(60),     
IN IDCategoria INT,            
IN PrecoMinimo FLOAT,         
IN PrecoMaximo FLOAT           
)
BEGIN
    SELECT 
        p.IDProduto,
        p.NomeProduto,
        p.DescricaoProduto,
        p.QuantidadeEstoque,
        p.PrecoCompra,
        p.PrecoVenda,
        c.NomeCategoria
    FROM Produtos p
    LEFT JOIN Categorias c ON p.CategoriaProduto = c.IDCategoria
    WHERE 
        (NomeProduto IS NULL OR p.NomeProduto LIKE CONCAT('%', NomeProduto, '%')) AND
        (IDCategoria IS NULL OR p.CategoriaProduto = IDCategoria) AND
        (PrecoMinimo IS NULL OR p.PrecoVenda >= PrecoMinimo) AND
        (PrecoMaximo IS NULL OR p.PrecoVenda <= PrecoMaximo);
END //
DELIMITER ;

CALL ConsultarProdutos('Notebook', NULL, NULL, NULL);

DELIMITER //
CREATE PROCEDURE ConsultarCategorias(
IN IDCategoria INT,           
IN NomeCategoria VARCHAR(60)   
)
BEGIN
    SELECT 
        c.IDCategoria,
        c.NomeCategoria,
        c.DescricaoCategoria,
        COUNT(p.IDProduto) AS TotalProdutos
    FROM Categorias c
    LEFT JOIN Produtos p ON p.CategoriaProduto = c.IDCategoria
    WHERE 
        (IDCategoria IS NULL OR c.IDCategoria = IDCategoria) AND
        (NomeCategoria IS NULL OR c.NomeCategoria LIKE CONCAT('%', NomeCategoria, '%'))
    GROUP BY 
        c.IDCategoria;
END //
DELIMITER ;

CREATE TABLE MovimentacoesEstoque (
    IDMovimentacao INT PRIMARY KEY AUTO_INCREMENT,
    IDProduto INT NOT NULL,
    TipoMovimentacao ENUM('Entrada', 'Saída') NOT NULL,
    Quantidade INT NOT NULL,
    DataMovimentacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (IDProduto) REFERENCES Produtos(IDProduto)
);

DELIMITER //
CREATE PROCEDURE RegistrarMovimentacaoEstoque(
    IN ProdutoID INT,
    IN TipoMovimentacao ENUM('Entrada', 'Saída'),
    IN Quantidade INT
)
BEGIN
    IF TipoMovimentacao = 'Entrada' THEN
        UPDATE Produtos
        SET QuantidadeEstoque = QuantidadeEstoque + Quantidade
        WHERE IDProduto = ProdutoID;
        ELSEIF TipoMovimentacao = 'Saída' THEN
        UPDATE Produtos
        SET QuantidadeEstoque = QuantidadeEstoque - Quantidade
        WHERE IDProduto = ProdutoID;
        -- Verifica o estoque mínimo e exibe um alerta 
        IF (SELECT QuantidadeEstoque FROM Produtos WHERE IDProduto = ProdutoID) < 5 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Estoque abaixo do nível mínimo!';
        END IF;
		END IF;
    -- Insere o registro na tabela MovimentacoesEstoque
    INSERT INTO MovimentacoesEstoque (IDProduto, TipoMovimentacao, Quantidade)
    VALUES (ProdutoID, TipoMovimentacao, Quantidade);
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE RelatorioProdutosCadastrados()
BEGIN
    SELECT 
        p.IDProduto,
        p.NomeProduto,
        p.DescricaoProduto,
        p.QuantidadeEstoque,
        p.PrecoCompra,
        p.PrecoVenda,
        c.NomeCategoria
    FROM Produtos p
    LEFT JOIN Categorias c ON p.CategoriaProduto = c.IDCategoria;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE RelatorioMovimentacoesEstoque()
BEGIN
    SELECT 
        m.IDMovimentacao,
        p.NomeProduto,
        m.TipoMovimentacao,
        m.Quantidade,
        m.DataMovimentacao
    FROM MovimentacoesEstoque m
    JOIN Produtos p ON m.IDProduto = p.IDProduto
    ORDER BY m.DataMovimentacao DESC;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE RelatorioProdutosBaixoEstoque(IN EstoqueMinimo INT)
BEGIN
    SELECT 
        p.IDProduto,
        p.NomeProduto,
        p.QuantidadeEstoque,
        c.NomeCategoria
    FROM Produtos p
    LEFT JOIN Categorias c ON p.CategoriaProduto = c.IDCategoria
    WHERE p.QuantidadeEstoque < EstoqueMinimo;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE RelatorioVendasLucro()
BEGIN
    SELECT 
        p.NomeProduto,
        SUM(m.Quantidade * p.PrecoVenda) AS TotalVendas,
        SUM(m.Quantidade * (p.PrecoVenda - p.PrecoCompra)) AS Lucro
    FROM MovimentacoesEstoque m
    JOIN Produtos p ON m.IDProduto = p.IDProduto
    WHERE m.TipoMovimentacao = 'Saída'
    GROUP BY p.IDProduto;
END //
DELIMITER ;

CALL RegistrarMovimentacaoEstoque(1, 'Entrada', 50);
CALL RegistrarMovimentacaoEstoque(1, 'Saída', 10);

CALL RelatorioProdutosCadastrados();
CALL RelatorioMovimentacoesEstoque();
CALL RelatorioProdutosBaixoEstoque(5);
CALL RelatorioVendasLucro();


