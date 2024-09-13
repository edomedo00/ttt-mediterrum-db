CALL obtener_red_usuario(2); -- Distribuidor Juan B
CALL obtener_red_usuario(5); -- Promotor Hector C
CALL obtener_red_usuario(12); -- Vendedor Ana F

CALL insertar_usuario ('Pedro P', 'pedrop@gmail.com', '019238430', 'vendedor', 0, '1', 2, 4); -- Insertar vendedor Pedro P y asignarle distribuidor y promotor
CALL insertar_usuario ('Memo M', 'memom@gmail.com', '019526430', 'distribuidor', 0, '1', NULL, NULL); -- Insertar distribuidor Memo M


-- -------------------------------------------------------------------
-- Para probar que se reinicia el carrito al realizar una compra
-- Se obtiene el carrito de Ana A
SELECT 
    usuarios.id AS usuario_id,
    usuarios.nombre AS usuario_nombre,
    carrito.id AS carrito_id,
    productos.id AS producto_id,
    productos.nombre_producto AS producto_nombre,
    carrito_producto.cantidad
FROM usuarios
JOIN carrito ON usuarios.carrito_actual = carrito.id
JOIN carrito_producto ON carrito.id = carrito_producto.carrito
JOIN productos ON carrito_producto.producto = productos.id
WHERE usuarios.nombre = 'Ana A';

-- Obtener los productos y su cantidad en el carrito del usuario con el nombre 'Ana A'
-- SELECT usuarios.id, usuarios.nombre, carrito.id AS carrito_id, carrito_producto.producto, carrito_producto.cantidad
-- FROM usuarios
-- JOIN carrito ON usuarios.carrito_actual = carrito.id
-- JOIN carrito_producto ON carrito.id = carrito_producto.carrito
-- WHERE usuarios.nombre = 'Ana A';

CALL realizar_compra (7, '2024-09-10', 'Zapopan xd', 100); -- Registrar una venta del carrito actual de Ana A (ID 7)

SELECT * FROM ventas; -- Se inserto la venta

-- Se obtiene el carrito de Ana A
-- No se pueden mostrar los productos del carrito porque aun no se han añadido
SELECT 
    usuarios.id AS usuario_id,
    usuarios.nombre AS usuario_nombre,
    carrito.id AS carrito_id
FROM usuarios
JOIN carrito ON usuarios.carrito_actual = carrito.id
WHERE usuarios.nombre = 'Ana A';


