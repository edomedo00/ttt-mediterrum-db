-- Insert distribuidores
INSERT INTO usuarios (nombre, email, telefono, rol, puntos_total, nivel, distribuidor, promotor)
VALUES 
('Juan A', 'juana@gmail.com', '128938747', 'distribuidor', 100, '1', NULL, NULL),
('Juan B', 'juanb@gmail.com', '192460198', 'distribuidor', 150, '2', NULL, NULL);

-- Insert promotores
INSERT INTO usuarios (nombre, email, telefono, rol, puntos_total, nivel, distribuidor, promotor)
VALUES 
('Hector A', 'hectora@gmail.com', '123456789', 'promotor', 100, '1', 1, NULL),
('Hector B', 'hectorb@gmail.com', '812937647', 'promotor', 150, '2', 1, NULL),
('Hector C', 'hectorc@gmail.com', '129837846', 'promotor', 200, '3', 2, NULL),
('Hector D', 'hectord@gmail.com', '190283749', 'promotor', 300, '4', 2, NULL);

-- Insert vendedores
INSERT INTO usuarios (nombre, email, telefono, rol, puntos_total, nivel, distribuidor, promotor)
VALUES 	
('Ana A', 'anaa@gmail.com', '92384762', 'vendedor', 140, '1', 1, 3),
('Ana B', 'anab@gmail.com', '109273897', 'vendedor', 150, '2', 1, 3),
('Ana C', 'anac@gmail.com', '109254823', 'vendedor', 200, '3', 1, 4),
('Ana D', 'anad@gmail.com', '111111111', 'vendedor', 300, '2', 1, 4),
('Ana E', 'anae@gmail.com', '834791283', 'vendedor', 120, '1', 2, 5),
('Ana F', 'anaf@gmail.com', '348923479', 'vendedor', 130, '3', 2, 5),
('Ana G', 'anag@gmail.com', '129387483', 'vendedor', 90, '1', 2, 6),
('Ana H', 'anah@gmail.com', '765203984', 'vendedor', 50, '2', 2, 6);


-- Esquema de usuarios
-- Juan A (Distribuidor)
-- ├── Hector A (Promotor)
-- │   ├── Ana A (Vendedor)
-- │   └── Ana B (Vendedor)
-- └── Hector B (Promotor)
--     ├── Ana C (Vendedor)
--     └── Ana D (Vendedor)

-- Juan B (Distribuidor)
-- ├── Hector C (Promotor)
-- │   ├── Ana E (Vendedor)
-- │   └── Ana F (Vendedor)
-- └── Hector D (Promotor)
--     ├── Ana G (Vendedor)
--     └── Ana H (Vendedor)

-- Insert productos
INSERT INTO productos (nombre_producto, costo_total, costo_no_iva, img, descripcion, descuento, cantidad_inventario)
VALUES 
('Echinacea', 50, 40, 'echinacea.jpg', 'Suplemento de Echinacea para fortalecer el sistema inmunológico', 0, 100),
('Manzanilla', 60, 50, 'manzanilla.jpg', 'Infusión de manzanilla para aliviar el estrés y problemas digestivos', 10, 150),
('Ginseng', 30, 20, 'ginseng.jpg', 'Raíz de ginseng para aumentar la energía y la resistencia', 20, 80),
('Valeriana', 70, 60, 'valeriana.jpg', 'Extracto de valeriana para ayudar con el insomnio y la ansiedad', 30, 60),
('Peppermint', 100, 90, 'peppermint.jpg', 'Aceite de menta para aliviar dolores de cabeza y problemas digestivos', 50, 200);

-- Insert carritos para cada usuario
INSERT INTO carrito (usuario) 
VALUES 
(1), -- Juan A
(3), -- Hector A
(6), -- Hector D
(7), -- Ana A
(10), -- Ana D
(11), -- Ana E
(13); -- Ana G

-- Define como carrito_actual el carrito de cada usuario
UPDATE usuarios SET carrito_actual = 1 WHERE id = 1; -- Juan A
UPDATE usuarios SET carrito_actual = 2 WHERE id = 3; -- Hector A
UPDATE usuarios SET carrito_actual = 3 WHERE id = 6; -- Hector D
UPDATE usuarios SET carrito_actual = 4 WHERE id = 7; -- Ana A
UPDATE usuarios SET carrito_actual = 5 WHERE id = 10; -- Ana D
UPDATE usuarios SET carrito_actual = 6 WHERE id = 11; -- Ana E
UPDATE usuarios SET carrito_actual = 7 WHERE id = 13; -- Ana G


-- Insert productos en los carritos de cada usuario
INSERT INTO carrito_producto (carrito, producto, cantidad) 
VALUES
(1, 1, 2), -- Juan A -> 2 Echinacea
(1, 3, 1), -- Juan A -> 1 Ginseng
(2, 2, 3), -- Hector A -> 3 Manzanilla
(2, 4, 2), -- Hector A -> 2 Valeriana
(3, 5, 5), -- Hector D -> 5 Peppermint
(4, 1, 1), -- Ana A -> 1 Echinacea
(4, 4, 3), -- Ana A -> 3 Valeriana
(5, 3, 4), -- Ana D -> 4 Ginseng
(6, 2, 2), -- Ana E -> 2 Manzanilla
(7, 5, 1); -- Ana G -> 1 Peppermint

INSERT INTO carrito_producto (carrito, producto, cantidad) 
VALUES
(1, 1, 2); -- Juan A -> 2 Echinacea
 




