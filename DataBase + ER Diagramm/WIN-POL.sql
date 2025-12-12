CREATE DATABASE ShoeDB;
GO
USE ShoeDB;
GO

CREATE TABLE StgProduct (
    Article NVARCHAR(50),
    Name NVARCHAR(200),
    Unit NVARCHAR(50),
    Price NVARCHAR(50),
    Supplier NVARCHAR(200),
    Manufacturer NVARCHAR(200),
    Category NVARCHAR(200),
    Discount NVARCHAR(50),
    Quantity NVARCHAR(50),
    Description NVARCHAR(MAX),
    Photo NVARCHAR(200)
);

CREATE TABLE StgUsers (
    Role NVARCHAR(100),
    FullName NVARCHAR(200),
    Login NVARCHAR(100),
    Password NVARCHAR(100)
);

CREATE TABLE StgOrders (
    Number NVARCHAR(50),
    Articles NVARCHAR(MAX),
    OrderDate NVARCHAR(50),
    DeliveryDate NVARCHAR(50),
    Point NVARCHAR(200),
    Client NVARCHAR(200),
    Code NVARCHAR(50),
    Status NVARCHAR(100)
);

CREATE TABLE StgPickupPoints (
    IndexCode NVARCHAR(50),
    City NVARCHAR(200),
    Street NVARCHAR(200),
    Home NVARCHAR(50)
);
GO

CREATE TABLE Suppliers (
    Id INT IDENTITY PRIMARY KEY, 
    Name NVARCHAR(200) UNIQUE
);

CREATE TABLE Manufacturers (
    Id INT IDENTITY PRIMARY KEY, 
    Name NVARCHAR(200) UNIQUE
);

CREATE TABLE Categories (
    Id INT IDENTITY PRIMARY KEY, 
    Name NVARCHAR(200) UNIQUE
);

CREATE TABLE Roles (
    Id INT IDENTITY PRIMARY KEY, 
    Name NVARCHAR(200) UNIQUE
);

CREATE TABLE OrderStatus (
    Id INT IDENTITY PRIMARY KEY, 
    Name NVARCHAR(200) UNIQUE
);

CREATE TABLE PickupPoints (
    Id INT IDENTITY PRIMARY KEY,
    IndexCode NVARCHAR(50) UNIQUE,
    City NVARCHAR(200),
    Street NVARCHAR(200),
    Home NVARCHAR(50)
);

CREATE TABLE Users (
    Id INT IDENTITY PRIMARY KEY,
    FullName NVARCHAR(200),
    Login NVARCHAR(100) UNIQUE,
    Password NVARCHAR(100),
    RoleId INT,
    CONSTRAINT FK_Users_Roles FOREIGN KEY (RoleId) REFERENCES Roles(Id)
);

CREATE TABLE Products (
    Id INT IDENTITY PRIMARY KEY,
    Article NVARCHAR(50) UNIQUE,
    Name NVARCHAR(200),
    Unit NVARCHAR(50),
    Price DECIMAL(18,2),
    SupplierId INT,
    ManufacturerId INT,
    CategoryId INT,
    Discount INT,
    StockQty INT,
    Description NVARCHAR(MAX),
    Photo NVARCHAR(200),
    CONSTRAINT FK_Products_Suppliers FOREIGN KEY (SupplierId) REFERENCES Suppliers(Id),
    CONSTRAINT FK_Products_Manufacturers FOREIGN KEY (ManufacturerId) REFERENCES Manufacturers(Id),
    CONSTRAINT FK_Products_Categories FOREIGN KEY (CategoryId) REFERENCES Categories(Id)
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
    CONSTRAINT FK_Orders_PickupPoints FOREIGN KEY (PickupPointId) REFERENCES PickupPoints(Id),
    CONSTRAINT FK_Orders_Users FOREIGN KEY (ClientId) REFERENCES Users(Id),
    CONSTRAINT FK_Orders_Status FOREIGN KEY (StatusId) REFERENCES OrderStatus(Id)
);

CREATE TABLE OrderItems (
    Id INT IDENTITY PRIMARY KEY,
    OrderId INT NOT NULL,
    ProductId INT,
    Quantity INT,
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (OrderId) REFERENCES Orders(Id),
    CONSTRAINT FK_OrderItems_Products FOREIGN KEY (ProductId) REFERENCES Products(Id)
);
GO

INSERT INTO Roles(Name)
SELECT DISTINCT TRIM(Role) FROM StgUsers WHERE Role IS NOT NULL AND Role != '';

INSERT INTO Users(FullName, Login, Password, RoleId)
SELECT 
    TRIM(s.FullName),
    TRIM(s.Login),
    TRIM(s.Password),
    r.Id
FROM StgUsers s
LEFT JOIN Roles r ON r.Name = TRIM(s.Role);

INSERT INTO Suppliers(Name)
SELECT DISTINCT TRIM(Supplier) FROM StgProduct WHERE Supplier IS NOT NULL AND Supplier != '';

INSERT INTO Manufacturers(Name)
SELECT DISTINCT TRIM(Manufacturer) FROM StgProduct WHERE Manufacturer IS NOT NULL AND Manufacturer != '';

INSERT INTO Categories(Name)
SELECT DISTINCT TRIM(Category) FROM StgProduct WHERE Category IS NOT NULL AND Category != '';

INSERT INTO OrderStatus(Name)
SELECT DISTINCT TRIM(Status) FROM StgOrders WHERE Status IS NOT NULL AND Status != '';

INSERT INTO PickupPoints(IndexCode, City, Street, Home)
SELECT 
    TRIM(IndexCode),
    TRIM(City),
    TRIM(Street),
    TRIM(Home)
FROM StgPickupPoints;

INSERT INTO Products(Article, Name, Unit, Price, SupplierId, ManufacturerId, CategoryId, Discount, StockQty, Description, Photo)
SELECT
    TRIM(s.Article),
    TRIM(s.Name),
    TRIM(s.Unit),
    CAST(TRIM(s.Price) AS DECIMAL(18,2)),
    sp.Id,
    m.Id,
    c.Id,
    CAST(TRIM(s.Discount) AS INT),
    CAST(TRIM(s.Quantity) AS INT),
    TRIM(s.Description),
    TRIM(s.Photo)
FROM StgProduct s
LEFT JOIN Suppliers sp ON sp.Name = TRIM(s.Supplier)
LEFT JOIN Manufacturers m ON m.Name = TRIM(s.Manufacturer)
LEFT JOIN Categories c ON c.Name = TRIM(s.Category);

INSERT INTO Orders(OrderNumber, OrderDate, DeliveryDate, PickupPointId, ClientId, PickupCode, StatusId)
SELECT
    TRIM(s.Number),
    CONVERT(DATE, TRIM(s.OrderDate)),
    CONVERT(DATE, TRIM(s.DeliveryDate)),
    pp.Id,
    u.Id,
    TRIM(s.Code),
    os.Id
FROM StgOrders s
LEFT JOIN PickupPoints pp ON pp.IndexCode = TRIM(s.Point)
LEFT JOIN Users u ON u.FullName = TRIM(s.Client)
LEFT JOIN OrderStatus os ON os.Name = TRIM(s.Status);

DECLARE @OrderId INT, @Raw NVARCHAR(MAX);
DECLARE order_cursor CURSOR FOR
SELECT o.Id, so.Articles
FROM Orders o
JOIN StgOrders so ON TRIM(o.OrderNumber) = TRIM(so.Number);

CREATE TABLE #RawOrderItems (OrderId INT, Token NVARCHAR(200), Seq INT);

OPEN order_cursor;
FETCH NEXT FROM order_cursor INTO @OrderId, @Raw;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @clean NVARCHAR(MAX) = ISNULL(@Raw,'');
    SET @clean = REPLACE(@clean, ';', ',');
    SET @clean = REPLACE(@clean, CHAR(160), ' ');
    SET @clean = REPLACE(@clean, ', ', ',');
    
    DECLARE @xml NVARCHAR(MAX) = N'<r><x>' + REPLACE(@clean, ',', '</x><x>') + '</x></r>';
    
    INSERT INTO #RawOrderItems(OrderId, Token, Seq)
    SELECT @OrderId, TRIM(T.X.value('.','nvarchar(200)')), ROW_NUMBER() OVER (ORDER BY (SELECT 1))
    FROM (SELECT CAST(@xml AS XML) AS xm) AS A
    CROSS APPLY xm.nodes('/r/x') AS T(X)
    WHERE TRIM(T.X.value('.','nvarchar(200)')) != '';
    
    FETCH NEXT FROM order_cursor INTO @OrderId, @Raw;
END
CLOSE order_cursor;
DEALLOCATE order_cursor;

INSERT INTO OrderItems(OrderId, ProductId, Quantity)
SELECT
    r1.OrderId,
    p.Id,
    COALESCE(TRY_CAST(r2.Token AS INT), 1)
FROM #RawOrderItems r1
LEFT JOIN #RawOrderItems r2 ON r1.OrderId = r2.OrderId AND r2.Seq = r1.Seq + 1
LEFT JOIN Products p ON p.Article = r1.Token
WHERE r1.Seq % 2 = 1;

DROP TABLE #RawOrderItems;
GO
