-- Obtener la red a la que pertenece un vendedor (Ana G), es decir, los vendedores con los que comparte promotor y distribuidor
-- Funciona
SELECT 
    v.id AS VendedorID,
    v.nombre AS VendedorNombre,
    v.email AS VendedorEmail,
    p.nombre AS PromotorNombre,
    d.nombre AS DistribuidorNombre
FROM 
    usuarios v
LEFT JOIN 
    usuarios p ON v.promotor = p.id
LEFT JOIN 
    usuarios d ON p.distribuidor = d.id
WHERE 
    v.rol = 'vendedor' 
    AND v.promotor = (SELECT promotor FROM usuarios WHERE nombre = 'Ana G');
    
    
-- Obtener el los productos y su cantidad en el carrito del usuario con el nombre 'Ana A'
SELECT usuarios.id, usuarios.nombre, carrito.id AS carrito_id, carrito_producto.producto, carrito_producto.cantidad
FROM usuarios 
JOIN carrito ON usuarios.carrito_actual = carrito.id
JOIN carrito_producto ON carrito.id = carrito_producto.carrito
WHERE usuarios.nombre = 'Ana A';

-- Calcula el precio total del carrito de 'Ana A'
SELECT usuarios.id, usuarios.nombre, carrito.id AS carrito_id, SUM(carrito_producto.producto * carrito_producto.cantidad * productos.costo_total) AS precio_total
FROM usuarios
JOIN carrito ON usuarios.carrito_actual = carrito.id
JOIN carrito_producto ON carrito.id = carrito_producto.carrito
JOIN productos ON carrito_producto.producto = productos.id
WHERE usuarios.nombre = 'Ana A'
GROUP BY usuarios.id, carrito.id;

-- Calcula el precio total del carrito de 'Ana A' si los productos tienen descuento
SELECT usuarios.id, usuarios.nombre, carrito.id AS carrito_id, SUM(carrito_producto.producto * carrito_producto.cantidad * (productos.costo_total - (productos.costo_total * productos.descuento * 0.01))) AS precio_total
FROM usuarios
JOIN carrito ON usuarios.carrito_actual = carrito.id
JOIN carrito_producto ON carrito.id = carrito_producto.carrito
JOIN productos ON carrito_producto.producto = productos.id
WHERE usuarios.nombre = 'Ana A'
GROUP BY usuarios.id, carrito.id;





