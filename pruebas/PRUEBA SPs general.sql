-- USUARIOS

-- Juan A (Distribuidor)
-- ├── Hector A (Promotor)
-- │   ├── Ana A (Vendedor)
-- │   └── Ana B (Vendedor)
-- └── Hector B (Promotor)
--     ├── Ana C (Vendedor)
--     └── Ana D (Vendedor)

-- Insertar usuarios de acuerdo al esquema anterior
-- Argumentos (nombre, email, telefono, rol, puntos_total, nivel, distribuidor_id, promotor_id) [distribuidor_id y promotor_id pueden ser nulos]
CALL insertar_usuario('Juan A', 'juana@gmail.com', '128938747', 'distribuidor', 100, 'oro', NULL, NULL); -- dist
CALL insertar_usuario('Hector A', 'hectora@gmail.com', '123456789', 'promotor', 100, 'plata', 1, NULL); -- prom
CALL insertar_usuario('Hector B', 'hectorb@gmail.com', '812937647', 'promotor', 150, 'bronce', 1, NULL);
CALL insertar_usuario('Ana A', 'anaa@gmail.com', '92384762', 'vendedor', 140, 'oro', 1, 2); -- vend
CALL insertar_usuario('Ana B', 'anab@gmail.com', '109273897', 'vendedor', 150, 'plata', 1, 2);
CALL insertar_usuario('Ana C', 'anac@gmail.com', '109254823', 'vendedor', 200, 'plata', 1, 3);
CALL insertar_usuario('Ana D', 'anad@gmail.com', '111111111', 'vendedor', 300, 'bronce', 1, 3);

CALL insertar_usuario('Juan', 'juana@gmail.com', '1289387473', 'distribuidor', 100, 'plata', NULL, NULL); -- dist se duplica email NO se inserta
CALL insertar_usuario('Juan', 'juansadasda@gmail.com', '128938747', 'distribuidor', 100, 'plata', NULL, NULL); -- dist se duplica telefono NO se inserta

-- Obtener todos los usuarios
CALL obtener_todos_usuarios();

-- Busqueda de usuario por id, nombre, email o telefono
-- no se si sea lo mejor dejar que id y numero se revisen en la misma consulta
-- aunque se necesitarian millones de usuarios para que comiencen a chocar los valores id y tel
CALL obtener_usuario_parametro('2');
CALL obtener_usuario_parametro('Juan B');
CALL obtener_usuario_parametro('juanb@gmail.com');
CALL obtener_usuario_parametro('128938845');
CALL obtener_usuario_parametro('112'); -- no arroja nada

-- Obtener red de un usuario (usuarios hacia arriba arriba y abajo)
CALL obtener_usuario_red (1);

-- Obtener distribuidor y promotor de usuario
CALL obtener_usuario_relaciones(7);
CALL obtener_usuario_relaciones(2);
CALL obtener_usuario_relaciones(1);

-- Modificar datos de un usuario
CALL modificar_usuario_datos (5, 'Ana Alvarez', 'anaaAA@gmail.com', '92384734');
CALL obtener_usuario_parametro(5);

-- Modificar relaciones (promotor, distribuidor) de un usuario (usuario_id, promotor, distribuidor)
CALL modificar_usuario_relaciones(4, 1, 3);
CALL modificar_usuario_relaciones(5, 2, 4);
CALL modificar_usuario_relaciones(6, NULL, NULL);
CALL modificar_usuario_relaciones(6, 1, 999);

-- Modificar rol de un usuario
CALL modificar_usuario_rol (6, 'distribuidor');
CALL modificar_usuario_rol (7, 'distribuidor');
CALL obtener_todos_usuarios(); -- usuario id 6 debe ser distribuidor y tener prom y dist NULL

-- Eliminar un usuario
CALL insertar_usuario('Eliminable', 'elim@gmail.com', '1234321', 'vendedor', 300, 'bronce', 1, 3);
CALL eliminar_usuario((SELECT id FROM usuarios WHERE nombre='Eliminable'));
CALL obtener_todos_usuarios(); 
CALL eliminar_usuario(11111); -- no existe


-- CLIENTES

-- Insertar clientes (no se puede repetir ni email ni telefono)
CALL insertar_cliente('Laura Gomez', 'laura.gomez@gmail.com', '999999998', 'CDMX', 'Plantas curativas');
CALL insertar_cliente('Carlos Perez', 'carlos.perez@gmail.com', '999999876', 'Guadalajara', 'Plantas de alivio para dolor');

-- Obtener todos los clientes
CALL obtener_todos_clientes();

-- Obtener un cliente por ID, nombre, email o telefono
-- misma duda que con el read de usuarios parametro
CALL obtener_cliente_parametro('laura.gomez@gmail.com');

-- Modificar un cliente
CALL modificar_cliente(2,'Laura perez', 'carlos.perez@gmail.com', '999999238', 'CDMX', 'Plantas curativas');
CALL obtener_todos_clientes();

-- Eliminar un cliente 
CALL eliminar_cliente(2);
CALL obtener_todos_clientes();


-- PRODUCTOS

-- Insertar productos (SKU, nombre, precio, precion sin iva, img, desc, descuento, puntos)
CALL insertar_producto('ALV001', 'Extracto de Aloe Vera', 150, 120, 'aloe_vera.jpg', 'Extracto natural de Aloe Vera para hidratación profunda.', 0, 50, 5);
CALL insertar_producto('ACO002', 'Aceite de Coco Orgánico', 180, 150, 'aceite_coco.jpg', 'Aceite virgen de coco orgánico, ideal para cocinar y cuidado de la piel.', 15, 70, 5);
CALL insertar_producto('MAC003', 'Polvo de Maca', 200, 170, 'maca_polvo.jpg', 'Polvo de maca pura para aumentar energía y vitalidad.', 5, 60, 5);
CALL insertar_producto('TGV004', 'Té Verde Matcha', 220, 180, 'matcha_tea.jpg', 'Té verde matcha premium, antioxidante y revitalizante.', 0, 40, 5);
CALL insertar_producto('HCH005', 'Harina de Chía', 160, 130, 'chia_flour.jpg', 'Harina de chía rica en fibra y omega-3.', 20, 55, 5);

-- Obtener todos los productos
CALL obtener_productos_todos();

-- Obtener producto por parametro (SKU, nombre)
CALL obtener_producto_parametro('ALV001');
CALL obtener_producto_parametro('Aceite de Coco Orgánico');

-- Obtener el inventario de un producto
CALL obtener_producto_inventario ('TGV004');

-- Modificar los datos de un producto
CALL modificar_producto('ALV001', 'Extracto de Aloe Vera editado', 150, 125, 'aloe_edited_vera.jpg', 'Extracto super natural de Aloe Vera para hidratación profunda.', 0, 50);
CALL obtener_producto_parametro('ALV001');

-- Modificar el inventario de UN producto
CALL modificar_producto_inventario('TGV004', 20);
CALL obtener_producto_inventario ('TGV004');

-- Eliminar un producto
CALL eliminar_producto('HCH005');
CALL obtener_productos_todos();


-- CARRITO

-- Obtener productos y cantidad en carrito de un usuario
CALL obtener_productos_en_carrito_usuario(3);

-- Agregar producto al carrito de un usuario (usuario, sku, cantidad)
CALL insertar_producto_carrito(3, 'MAC003', 2);
CALL insertar_producto_carrito(3, 'HCH005', 1);
CALL obtener_productos_en_carrito_usuario(3);

-- Modificar cantidad de un producto en carrito de usuario (usuario, sku, nueva cantidad)
CALL modificar_cantidad_producto_carrito (3, 'MAC003', 5);
CALL modificar_producto_inventario('MAC003', 10);
CALL obtener_producto_inventario('MAC003');
CALL modificar_cantidad_producto_carrito (3, 'MAC003', 5); -- CORREGIR
CALL obtener_productos_en_carrito_usuario(3);

-- Eliminar producto de carrito de usuario
CALL eliminar_producto_carrito(3, 'HCH005');
CALL obtener_productos_en_carrito_usuario(3);


-- VENTAS

-- Realizar una venta
CALL realizar_venta(3, '2024-09-30', 'Zapopan #314');

-- Obtener todas las ventas
CALL obtener_ventas_todas();

-- Vaciar carrito al realizar venta (comprobar)
CALL obtener_productos_en_carrito_usuario(3);

-- Insertar varias ventas para probar READS de ventas
-- Inserta venta con fecha_venta del mes que viene
INSERT INTO ventas (usuario, carrito, costo_total, fecha_venta, fecha_entrega, lugar_entrega, puntos_venta)
VALUES (1, '{"items": [{"product_id": 101, "quantity": 2}]}', 150.75, 
        DATE_ADD(CURDATE(), INTERVAL 1 MONTH), 
        DATE_ADD(DATE_ADD(CURDATE(), INTERVAL 1 MONTH), INTERVAL 7 DAY), 
        '123 Main St', 50);

-- Inserta venta con fecha_venta del año pasado
INSERT INTO ventas (usuario, carrito, costo_total, fecha_venta, fecha_entrega, lugar_entrega, puntos_venta)
VALUES (2, '{"items": [{"product_id": 303, "quantity": 3}]}', 250.50, 
        DATE_SUB(CURDATE(), INTERVAL 1 YEAR), 
        DATE_SUB(DATE_SUB(CURDATE(), INTERVAL 1 YEAR), INTERVAL 3 DAY), 
        '456 Elm St', 75);

-- Inserta venta para usuario 3 con día de hoy
INSERT INTO ventas (usuario, carrito, costo_total, fecha_venta, fecha_entrega, lugar_entrega, puntos_venta)
VALUES (3, '{"items": [{"product_id": 505, "quantity": 1}]}', 75.00, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 5 DAY), '789 Oak St', 20);

-- Obtener ventas usuario
CALL obtener_ventas_usuario('3');

-- Obtener ventas venta_id
-- (se obtiene el id de la primera venta realizada para hacer la prueba)
CALL obtener_venta_id((SELECT id FROM ventas WHERE usuario = 3 AND fecha_venta = CURRENT_DATE() AND lugar_entrega = 'Zapopan #314'));
 
-- Obtener ventas por fecha
-- dia
CALL obtener_ventas_fecha(CURRENT_DATE()); 

-- mes (año int, mes int)
CALL obtener_ventas_mes(2024, 10);

-- año
CALL obtener_ventas_anio('2023');



