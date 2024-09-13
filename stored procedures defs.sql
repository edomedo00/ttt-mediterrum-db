-- SP para insertar usuario con promotor y distribuidor especificos (pueden ser nulos). 
-- Al crear un usuario, se crea un carrito para el usuario y se referencia el carrito a carrito_actual en Usuarios
DELIMITER $$
CREATE PROCEDURE insertar_usuario (
    IN nombre VARCHAR(100), 
    IN email VARCHAR(50), 
    IN telefono VARCHAR(15), 
    IN rol ENUM('vendedor', 'promotor', 'distribuidor'), 
    IN puntos_total INT, 
    IN nivel ENUM('oro', 'plata', 'bronce'), 
    IN distribuidor_id INT, 
    IN promotor_id INT
)
BEGIN 
    DECLARE nuevo_usuario_id INT;
    DECLARE nuevo_carrito_id INT;

    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Se ha producido un error en la transacción.';
    END;

    START TRANSACTION;

    INSERT INTO usuarios (
        nombre, 
        email, 
        telefono, 
        rol, 
        puntos_total, 
        nivel, 
        distribuidor, 
        promotor
    ) 
    VALUES (
        nombre, 
        email, 
        telefono, 
        rol, 
        puntos_total, 
        nivel, 
        distribuidor_id, 
        promotor_id
    );

    SET nuevo_usuario_id = LAST_INSERT_ID();

    INSERT INTO carrito (usuario) 
    VALUES (nuevo_usuario_id);

    SET nuevo_carrito_id = LAST_INSERT_ID();

    UPDATE usuarios
    SET carrito_actual = nuevo_carrito_id
    WHERE id = nuevo_usuario_id;

    COMMIT;
END $$
DELIMITER ;

-- SP para eliminar a un usuario del sistema
DELIMITER $$
CREATE PROCEDURE eliminar_usuario (
    IN usuario_id INT
)
BEGIN
    DECLARE carrito_id INT;

    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Se ha producido un error en la transacción.';
    END;

    START TRANSACTION;

    UPDATE usuarios
    SET distribuidor = NULL
    WHERE distribuidor = usuario_id;

    UPDATE usuarios
    SET promotor = NULL
    WHERE promotor = usuario_id;

    SELECT carrito_actual INTO carrito_id
    FROM usuarios
    WHERE id = usuario_id;

    IF carrito_id IS NOT NULL THEN
        UPDATE usuarios
        SET carrito_actual = NULL
        WHERE id = usuario_id;

        DELETE FROM carrito WHERE id = carrito_id;
    END IF;

    DELETE FROM usuarios WHERE id = usuario_id;

    COMMIT;
END $$
DELIMITER ;

-- SP para modificar los datos personales de un usuario
DELIMITER $$
CREATE PROCEDURE modificar_datos_usuario (
    IN usuario_id INT,
    IN nuevo_nombre VARCHAR(100),
    IN nuevo_email VARCHAR(50),
    IN nuevo_telefono VARCHAR(15)
)
BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Se ha producido un error en la transacción.';
    END;

    START TRANSACTION;

    UPDATE usuarios
    SET nombre = nuevo_nombre,
        email = nuevo_email,
        telefono = nuevo_telefono
    WHERE id = usuario_id;

    COMMIT;
END $$
DELIMITER ;

-- SP para modificar el rol de un usuario
DELIMITER $$
CREATE PROCEDURE modificar_rol_usuario (
    IN usuario_id INT,
    IN nuevo_rol ENUM('vendedor', 'promotor', 'distribuidor')
)
BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Se ha producido un error en la transacción.';
    END;

    START TRANSACTION;

    UPDATE usuarios
    SET distribuidor = NULL
    WHERE distribuidor = usuario_id;

    UPDATE usuarios
    SET promotor = NULL
    WHERE promotor = usuario_id;

    UPDATE usuarios
    SET rol = nuevo_rol
    WHERE id = usuario_id;

    COMMIT;
END $$
DELIMITER ;

-- SP para realizar una compra/venta para un usuario
-- Pasos
-- 1. Hacer consulta para extraer precio total del carrito
-- 2. Insertar la venta en la tabla ventas
-- 3. Crear un nuevo carrito y asignarselo al usuario
DELIMITER $$
CREATE PROCEDURE realizar_compra (
    IN usuario_id INT,
    IN fecha_entrega DATE,
    IN lugar_entrega VARCHAR(100)
)
BEGIN
    DECLARE precio_total FLOAT DEFAULT 0;
    DECLARE puntos_total_venta INT DEFAULT 0;
    DECLARE nuevo_carrito_id INT;
    DECLARE carrito_actual_id INT;
    DECLARE cant_disponible INT;
    DECLARE cant_comprada INT;
    DECLARE prod_sku VARCHAR(20);
    DECLARE finished INT DEFAULT 0;
    DECLARE err_message VARCHAR(30);
    
    -- cursor para iterar al revisar y actualizar inventario
	DECLARE cur CURSOR FOR
	SELECT cp.producto, cp.cantidad
    FROM carrito_producto cp
    WHERE cp.carrito = carrito_actual_id;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = 1;

    -- start transaction
    START TRANSACTION;

    SELECT carrito_actual INTO carrito_actual_id FROM usuarios WHERE id = usuario_id;

    SELECT SUM(
        cp.cantidad * (p.costo_total - (p.costo_total * IFNULL(p.descuento, 0) * 0.01))
    ) INTO precio_total
    FROM carrito_producto cp
    JOIN productos p ON cp.producto = p.sku
    WHERE cp.carrito = carrito_actual_id;

    SELECT SUM( cp.cantidad * p.puntos_producto ) INTO puntos_total_venta
    FROM carrito_producto cp
    JOIN productos p ON cp.producto = p.sku
    WHERE cp.carrito = carrito_actual_id;

    IF precio_total > 0 THEN

        OPEN cur;

        inventory_check_loop: LOOP
            FETCH cur INTO prod_sku, cant_comprada;
            IF finished THEN
                LEAVE inventory_check_loop;
            END IF;

			-- revisa el inventario para cada producto
            SELECT cantidad_inventario INTO cant_disponible
            FROM productos
            WHERE sku = prod_sku;

            IF cant_disponible < cant_comprada THEN
				-- rollback transaction si el inventario es insuficiente
                ROLLBACK;
                SET err_message = CONCAT('Inventario insuficiente para el producto: ', prod_sku);
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = err_message;
            END IF;
        END LOOP;

        CLOSE cur;

        INSERT INTO ventas (
            usuario, 
            carrito, 
            costo_total, 
            fecha_venta, 
            fecha_entrega, 
            lugar_entrega, 
            puntos_venta
        )
        VALUES (
            usuario_id, 
            carrito_actual_id, 
            precio_total, 
            CURDATE(), 
            fecha_entrega, 
            lugar_entrega, 
            puntos_total_venta
        );

        INSERT INTO carrito (usuario) VALUES (usuario_id);
        SET nuevo_carrito_id = LAST_INSERT_ID();

        UPDATE usuarios 
        SET carrito_actual = nuevo_carrito_id
        WHERE id = usuario_id;

        UPDATE usuarios 
        SET puntos_total = puntos_total + puntos_total_venta
        WHERE id = usuario_id;

        OPEN cur;

        inventory_loop_update: LOOP
            FETCH cur INTO prod_sku, cant_comprada;
            IF finished THEN
                LEAVE inventory_loop_update;
            END IF;

            UPDATE productos 
            SET cantidad_inventario = cantidad_inventario - cant_comprada
            WHERE sku = prod_sku;
        END LOOP;

        CLOSE cur;

        -- commit transaction
        COMMIT;

    ELSE
        -- rollback transaction si el carrito esta vacio 
        -- no deberia suceder porque se debe ver si el carrito esta vacio para solicitar la compra
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Carrito vacio.';
    END IF;

END $$
DELIMITER ;

-- SP para obtener la red de un usuario_id, usuarios hacia arriba y hacia abajo 
DELIMITER $$
CREATE PROCEDURE obtener_red_usuario (IN usuario_id INT)
BEGIN 
	SELECT 
		d.id AS DistribuidorID,
		d.nombre AS DistribuidorNombre,
		p.id AS PromotorID,
		p.nombre AS PromotorNombre,
		v.id AS VendedorID,
		v.nombre AS VendedorNombre
	FROM 
		usuarios d
	LEFT JOIN 
		usuarios p ON p.distribuidor = d.id AND p.rol = 'promotor'
	LEFT JOIN 
		usuarios v ON v.promotor = p.id AND v.rol = 'vendedor'
	WHERE 
		d.id = usuario_id   	
		AND d.rol = 'distribuidor'

	UNION

	SELECT 
		p.distribuidor AS DistribuidorID,
		d.nombre AS DistribuidorNombre,
		p.id AS PromotorID,
		p.nombre AS PromotorNombre,
		v.id AS VendedorID,
		v.nombre AS VendedorNombre
	FROM 
		usuarios p
	LEFT JOIN 
		usuarios d ON p.distribuidor = d.id AND d.rol = 'distribuidor'
	LEFT JOIN 
		usuarios v ON v.promotor = p.id AND v.rol = 'vendedor'
	WHERE 
		p.id = usuario_id  
		AND p.rol = 'promotor'

	UNION

	SELECT 
		d.id AS DistribuidorID,
		d.nombre AS DistribuidorNombre,
		p.id AS PromotorID,
		p.nombre AS PromotorNombre,
		v.id AS VendedorID,
		v.nombre AS VendedorNombre
	FROM 
		usuarios v
	LEFT JOIN 
		usuarios p ON v.promotor = p.id AND p.rol = 'promotor'
	LEFT JOIN 
		usuarios d ON v.distribuidor = d.id AND d.rol = 'distribuidor'
	WHERE 
		v.id = usuario_id  
		AND v.rol = 'vendedor';

END $$
DELIMITER ;

-- SP insertar cliente
DELIMITER $$
CREATE PROCEDURE insertar_cliente (
    IN c_nombre VARCHAR(50),
    IN c_email VARCHAR(30),
    IN c_telefono VARCHAR(15),
    IN c_locacion VARCHAR(30),
    IN c_intereses VARCHAR(30)
)
BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Se ha producido un error en la transacción.';
    END;

    START TRANSACTION;

    INSERT INTO clientes (nombre, email, telefono, locacion, intereses)
    VALUES (c_nombre, c_email, c_telefono, c_locacion, c_intereses);

    COMMIT;
END $$
DELIMITER ;

-- SP insertar producto
DELIMITER $$
CREATE PROCEDURE insertar_producto (
    IN p_sku VARCHAR(20),
    IN p_nombre_producto VARCHAR(30),
    IN p_costo_total INT,
    IN p_costo_no_iva INT,
    IN p_img VARCHAR(50),
    IN p_descripcion VARCHAR(100),
    IN p_descuento INT,
    IN p_puntos_producto INT,
    IN p_cantidad_inventario INT
)
BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Se ha producido un error en la transacción.';
    END;

    START TRANSACTION;

    IF EXISTS (SELECT 1 FROM productos WHERE sku = p_sku) THEN
        -- el codigo 45000 es una excepcion general o definida por el usuario.
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El SKU ya existe en la base de datos.';
    ELSE
        INSERT INTO productos (
            sku, 
            nombre_producto,
            costo_total,
            costo_no_iva,
            img,
            descripcion,
            descuento,
            puntos_producto,
            cantidad_inventario
        ) VALUES (
            p_sku, 
            p_nombre_producto,
            p_costo_total,
            p_costo_no_iva,
            p_img,
            p_descripcion,
            p_descuento,
            p_puntos_producto,
            p_cantidad_inventario
        );
    END IF;

    COMMIT;
END $$
DELIMITER ;

-- SP insertar producto en carrito_producto (usuario_id, producto_SKU)
DELIMITER $$

CREATE PROCEDURE insertar_producto_carrito (
    IN usuario_id INT,
    IN producto_sku VARCHAR(20),
    IN p_cantidad INT
)
BEGIN
    DECLARE carrito_id INT;
    DECLARE cant_disponible INT;

    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Se ha producido un error en la transacción.';
    END;

    START TRANSACTION;

    SELECT carrito_actual INTO carrito_id
    FROM usuarios
    WHERE id = usuario_id;

    SELECT cantidad_inventario INTO cant_disponible
    FROM productos
    WHERE sku = producto_sku;

    IF cant_disponible < p_cantidad THEN
		ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No hay suficiente inventario.';
    ELSE
        INSERT INTO carrito_producto (carrito, producto, cantidad)
        VALUES (carrito_id, producto_sku, p_cantidad)
        ON DUPLICATE KEY UPDATE cantidad = cantidad + VALUES(cantidad);
        -- si ya existe el producto en ese carrito, se suma la nueva cantidad a la actual 
    END IF;

    COMMIT;
END $$
DELIMITER ;

-- SP para obtener los productos en el carrito de un usuario
DELIMITER $$
CREATE PROCEDURE obtener_productos_en_carrito_usuario (
    IN usuario_id INT
)
BEGIN
    DECLARE carrito_id INT;

    SELECT carrito_actual INTO carrito_id
    FROM usuarios
    WHERE id = usuario_id;

    SELECT
        p.sku AS producto_sku,
        p.nombre_producto AS nombre,
        p.costo_total AS costo,
        cp.cantidad AS cantidad,
        (p.costo_total * cp.cantidad) AS costo_total
    FROM
        carrito_producto cp
        JOIN productos p ON cp.producto = p.sku
    WHERE
        cp.carrito = carrito_id;

END $$
DELIMITER ;

-- SP para obtener todos los productos en inventario
DELIMITER $$
CREATE PROCEDURE obtener_todos_productos()
BEGIN
    SELECT
        sku AS producto_sku,
        nombre_producto AS nombre,
        costo_total AS costo,
        costo_no_iva AS costo_sin_iva,
        img AS imagen, -- ?? no se si mostrar la URL, o como se maneje esta parte
        descripcion AS descripcion,
        descuento AS descuento,
        puntos_producto AS puntos_producto,
        cantidad_inventario AS cantidad
    FROM
        productos;
END $$
DELIMITER ;

-- SP para obtener un producto por SKU o nombre 
DELIMITER $$
CREATE PROCEDURE obtener_producto_parametro (
    IN p_parametro VARCHAR(30)
)
BEGIN
    SELECT
        sku AS producto_sku,
        nombre_producto AS nombre,
        costo_total AS costo,
        costo_no_iva AS costo_sin_iva,
        img AS imagen,  -- ?? no se si mostrar la URL, o como se maneje esta parte
        descripcion AS descripcion,
        descuento AS descuento,
        puntos_producto AS puntos_producto,
        cantidad_inventario AS cantidad
    FROM
        productos
    WHERE
        sku = p_parametro OR nombre_producto = p_parametro;
END $$
DELIMITER ;

-- SP para obtener el inventario de un producto
DELIMITER $$
CREATE PROCEDURE obtener_inventario_producto (
    IN producto_sku VARCHAR(20)
)
BEGIN

    SELECT cantidad_inventario
    FROM productos
    WHERE sku = producto_sku;
	
END $$
DELIMITER ;

-- SP para obtener un usuario por id, nombre o email 
DELIMITER $$
CREATE PROCEDURE obtener_usuario_parametro (
    IN u_parametro VARCHAR(100)
)
BEGIN
    DECLARE u_id_tel INT;
    
	IF u_parametro REGEXP '^[0-9]+$' THEN
		-- si es numerico, se convierte el parametro de entrada a un unsigned int
        SET u_id_tel = CAST(u_parametro AS UNSIGNED);
    ELSE
        SET u_id_tel = NULL;
    END IF;

    IF u_id_tel IS NOT NULL AND u_id_tel > 0 THEN
        SELECT
            id AS usuario_id,
            nombre AS nombre,
            email AS email,
            telefono AS telefono,
            rol AS rol,
            puntos_total AS puntos,
            nivel AS nivel,
            distribuidor AS distribuidor,
            promotor AS promotor,
            carrito_actual AS carrito_actual
        FROM
            usuarios
        WHERE
            id = u_id_tel OR CAST(telefono AS UNSIGNED) = u_id_tel;
    ELSE
        SELECT
            id AS usuario_id,
            nombre AS nombre,
            email AS email,
            telefono AS telefono,
            rol AS rol,
            puntos_total AS puntos,
            nivel AS nivel,
            distribuidor AS distribuidor,
            promotor AS promotor,
            carrito_actual AS carrito_actual
        FROM
            usuarios
        WHERE
            nombre = u_parametro
            OR email = u_parametro
            OR telefono = u_parametro;
    END IF;
END $$
DELIMITER ;

-- SP para obtener a todos los usuarios
DELIMITER $$
CREATE PROCEDURE obtener_todos_usuarios()
BEGIN
    SELECT
        id AS usuario_id,
        nombre AS nombre,
        email AS email,
        telefono AS telefono,
        rol AS rol,
        puntos_total AS puntos,
        nivel AS nivel,
        distribuidor AS distribuidor,
        promotor AS promotor,
        carrito_actual AS carrito_actual
    FROM
        usuarios;
END $$
DELIMITER ;

-- SP para obtener el promotor y distribuidor de un usuario
DELIMITER $$
CREATE PROCEDURE obtener_promotor_distribuidor_usuario (
    IN usuario_id INT
)
BEGIN
    SELECT 
        u.id AS usuario_id,
        u.nombre AS nombre_usuario,
        u.email AS email_usuario,
        u.rol AS rol_usuario,
        p.id AS promotor_id,
        p.nombre AS nombre_promotor,
        d.id AS distribuidor_id,
        d.nombre AS nombre_distribuidor
    FROM 
        usuarios u
    LEFT JOIN usuarios p ON u.promotor = p.id
    LEFT JOIN usuarios d ON u.distribuidor = d.id
    WHERE 
        u.id = usuario_id;
END $$
DELIMITER ;

-- SP para obtener a todos los clientes
DELIMITER $$
CREATE PROCEDURE obtener_todos_clientes()
BEGIN
    SELECT
        id AS cliente_id,
        nombre AS nombre,
        email AS email,
        telefono AS telefono,
        locacion AS locacion,
        intereses AS intereses
    FROM
        clientes;
END $$
DELIMITER ;

-- SP para obtener un cliente por su nombre, email o telefono
DELIMITER $$
CREATE PROCEDURE obtener_cliente_parametro (
    IN c_parametro VARCHAR(50)
)
BEGIN
    DECLARE c_id_tel INT;
    
	IF c_parametro REGEXP '^[0-9]+$' THEN
		-- si es numerico, se convierte el parametro de entrada a un unsigned int
        SET c_id_tel = CAST(c_parametro AS UNSIGNED);
    ELSE
        SET c_id_tel = NULL;
    END IF;

    IF c_id_tel IS NOT NULL AND c_id_tel > 0 THEN
        SELECT
            id AS cliente_id,
            nombre AS nombre,
            email AS email,
            telefono AS telefono,
            locacion AS locacion,
            intereses AS intereses
        FROM
            clientes
        WHERE
            id = c_id_tel OR telefono = c_id_tel;
    ELSE
        SELECT
            id AS cliente_id,
            nombre AS nombre,
            email AS email,
            telefono AS telefono,
            locacion AS locacion,
            intereses AS intereses
        FROM
            clientes
        WHERE
            nombre = c_parametro
            OR email = c_parametro
            OR telefono = c_parametro;
    END IF;
END $$
DELIMITER ;

-- SP para obtener las ventas de una fecha
DELIMITER $$
CREATE PROCEDURE obtener_ventas_fecha (
    IN p_fecha_venta DATE
)
BEGIN
    SELECT v.id, u.nombre AS vendedor, v.costo_total, v.fecha_venta, v.lugar_entrega, 
           GROUP_CONCAT(CONCAT(p.sku, ': ', p.nombre_producto, ' (', cp.cantidad, ')') SEPARATOR ', ') AS productos_carrito
    FROM ventas v
    JOIN usuarios u ON v.usuario = u.id
    JOIN carrito_producto cp ON v.carrito = cp.carrito
    JOIN productos p ON cp.producto = p.sku
    WHERE v.fecha_venta = p_fecha_venta
    GROUP BY v.id;
END $$
DELIMITER ;

-- SP para obtener las ventas que ha realizado un usuario
DELIMITER $$
CREATE PROCEDURE obtener_ventas_usuario (
    IN p_nombre_vendedor VARCHAR(100)
)
BEGIN
    SELECT v.id, u.nombre AS vendedor, v.costo_total, v.fecha_venta, v.lugar_entrega, 
           GROUP_CONCAT(CONCAT(p.sku, ': ', p.nombre_producto, ' (', cp.cantidad, ')') SEPARATOR ', ') AS productos_carrito
    FROM ventas v
    JOIN usuarios u ON v.usuario = u.id
    JOIN carrito_producto cp ON v.carrito = cp.carrito
    JOIN productos p ON cp.producto = p.sku
    WHERE u.nombre = p_nombre_vendedor
    GROUP BY v.id;
END $$
DELIMITER ;

-- SP para obtener una venta por ID (venta)
DELIMITER $$
CREATE PROCEDURE obtener_venta_id (
    IN p_id INT
)
BEGIN
    SELECT v.id, u.nombre AS vendedor, v.costo_total, v.fecha_venta, v.lugar_entrega, 
           GROUP_CONCAT(CONCAT(p.sku, ': ', p.nombre_producto, ' (', cp.cantidad, ')') SEPARATOR ', ') AS productos_carrito
    FROM ventas v
    JOIN usuarios u ON v.usuario = u.id
    JOIN carrito_producto cp ON v.carrito = cp.carrito
    JOIN productos p ON cp.producto = p.sku
    WHERE v.id = p_id
    GROUP BY v.id;
END $$
DELIMITER ;

-- SP para modificar los datos de un producto
DELIMITER $$
CREATE PROCEDURE modificar_producto (
    IN p_sku VARCHAR(20),
    IN p_nombre_producto VARCHAR(30),
    IN p_costo_total INT,
    IN p_costo_no_iva INT,
    IN p_img VARCHAR(50),
    IN p_descripcion VARCHAR(100),
    IN p_puntos_producto INT,
    IN p_descuento INT
)
BEGIN
    START TRANSACTION;

    UPDATE productos
    SET 
        nombre_producto = p_nombre_producto,
        costo_total = p_costo_total,
        costo_no_iva = p_costo_no_iva,
        img = p_img,
        descripcion = p_descripcion,
        puntos_producto = p_puntos_producto,
        descuento = p_descuento
    WHERE 
        sku = p_sku;

    COMMIT;

END $$
DELIMITER ;

-- SP para modificar exclusivamente el inventario de un producto
DELIMITER $$
CREATE PROCEDURE modificar_producto_inventario (
    IN p_sku VARCHAR(20),
    IN p_cantidad_inventario INT
)
BEGIN
	START TRANSACTION;
    
	IF p_cantidad_inventario >= 0 THEN
		UPDATE productos
		SET 
			cantidad_inventario = p_cantidad_inventario
		WHERE 
			sku = p_sku;
	ELSE 
		ROLLBACK;
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad no es válida.';
	END IF;
    
    COMMIT;
    
END $$
DELIMITER ;

-- SP para modificar la cantidad de productos en carrito_producto
-- hay que prevenir desde el front que se ingresen cantidades negativas
-- ademas, no estoy seguro de que sea la mejor manera de verificar si hay suficiente inventario
-- una idea es que el producto tenga un boton individual para actualizar su cantidad en el carrito, 
-- 		en lugar de un boton para actualizar las cantidades de todos los productos del carrito a la vez
DELIMITER $$
CREATE PROCEDURE modificar_cantidad__carrito_producto (
    IN usuario_id INT,
    IN producto_sku VARCHAR(20),
    IN nueva_cantidad INT
)
BEGIN
    DECLARE carrito_id INT;
    DECLARE cantidad_actual INT DEFAULT 0;
    DECLARE cantidad_inventario INT DEFAULT 0;

	START TRANSACTION;

    SELECT carrito_actual INTO carrito_id 
    FROM usuarios 
    WHERE id = usuario_id;

    SELECT cp.cantidad INTO cantidad_actual
    FROM carrito_producto cp
    WHERE cp.carrito = carrito_id AND cp.producto = producto_sku;

    SELECT cantidad_inventario INTO cantidad_inventario
    FROM productos
    WHERE sku = producto_sku;

    IF nueva_cantidad > cantidad_inventario THEN
		ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No hay suficiente inventario.';
    ELSE
        IF nueva_cantidad = 0 THEN
            DELETE FROM carrito_producto
            WHERE carrito = carrito_id AND producto = producto_sku;
        ELSE
			UPDATE carrito_producto
			SET cantidad = nueva_cantidad
			WHERE carrito = carrito_id AND producto = producto_sku;
        END IF;
        COMMIT;
    END IF;
END$$
DELIMITER ;

-- SP para modificar la informacion de un cliente
DELIMITER $$
CREATE PROCEDURE modificar_cliente (
    IN c_id INT,
    IN c_nombre VARCHAR(50),
    IN c_email VARCHAR(30),
    IN c_telefono VARCHAR(15),
    IN c_locacion VARCHAR(30),
    IN c_intereses VARCHAR(30)
)
BEGIN
	START TRANSACTION;

    UPDATE clientes
    SET 
        nombre = c_nombre,
        email = c_email,
        telefono = c_telefono,
        locacion = c_locacion,
        intereses = c_intereses
    WHERE id = c_id;
    
    COMMIT;
END$$
DELIMITER ;

-- SP para modificar distribuidor, promotor
DELIMITER $$
CREATE PROCEDURE modificar_usuario_relaciones (
    IN usuario_id INT,
    IN nuevo_distribuidor INT,
    IN nuevo_promotor INT
    )
BEGIN
	START TRANSACTION;

	IF nuevo_distribuidor = usuario_id OR nuevo_promotor = usuario_id THEN
		ROLLBACK;
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no puede ser su propio promotor/distribuidor.';
	END IF;
	
    IF nuevo_distribuidor IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = nuevo_distribuidor AND rol = 'distribuidor') THEN
			ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El distribuidor especificado no existe.';
        END IF;
    END IF;

    IF nuevo_promotor IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = nuevo_promotor AND rol = 'promotor') THEN
			ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El promotor especificado no existe.';
        END IF;
    END IF;

    UPDATE usuarios
    SET distribuidor = nuevo_distribuidor,
        promotor = nuevo_promotor
    WHERE id = usuario_id;
    
    COMMIT;
END$$
DELIMITER ;

-- SP para eliminar un producto 
DELIMITER $$
CREATE PROCEDURE eliminar_producto (
    IN producto_sku VARCHAR(20)
)
BEGIN
	START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM productos WHERE sku = producto_sku) THEN
		ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto especificado no existe.';
    ELSE
		-- elimina el producto de todos los carritos (carrrito_producto)
        DELETE FROM carrito_producto
        WHERE producto = producto_sku;

        DELETE FROM productos
        WHERE sku = producto_sku;

    END IF;
    COMMIT;
END $$
DELIMITER ;

-- SP para eliminar un producto de un carrito (carrito_producto)
DELIMITER $$
CREATE PROCEDURE eliminar_producto_de_carrito (
    IN carrito_id INT,
    IN producto_sku VARCHAR(20)
)
BEGIN
    START TRANSACTION;
    
    DELETE FROM carrito_producto
    WHERE carrito = carrito_id AND producto = producto_sku;
    
    COMMIT;
END $$
DELIMITER ;

-- SP para eliminar un cliente
DELIMITER $$
CREATE PROCEDURE eliminar_cliente (
    IN c_id INT
)
BEGIN
    DECLARE cliente_exists INT;

	START TRANSACTION;

    SELECT COUNT(*)
    INTO cliente_exists
    FROM clientes
    WHERE id = c_id;

    IF cliente_exists > 0 THEN
        DELETE FROM clientes
        WHERE id = c_id;
    ELSE
		ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no existe.';
    END IF;
    
    COMMIT;
END$$
DELIMITER ;

