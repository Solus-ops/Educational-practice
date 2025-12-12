CREATE DATABASE ObuvDB;
GO
USE ObuvDB;
GO
CREATE TABLE Stg_Tovar (
  Àðòèêóë NVARCHAR(50),
  Íàèìåíîâàíèå NVARCHAR(200),
  Åäèíèöà NVARCHAR(50),
  Öåíà NVARCHAR(50),
  Ïîñòàâùèê NVARCHAR(200),
  Ïðîèçâîäèòåëü NVARCHAR(200),
  Êàòåãîðèÿ NVARCHAR(200),
  Ñêèäêà NVARCHAR(50),
  Êîëâî NVARCHAR(50),
  Îïèñàíèå NVARCHAR(MAX),
  Ôîòî NVARCHAR(200)
);

CREATE TABLE Stg_Users (
  Ðîëü NVARCHAR(100),
  ÔÈÎ NVARCHAR(200),
  Ëîãèí NVARCHAR(100),
  Ïàðîëü NVARCHAR(100)
);

CREATE TABLE Stg_Orders (
  Íîìåð NVARCHAR(50),
  Àðòèêóëû NVARCHAR(MAX),
  ÄàòàÇàêàçà NVARCHAR(50),
  ÄàòàÄîñòàâêè NVARCHAR(50),
  Ïóíêò NVARCHAR(200),
  Êëèåíò NVARCHAR(200),
  Êîä NVARCHAR(50),
  Ñòàòóñ NVARCHAR(100)
);

CREATE TABLE Stg_PickupPoints (
  Address NVARCHAR(500)
);
GO
CREATE TABLE Units (Id INT IDENTITY PRIMARY KEY, Name NVARCHAR(100) UNIQUE);
CREATE TABLE Suppliers (Id INT IDENTITY PRIMARY KEY, Name NVARCHAR(200) UNIQUE);
CREATE TABLE Manufacturers (Id INT IDENTITY PRIMARY KEY, Name NVARCHAR(200) UNIQUE);
CREATE TABLE Categories (Id INT IDENTITY PRIMARY KEY, Name NVARCHAR(200) UNIQUE);
CREATE TABLE Promotions (Id INT IDENTITY PRIMARY KEY, DiscountPercent INT);

CREATE TABLE Roles (Id INT IDENTITY PRIMARY KEY, Name NVARCHAR(200));
CREATE TABLE OrderStatus (Id INT IDENTITY PRIMARY KEY, Name NVARCHAR(200));

CREATE TABLE PickupPoints (Id INT IDENTITY PRIMARY KEY, Address NVARCHAR(500) UNIQUE);

CREATE TABLE Clients (Id INT IDENTITY PRIMARY KEY, FullName NVARCHAR(300));

CREATE TABLE Products (
  Id INT IDENTITY PRIMARY KEY,
  Article NVARCHAR(50),
  Name NVARCHAR(200),
  UnitId INT,
  Price DECIMAL(18,2),
  SupplierId INT,
  ManufacturerId INT,
  CategoryId INT,
  PromotionId INT,
  StockQty INT,
  Description NVARCHAR(MAX),
  Photo NVARCHAR(100),
  FOREIGN KEY (UnitId) REFERENCES Units(Id),
  FOREIGN KEY (SupplierId) REFERENCES Suppliers(Id),
  FOREIGN KEY (ManufacturerId) REFERENCES Manufacturers(Id),
  FOREIGN KEY (CategoryId) REFERENCES Categories(Id),
  FOREIGN KEY (PromotionId) REFERENCES Promotions(Id)
);

CREATE TABLE Users (
  Id INT IDENTITY PRIMARY KEY,
  FullName NVARCHAR(200),
  Login NVARCHAR(100),
  Password NVARCHAR(100),
  RoleId INT,
  FOREIGN KEY (RoleId) REFERENCES Roles(Id)
);

CREATE TABLE Orders (
  Id INT IDENTITY PRIMARY KEY,
  OrderNumber NVARCHAR(50),
  OrderDate DATE,
  DeliveryDate DATE,
  PickupPointId INT,
  ClientId INT,
  PickupCode NVARCHAR(50),
  StatusId INT,
  FOREIGN KEY (PickupPointId) REFERENCES PickupPoints(Id),
  FOREIGN KEY (ClientId) REFERENCES Clients(Id),
  FOREIGN KEY (StatusId) REFERENCES OrderStatus(Id)
);

CREATE TABLE OrderItems (
  Id INT IDENTITY PRIMARY KEY,
  OrderId INT,
  ProductId INT NULL,
  ProductArticle NVARCHAR(50),
  Quantity INT,
  FOREIGN KEY (OrderId) REFERENCES Orders(Id),
  FOREIGN KEY (ProductId) REFERENCES Products(Id)
);
GO
INSERT INTO Units(Name) SELECT DISTINCT Åäèíèöà FROM Stg_Tovar;

INSERT INTO Suppliers(Name) SELECT DISTINCT Ïîñòàâùèê FROM Stg_Tovar;

INSERT INTO Manufacturers(Name) SELECT DISTINCT Ïðîèçâîäèòåëü FROM Stg_Tovar;

INSERT INTO Categories(Name) SELECT DISTINCT Êàòåãîðèÿ FROM Stg_Tovar;

INSERT INTO Promotions(DiscountPercent)
SELECT DISTINCT TRY_CAST(Ñêèäêà AS INT) FROM Stg_Tovar;

INSERT INTO Roles(Name) SELECT DISTINCT Ðîëü FROM Stg_Users;

INSERT INTO OrderStatus(Name) SELECT DISTINCT Ñòàòóñ FROM Stg_Orders;

INSERT INTO PickupPoints(Address) SELECT DISTINCT Address FROM Stg_PickupPoints;

INSERT INTO Clients(FullName) SELECT DISTINCT Êëèåíò FROM Stg_Orders;
GO
INSERT INTO Products (Article, Name, UnitId, Price, SupplierId, ManufacturerId, CategoryId, PromotionId, StockQty, Description, Photo)
SELECT
  Àðòèêóë,
  Íàèìåíîâàíèå,
  u.Id,
  TRY_CAST(Öåíà AS DECIMAL(18,2)),
  sup.Id,
  man.Id,
  cat.Id,
  prom.Id,
  TRY_CAST(Êîëâî AS INT),
  Îïèñàíèå,
  Ôîòî
FROM Stg_Tovar s
JOIN Units u ON u.Name = s.Åäèíèöà
JOIN Suppliers sup ON sup.Name = s.Ïîñòàâùèê
JOIN Manufacturers man ON man.Name = s.Ïðîèçâîäèòåëü
JOIN Categories cat ON cat.Name = s.Êàòåãîðèÿ
JOIN Promotions prom ON prom.DiscountPercent = TRY_CAST(s.Ñêèäêà AS INT);
GO
INSERT INTO Users (FullName, Login, Password, RoleId)
SELECT s.ÔÈÎ, s.Ëîãèí, s.Ïàðîëü, r.Id
FROM Stg_Users s
JOIN Roles r ON r.Name = s.Ðîëü;
GO
INSERT INTO Orders (OrderNumber, OrderDate, DeliveryDate, PickupPointId, ClientId, PickupCode, StatusId)
SELECT 
  Íîìåð,
  TRY_CONVERT(date, ÄàòàÇàêàçà, 104),
  TRY_CONVERT(date, ÄàòàÄîñòàâêè, 104),
  pp.Id,
  cl.Id,
  Êîä,
  st.Id
FROM Stg_Orders s
JOIN PickupPoints pp ON s.Ïóíêò = pp.Id
JOIN Clients cl ON cl.FullName = s.Êëèåíò
JOIN OrderStatus st ON st.Name = s.Ñòàòóñ;
GO
IF OBJECT_ID('tempdb..#RawOrderItems') IS NOT NULL DROP TABLE #RawOrderItems;

CREATE TABLE #RawOrderItems (
    OrderId INT,
    Token NVARCHAR(100),
    Seq INT
);
GO
DECLARE 
    @OrderId INT,
    @Str NVARCHAR(MAX);

DECLARE order_cursor CURSOR FOR
SELECT o.Id, s.Àðòèêóëû
FROM Orders o
JOIN Stg_Orders s ON o.OrderNumber = s.Íîìåð;

OPEN order_cursor;
FETCH NEXT FROM order_cursor INTO @OrderId, @Str;

WHILE @@FETCH_STATUS = 0
BEGIN
    ;WITH CTE AS (
        SELECT 
            @OrderId AS OrderId,
            value AS Token,
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Seq
        FROM STRING_SPLIT(REPLACE(REPLACE(@Str, ' ', ''), ';', ','), ',')
        WHERE value <> ''
    )
    INSERT INTO #RawOrderItems (OrderId, Token, Seq)
    SELECT OrderId, Token, Seq FROM CTE;

    FETCH NEXT FROM order_cursor INTO @OrderId, @Str;
END

CLOSE order_cursor;
DEALLOCATE order_cursor;
GO
INSERT INTO OrderItems (OrderId, ProductId, ProductArticle, Quantity)
SELECT 
    r1.OrderId,
    p.Id AS ProductId,
    r1.Token AS ProductArticle,
    TRY_CAST(r2.Token AS INT) AS Quantity
FROM #RawOrderItems r1
JOIN #RawOrderItems r2 
    ON r1.OrderId = r2.OrderId
   AND r2.Seq = r1.Seq + 1
LEFT JOIN Products p 
    ON p.Article = r1.Token
WHERE r1.Seq % 2 = 1;
GO
