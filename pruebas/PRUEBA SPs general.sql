-- USUARIOS

-- Juan A (Distribuidor)
-- ├── Hector A (Promotor)
-- │   ├── Ana A (Vendedor)
-- │   └── Ana B (Vendedor)
-- └── Hector B (Promotor)
--     ├── Ana C (Vendedor)
--     └── Ana D (Vendedor)

-- Insertar usuarios de acuerdo al esquema anterior
-- Argumentos (nombre, email, telefono, ciudad, estado, rol, puntos_total, nivel, distribuidor_id, promotor_id, contrasena, creador_id) 
-- [distribuidor_id y promotor_id pueden ser nulos]
CALL insertar_usuario('Juan A', 'juana@gmail.com', '128938747', 'Monterrey', 'distribuidor', 1999, 'N1 Plata', NULL, NULL, 'password123', NULL); -- dist
CALL insertar_usuario('Hector A', 'hectora@gmail.com', '123456789', 'Guadalajara', 'vendedor', 100, 'N1 Plata', 1, NULL, 'securepass', 1); -- prom
CALL insertar_usuario('Hector B', 'hectorb@gmail.com', '812937647', 'Guadalajara', 'vendedor', 1999, 'N2 Oro', 1, NULL, 'strongpass', 1); -- prom
CALL insertar_usuario('Ana A', 'anaa@gmail.com', '92384762', 'Ciudad de México', 'promotor', 999, 'N1 Plata', 1, 2, 'pass2023', 2); -- vend
CALL insertar_usuario('Ana B', 'anab@gmail.com', '109273897', 'Monterrey', 'promotor', 319, NULL, 1, 2, 'pass456', 2); -- vend
CALL insertar_usuario('Ana C', 'anac@gmail.com', '109254823', 'Guadalajara', 'promotor', 200, 'N1 Plata', 1, 3, 'safepass', 3); -- vend
CALL insertar_usuario('Ana D', 'anad@gmail.com', '111111111', 'Ciudad de México', 'promotor', 300, 'N6 Diamante', 1, 3, 'mypassword', 3); -- vend
CALL insertar_usuario('Juan B', 'juanaq@gmail.com', '12228938747', 'Monterrey', 'distribuidor', 100, 'N2 Oro', NULL, NULL, 'password123', NULL); -- dist
CALL insertar_usuario('Admin', 'admin@gmail.com', '82828282', 'Monterrey', 'administrador', NULL, NULL, NULL, NULL, 'admin123', NULL); -- dist

CALL insertar_usuario('Juan A', 'juana@gmail.com', '128938747', 'Monterrey', 'distribuidor', 100, 'N2 Oro', NULL, NULL, 'password123', NULL); -- dist se duplica email NO se inserta
CALL insertar_usuario('Juan A', 'juaasdna@gmail.com', '128938747', 'Monterrey', 'distribuidor', 100, 'N2 Oro', NULL, NULL, 'password123', NULL); -- dist se duplica telefono NO se inserta

-- Obtener todos los usuarios
CALL obtener_usuarios_todos();

-- Busqueda de usuario por id, nombre, email o telefono
-- no se si sea lo mejor dejar que id y numero se revisen en la misma consulta
-- aunque se necesitarian millones de usuarios para que comiencen a chocar los valores id y tel
CALL obtener_usuario(2);
CALL obtener_usuario_parametro('Hector A');
CALL obtener_usuario_parametro('hectora@gmail.com');
CALL obtener_usuario_parametro('128938747');

-- Obtener red de un usuario (usuarios hacia arriba arriba y abajo)
CALL obtener_usuario_red (1);

-- Obtener distribuidor y promotor de usuario
CALL obtener_usuario_relaciones(6);
CALL obtener_usuario_relaciones(2);
CALL obtener_usuario_relaciones(1);

-- Obtener los puntos de un usuario en un periodo de tiempo
CALL obtener_usuario_puntos_trimestre (6, '2024-09-01');
CALL obtener_usuario_puntos_anio (6, '2024-09-01');

-- Obtener superiores de usuario
CALL obtener_usuario_distribuidor(6);
CALL obtener_usuario_vendedor(6);
CALL obtener_usuario_vendedor(1); -- No tiene vendedor

-- Modificar datos de un usuario
CALL modificar_usuario_datos (3, 'Ana Alvarez', 'anaaAA@gmail.com', '92384734', 'colima');
CALL obtener_usuario(5);

-- Modificar relaciones (distribuidor, vendedor) de un usuario
CALL modificar_usuario_vendedor(4, 3);
CALL modificar_usuario_distribuidor(4, 1);

CALL obtener_usuarios_todos();

-- Modificar rol de un usuario
CALL modificar_usuario_rol (5, 'vendedor');
CALL modificar_usuario_rol (7, 'distribuidor');
CALL obtener_usuarios_todos(); -- usuario id 6 debe ser distribuidor y tener prom y dist NULL

-- Modificar contrasena de usuario
SELECT contrasena FROM usuarios WHERE id = 1;
CALL modificar_usuario_contrasena (1, 'pastadequesoo');
SELECT contrasena FROM usuarios WHERE id = 1;

-- Eliminar un usuario
CALL insertar_usuario('Eliminable', 'elim@gmail.com', '12343221', 'Monterrey', 'promotor', 9998, 'N1 Plata', 1, 3, 'safepass', 3);
CALL eliminar_usuario((SELECT id FROM usuarios WHERE nombre='Eliminable'));
CALL obtener_usuarios_todos(); 
CALL eliminar_usuario(11111); -- no existe
CALL eliminar_usuario(14);


-- HISTORIAL 

-- Obtener el historial del usuario 5
CALL obtener_usuario_historial(3);
CALL obtener_usuario_historial(4);
CALL obtener_usuario_historial(1);
CALL obtener_usuario(5);


-- CLIENTES

-- Insertar clientes (no se puede repetir ni email ni telefono)
CALL insertar_cliente(3, 'Laura Gomez', 'laura.gomez@gmail.com', '999999998', 'CDMX', 'Plantas curativas');
CALL insertar_cliente(3, 'Carlos Perez', 'carlos.perez@gmail.com', '999999876', 'Guadalajara', 'Plantas de alivio para dolor');

-- Obtener todos los clientes
CALL obtener_clientes_todos();

-- Obtener un cliente por ID, nombre, email o telefono
CALL obtener_cliente(1);
CALL obtener_cliente_parametro('laura.gomez@gmail.com');
CALL obtener_cliente_parametro('Laura Gomez');
CALL obtener_cliente_parametro('999999998');

-- Obtener clientes 

-- Modificar un cliente
CALL modificar_cliente(1, 'Laura perez', 'carlos.pereza@gmail.com', '9999299238', 'CDMX', 'Plantas curativas');
CALL obtener_clientes_todos();

CALL modificar_cliente_usuario(1,5);
CALL obtener_usuario_historial(1);

-- Eliminar un cliente 
CALL eliminar_cliente(10);
CALL obtener_clientes_todos();

CALL obtener_usuario_historial(6);


-- PRODUCTOS

-- Insertar productos (SKU, nombre, precio, precion sin iva, img, desc, descuento, puntos, inventario)
CALL insertar_producto('ALV001', 'Extracto de Aloe Vera', 150, 120, 'aloe_vera.jpg', 'Extracto natural de Aloe Vera para hidratación profunda.', 0, NULL, 30);
CALL insertar_producto('ACO002', 'Aceite de Coco Orgánico', 180, 150, 'aceite_coco.jpg', 'Aceite virgen de coco orgánico, ideal para cocinar y cuidado de la piel.', 15, NULL, 30);
CALL insertar_producto('MAC003', 'Polvo de Maca', 200, 170, 'maca_polvo.jpg', 'Polvo de maca pura para aumentar energía y vitalidad.', 5, NULL, 30);
CALL insertar_producto('TGV004', 'Té Verde Matcha', 220, 180, 'matcha_tea.jpg', 'Té verde matcha premium, antioxidante y revitalizante.', 0, 40, 30);
CALL insertar_producto('HCH005', 'Harina de Chía', 160, 130, 'chia_flour.jpg', 'Harina de chía rica en fibra y omega-3.', 20, 55, 30);

-- Obtener todos los productos
CALL obtener_productos_todos();

-- Obtener producto por parametro (SKU, nombre)
CALL obtener_producto('ALV001');
CALL obtener_producto_nombre('Aceite de Coco Orgánico');

-- Obtener el inventario de un producto
CALL obtener_producto_inventario ('TGV004');

-- Modificar los datos de un producto
CALL modificar_producto_datos('ALV001', 'Extracto de Aloe Vera editado', 150, 125, 'aloe_edited_vera.jpg', 'Extracto super natural de Aloe Vera para hidratación profunda.', 0, 50);
CALL obtener_producto('ALV001');

-- Modificar el inventario de UN producto
CALL modificar_producto_inventario('TGV004', 20);
CALL obtener_producto_inventario ('TGV004');

CALL modificar_producto_inventario('MAC003', 30);
CALL obtener_producto_inventario ('TGV004');

-- Eliminar un producto
CALL eliminar_producto('HCH005');
CALL eliminar_producto('MAC003');
CALL obtener_productos_todos();


-- CARRITO

-- Obtener productos y cantidad en carrito de un usuario
CALL obtener_productos_en_carrito_usuario(1);

-- Agregar producto al carrito de un usuario (usuario, sku, cantidad)
CALL insertar_producto_carrito(1, 'MAC003', 2);
CALL insertar_producto_carrito(3, 'MAC003', 4);
CALL insertar_producto_carrito(6, 'MAC003', 10);

CALL insertar_producto_carrito(3, 'HCH005', 1);

CALL obtener_productos_en_carrito_usuario(3);

CALL insertar_producto_carrito(4, 'MAC003', 2);

CALL insertar_producto_carrito(5, 'MAC003', 2);

-- Modificar cantidad de un producto en carrito de usuario (usuario, sku, nueva cantidad)
CALL modificar_cantidad_producto_carrito (3, 'MAC003', 0);
CALL modificar_producto_inventario('MAC003', 10);
CALL obtener_producto_inventario('MAC003');
CALL modificar_cantidad_producto_carrito (6, 'MAC003', 4); 
CALL obtener_productos_en_carrito_usuario(3);

-- Eliminar producto de carrito de usuario
CALL eliminar_producto_carrito(1, 'MAC003');
CALL obtener_productos_en_carrito_usuario(1);


CALL obtener_producto_inventario ('MAC003');
CALL obtener_producto_inventario ('HCH005');


-- COMISIONES

-- Modificar las comisiones, se introduce el rol y el nuevo porcentaje 
CALL modificar_comision ('vendedor', 5);


-- VENTAS

-- Realizar una venta
CALL realizar_venta(1, '2024-09-30', 'Zapopan #314');
CALL realizar_venta(3, '2024-09-30', 'Zapopan #314');
CALL realizar_venta(6, '2024-09-30', 'Zapopan #314');

-- Obtener todas las ventas
CALL obtener_ventas_todas();

-- Vaciar carrito al realizar venta (comprobar)
CALL obtener_productos_en_carrito_usuario(3);

-- Obtener ventas usuario
CALL obtener_ventas_usuario(3);

-- Obtener ventas venta_id
-- (se obtiene el id de la primera venta realizada para hacer la prueba)
CALL obtener_venta_id((SELECT id FROM ventas WHERE fecha_venta = CURRENT_DATE() AND lugar_entrega = 'Zapopan #314' LIMIT 1));
 
-- Obtener ventas por fecha
-- dia
CALL obtener_ventas_fecha(CURRENT_DATE());
CALL obtener_ventas_fecha('2024-01-01');

-- mes (date)
CALL obtener_ventas_mes('2024-09-01');

-- trimestre (date)
CALL obtener_ventas_trimestre('2024-07-01');

-- año (date)
CALL obtener_ventas_anio('2024-09-01');


-- PRUEBAS EXTRA

CALL obtener_lista_vendedores ();
CALL obtener_lista_distribuidores ();

CALL obtener_topN_semana('2024-09-23', 2);
CALL obtener_topN_mes('2024-09-20', 3);
CALL obtener_topN_trimestre('2024-09-20', 2);

CALL obtener_ventas_todas;

CALL obtener_reporte_trimestral('2024-09-20');

CALL obtener_red_reporte_mensual('2024-09-20', 1);
CALL obtener_red_reporte_mensual('2024-09-20', 3);
CALL obtener_red_reporte_mensual('2024-09-20', 6);

CALL obtener_red_reporte_semestral('2024-09-20', 1);

CALL obtener_red_reporte_trimestral('2024-09-20', 1);
CALL obtener_red_reporte_trimestral('2024-09-20', 3);
CALL obtener_red_reporte_trimestral('2024-09-20', 6);

CALL obtener_cliente_por_usuario('Hector B');





