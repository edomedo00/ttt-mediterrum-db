-- Se insertan usuarios para pruebas
-- Esquema
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
CALL insertar_usuario('Juan B', 'juanb@gmail.com', '128938845', 'distribuidor', 100, 'oro', NULL, NULL); -- dist se duplica email
CALL insertar_usuario('Hector A', 'hectora@gmail.com', '123456789', 'promotor', 100, 'plata', 1, NULL); -- prom
CALL insertar_usuario('Hector B', 'hectorb@gmail.com', '812937647', 'promotor', 150, 'bronce', 1, NULL);
CALL insertar_usuario('Ana A', 'anaa@gmail.com', '92384762', 'vendedor', 140, 'oro', 1, 2); -- vend
CALL insertar_usuario('Ana B', 'anab@gmail.com', '109273897', 'vendedor', 150, 'plata', 1, 2);
CALL insertar_usuario('Ana C', 'anac@gmail.com', '109254823', 'vendedor', 200, 'plata', 1, 3);
CALL insertar_usuario('Ana D', 'anad@gmail.com', '111111111', 'vendedor', 300, 'bronce', 1, 3);

CALL insertar_usuario('Juan', 'juana@gmail.com', '1289387473', 'distribuidor', 100, 'plata', NULL, NULL); -- dist se duplica email NO se inserta
CALL insertar_usuario('Juan', 'juansadasda@gmail.com', '128938747', 'distribuidor', 100, 'plata', NULL, NULL); -- dist se duplica telefono NO se inserta

-- Insertar productos (SKU, nombre, precio, precion sin iva, img, desc, descuento, puntos)
CALL insertar_producto('ALV00232', 'Extracto de Aloe Vera', 150, 120, 'aloe_vera.jpg', 'Extracto natural de Aloe Vera para hidratación profunda.', 0, 50, 5);
CALL insertar_producto('ACO002', 'Aceite de Coco Orgánico', 180, 150, 'aceite_coco.jpg', 'Aceite virgen de coco orgánico, ideal para cocinar y cuidado de la piel.', 15, 70, 5);
CALL insertar_producto('MAC003', 'Polvo de Maca', 200, 170, 'maca_polvo.jpg', 'Polvo de maca pura para aumentar energía y vitalidad.', 5, 60, 5);
CALL insertar_producto('TGV004', 'Té Verde Matcha', 220, 180, 'matcha_tea.jpg', 'Té verde matcha premium, antioxidante y revitalizante.', 0, 40, 5);
CALL insertar_producto('HCH005', 'Harina de Chía', 160, 130, 'chia_flour.jpg', 'Harina de chía rica en fibra y omega-3.', 20, 55, 5);

-- Cambiar la cantidad de productos en inventario 
CALL modificar_producto_inventario('ALV001', 3);
-- Modificar los datos de un producto
CALL modificar_producto('ALV001', 'Extracto de Aloe Vera', 150, 125, 'aloe_vera.jpg', 'Extracto super natural de Aloe Vera para hidratación profunda.', 0, 50);

-- Modificar promotor y distribuidor de usuario_id
CALL modificar_usuario_relaciones(4, 1, 3);
CALL modificar_usuario_relaciones(5, 2, 4);
CALL modificar_usuario_relaciones(6, NULL, NULL);
CALL modificar_usuario_relaciones(6, 1, 999);

SELECT * FROM usuarios;

-- Busqueda de usuario por id, nombre, email o telefono
-- no se si sea lo mejor dejar que id y numero se revisen en la misma consulta
-- aunque se necesitarian millones de usuarios para que comiencen a chocar los valores id y tel
CALL obtener_usuario_parametro('2');
CALL obtener_usuario_parametro('Juan B');
CALL obtener_usuario_parametro('juanb@gmail.com');
CALL obtener_usuario_parametro('128938845');

-- Obtener todos los usuarios
CALL obtener_todos_usuarios();

-- Eliminar un usuario
CALL eliminar_usuario(100);

-- Insertar clientes (no se puede repetir ni email ni telefono)
CALL insertar_cliente('Laura Gomez', 'laura.gomez@gmail.com', '999999998', 'CDMX', 'Plantas curativas');
CALL insertar_cliente('Carlos Perez', 'carlos.perez@gmail.com', '999999876', 'Guadalajara', 'Plantas de alivio para dolor');

-- Obtener todos los clientes
CALL obtener_todos_clientes();

-- Obtener un cliente por ID, nombre, email o telefono
-- misma duda que con el read de usuarios
CALL obtener_cliente_parametro('laura.gomez@gmail.com');

-- Modificar un cliente
CALL modificar_cliente(2,'Laura perez', 'carlos.perez@gmail.com', '999999998', 'CDMX', 'Plantas curativas');

-- Eliminar un cliente 
CALL eliminar_cliente(2);
CALL obtener_todos_clientes();
