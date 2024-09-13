-- Esquema de usuarios
-- Juan A (Distribuidor)
-- ├── Hector A (Promotor)
-- │   ├── Ana A (Vendedor)
-- │   └── Ana B (Vendedor)
-- └── Hector B (Promotor)
--     ├── Ana C (Vendedor)
--     └── Ana D (Vendedor)

-- Insertar usuarios de acuerdo al esquema anterior
-- Argumentos (nombre, telefono, rol, puntos_total, nivel, distribuidor_id, promotor_id) distribuidor_id y promotor_id pueden ser nulos
CALL insertar_usuario(
    'Juan A', 'juana@gmail.com', '128938747', 'distribuidor', 100, '1', NULL, NULL
);
CALL insertar_usuario(
    'Hector A', 'hectora@gmail.com', '123456789', 'promotor', 100, '1', 1, NULL
);
CALL insertar_usuario(
    'Hector B', 'hectorb@gmail.com', '812937647', 'promotor', 150, '2', 1, NULL
);
CALL insertar_usuario(
    'Ana A', 'anaa@gmail.com', '92384762', 'vendedor', 140, '1', 1, 2
);
CALL insertar_usuario(
    'Ana B', 'anab@gmail.com', '109273897', 'vendedor', 150, '2', 1, 2
);
CALL insertar_usuario(
    'Ana C', 'anac@gmail.com', '109254823', 'vendedor', 200, '3', 1, 3
);
CALL insertar_usuario(
    'Ana D', 'anad@gmail.com', '111111111', 'vendedor', 300, '2', 1, 3
);

-- Obtener todos los usuarios de la tabla usuarios
SELECT * FROM usuarios;

-- Obtener la red de un usuario en especifico. 
-- Si es distribuidor o promotor, se obtienen todas las personas debajo de el. 
-- Si es vendedor, solamente se muestra al vendedor junto con su promotor y distribuidor.
-- Parametro -> usuario id 
CALL obtener_red_usuario(1); -- Distribuidor Juan A id 1
CALL obtener_red_usuario(3); -- Promotor Hector B id 3
CALL obtener_red_usuario(5); -- Vendedor Ana B id 5

-- Se inserta un usuario para eliminarlo despues
CALL insertar_usuario(
    'Anaaaa', 'anaaa@gmail.com', '111123111', 'vendedor', 300, '2', 1, 3
);

-- Comprobar
SELECT * FROM usuarios WHERE nombre='Anaaaa';

-- Se elimina un usuario, el parametro es el id del usuario
CALL eliminar_usuario(
    (SELECT id FROM usuarios WHERE nombre = 'Anaaaa')
);
-- eliminar_usuario tambien puede eliminar distribuidores/promotores, y asignar NULL a todas las referencias a estos distribuidores/promotores

-- Comprobar
SELECT * FROM usuarios WHERE nombre='Anaaaa';

-- Modificar los datos personales de un usuario
CALL modificar_datos_usuario(
    (SELECT id FROM usuarios WHERE nombre = 'Ana D'), 
	'Ana Diaz', 
	'anadiaz@gmail.com', 
	'999888777'
    );
    
-- Comprobar los cambios    
SELECT id, nombre, email, telefono FROM usuarios WHERE nombre = 'Ana Diaz';

-- Modificar el rol de un usuario
CALL modificar_rol_usuario(
	(SELECT id FROM usuarios WHERE nombre = 'Ana Diaz'), 
    'promotor'
    );
    
-- Comprobar los cambios    
SELECT id, nombre, rol FROM usuarios WHERE nombre = 'Ana Diaz';

    
-- Modificar el rol de un usuario promotor y verificar que se desasigne como promotor de sus vendedores
CALL modificar_rol_usuario(
	(SELECT id FROM usuarios WHERE nombre = 'Hector A'), 
    'distribuidor'
    );
    
-- Comprobar los cambios 
SELECT * FROM usuarios;


