-- SP para insertar usuario con promotor y distribuidor especificos (pueden ser nulos). x
DELIMITER $$
CREATE PROCEDURE insertar_usuario ( 
    IN p_nombre VARCHAR(100), 
    IN p_email VARCHAR(50), 
    IN p_telefono VARCHAR(15), 
    IN p_locacion VARCHAR(50),
    IN p_rol ENUM('promotor', 'vendedor', 'distribuidor', 'administrador'), 
    IN p_puntos_total INT, 
    IN p_nivel ENUM('N1 Plata', 'N2 Oro', 'N3 Platino', 'N4 Zafiro', 'N5 Esmeralda', 'N6 Diamante'), 
    IN p_distribuidor_id INT, 
    IN p_vendedor_id INT,
    IN p_contrasena VARCHAR(20),
    IN p_creador_id INT
)
BEGIN 
    DECLARE nuevo_usuario_id INT;
    DECLARE creador_nombre VARCHAR(60);
    DECLARE creador_rol VARCHAR(15);

    IF p_puntos_total IS NULL THEN
        SET p_puntos_total = 0;
    END IF;

    START TRANSACTION;

    INSERT INTO usuarios (
        nombre, 
        email, 
        telefono, 
        locacion,
        rol, 
        puntos_total, 
        nivel, 
        distribuidor, 
        vendedor,
        contrasena
    ) 
    VALUES (
        p_nombre, 
        p_email, 
        p_telefono, 
        p_locacion,
        p_rol, 
        p_puntos_total, 
        p_nivel, 
        p_distribuidor_id, 
        p_vendedor_id,
        p_contrasena
    );

    SET nuevo_usuario_id = LAST_INSERT_ID();

    INSERT INTO carrito (usuario) 
    VALUES (nuevo_usuario_id);
    
    SELECT nombre INTO creador_nombre FROM usuarios WHERE p_creador_id = id;
    SELECT rol INTO creador_rol FROM usuarios WHERE p_creador_id = id;
    
    INSERT INTO historial (usuario, fecha, descripcion) 
	VALUES (nuevo_usuario_id, CURDATE(), CONCAT('El usuario ', p_nombre, ' fue registrado como ', p_rol, ' por el ', creador_rol, ' ', creador_nombre, '.'));

    COMMIT;
END $$
DELIMITER ;

-- SP para eliminar a un usuario del sistema x 
DELIMITER $$
CREATE PROCEDURE eliminar_usuario (
    IN usuario_id INT
)
BEGIN
    DECLARE carrito_id INT;
    DECLARE historial_id INT;

    START TRANSACTION;
    
    UPDATE usuarios
    SET distribuidor = NULL
    WHERE distribuidor = usuario_id;

    UPDATE usuarios
    SET vendedor = NULL
    WHERE vendedor = usuario_id;
    
    UPDATE clientes 
    SET usuario = NULL 
    WHERE usuario = usuario_id;

    SELECT id INTO carrito_id
    FROM carrito
    WHERE usuario = usuario_id;

    IF carrito_id IS NOT NULL THEN
        DELETE FROM carrito WHERE id = carrito_id;
    END IF;
    
    SELECT id INTO historial_id FROM historial WHERE usuario = usuario_id;
    IF historial_id IS NOT NULL THEN 
		DELETE FROM historial WHERE id = historial_id;
	END IF;

    DELETE FROM usuarios WHERE id = usuario_id;

    COMMIT;
END $$
DELIMITER ;

-- SP para modificar los datos personales de un usuario x
DELIMITER $$
CREATE PROCEDURE modificar_usuario_datos (
    IN usuario_id INT,
    IN nuevo_nombre VARCHAR(100),
    IN nuevo_email VARCHAR(50),
    IN nuevo_telefono VARCHAR(15),
    IN nueva_locacion VARCHAR(50)
)
BEGIN
DECLARE cambios INT DEFAULT 0;
    
    START TRANSACTION;
    
    IF nuevo_nombre IS NOT NULL THEN
        UPDATE usuarios 
        SET nombre = nuevo_nombre
        WHERE id = usuario_id;
        SET cambios = cambios + ROW_COUNT();
    END IF;
    
    IF nuevo_email IS NOT NULL THEN
        UPDATE usuarios 
        SET email = nuevo_email
        WHERE id = usuario_id;
        SET cambios = cambios + ROW_COUNT();
    END IF;
    
    IF nuevo_telefono IS NOT NULL THEN
        UPDATE usuarios 
        SET telefono = nuevo_telefono
        WHERE id = usuario_id;
        SET cambios = cambios + ROW_COUNT();
    END IF;
    
    IF nueva_locacion IS NOT NULL THEN
        UPDATE usuarios 
        SET locacion = nueva_locacion
        WHERE id = usuario_id;
        SET cambios = cambios + ROW_COUNT();
    END IF;
    
    IF cambios > 0 THEN
        INSERT INTO historial (usuario, fecha, descripcion) 
        VALUES (usuario_id, CURDATE(), 'Se modificaron los datos personales del usuario.');
        COMMIT;
    ELSE
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "El usuario no existe."; 
    END IF;
END $$
DELIMITER ;

-- SP para modificar el rol de un usuario x
DELIMITER $$
CREATE PROCEDURE modificar_usuario_rol ( 
    IN usuario_id INT,
    IN nuevo_rol ENUM('vendedor', 'promotor', 'distribuidor')
)
BEGIN

    START TRANSACTION;

    UPDATE usuarios
    SET distribuidor = NULL
    WHERE distribuidor = usuario_id;

    UPDATE usuarios
    SET vendedor = NULL
    WHERE vendedor = usuario_id;
    
    IF nuevo_rol = 'vendedor' THEN
		UPDATE usuarios SET vendedor = NULL WHERE usuario_id = id;
	ELSEIF nuevo_rol = 'distribuidor' THEN
		UPDATE usuarios SET distribuidor = NULL WHERE usuario_id = id;
	END IF;

    UPDATE usuarios
    SET rol = nuevo_rol
    WHERE id = usuario_id;
    
	INSERT INTO historial (usuario, fecha, descripcion) 
    VALUES (usuario_id, CURDATE(), CONCAT('El usuario cambio de rol a ', nuevo_rol, '.'));

    COMMIT;
END $$
DELIMITER ;

-- SP para modificar la contraseña de un usuario x
DELIMITER $$
CREATE PROCEDURE modificar_usuario_contrasena (
	IN usuario_id INT,
    IN nueva_contrasena VARCHAR(20)
)
BEGIN
	START TRANSACTION;
    
    UPDATE usuarios
    SET contrasena = nueva_contrasena
    WHERE id = usuario_id;
    
    COMMIT;
END $$
DELIMITER ;

-- SP para realizar una compra/venta para un usuario x
DELIMITER $$
CREATE PROCEDURE realizar_venta_interna (
    IN usuario_id INT,
    IN fecha_entrega DATE,
    IN lugar_entrega VARCHAR(100),
	OUT vend_comision DECIMAL(7, 2),
    OUT dist_comision DECIMAL(7, 2),
    OUT base_comision DECIMAL(7, 2),
    OUT eventos_comision DECIMAL(7, 2),
    OUT premios_comision DECIMAL(7, 2),
    OUT promotor_comision DECIMAL(7, 2),
    OUT bolsa_comision DECIMAL(7, 2),
    OUT venta_id INT
)
BEGIN
    DECLARE precio_total FLOAT DEFAULT 0;
    DECLARE puntos_total_venta INT DEFAULT 0;
	DECLARE puntos_total_usuario INT;
    DECLARE rol_usuario VARCHAR(20);
    DECLARE nivel_usuario VARCHAR(20);
    DECLARE carrito_compra_id INT;
    DECLARE cant_disponible INT;
    DECLARE cant_comprada INT;
    DECLARE prod_sku VARCHAR(20);
    DECLARE finished INT DEFAULT 0;
    DECLARE err_message VARCHAR(100);
    DECLARE carrito_json JSON;

	DECLARE distribuidor_nivel VARCHAR(15);
    DECLARE comision_vendedor_porcentaje DECIMAL(4, 1);
    DECLARE comision_distribuidor_porcentaje DECIMAL(4, 1);
    DECLARE comision_base_porcentaje DECIMAL(4, 1);
    DECLARE comision_eventos_porcentaje DECIMAL(4, 1);
    DECLARE comision_premios_porcentaje DECIMAL(4, 1);
    DECLARE comision_promotor_porcentaje DECIMAL(4, 1);
    DECLARE comision_bolsa_porcentaje DECIMAL(4, 1);
    
    -- cursor para iterar al revisar y actualizar inventario
	DECLARE cur_inventory CURSOR FOR
	SELECT cp.producto, cp.cantidad
	FROM carrito_producto cp
	WHERE cp.carrito = carrito_compra_id;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = 1;

    -- start transaction
    START TRANSACTION;

    SELECT id INTO carrito_compra_id FROM carrito WHERE usuario = usuario_id;
	SELECT rol INTO rol_usuario FROM usuarios WHERE id = usuario_id;

    SELECT SUM(
        cp.cantidad * (p.costo_total - (p.costo_total * IFNULL(p.descuento, 0) * 0.01))
    ) INTO precio_total
    FROM carrito_producto cp
    JOIN productos p ON cp.producto = p.sku
    WHERE cp.carrito = carrito_compra_id;

	IF rol_usuario = 'distribuidor' THEN
		SELECT SUM( cp.cantidad * p.puntos_producto ) INTO puntos_total_venta
		FROM carrito_producto cp
		JOIN productos p ON cp.producto = p.sku
		WHERE cp.carrito = carrito_compra_id;
	ELSE 
		SET puntos_total_venta = 0;
	END IF;

    IF precio_total > 0 THEN

        OPEN cur_inventory;

        inventory_check_loop: LOOP
            FETCH cur_inventory INTO prod_sku, cant_comprada;
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
            
            UPDATE productos 
			SET cantidad_inventario = cantidad_inventario - cant_comprada
			WHERE sku = prod_sku;
        END LOOP;

        CLOSE cur_inventory;

		SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'sku', p.sku,
                'nombre_producto', p.nombre_producto,
                'cantidad', cp.cantidad,
                'descuento', IFNULL(p.descuento, 0),
                'costo_individual', p.costo_total,
                'costo_total', cp.cantidad * (p.costo_total - (p.costo_total * IFNULL(p.descuento, 0) * 0.01))
            )
        ) INTO carrito_json
        FROM carrito_producto cp
        JOIN productos p ON cp.producto = p.sku
        WHERE cp.carrito = carrito_compra_id;
        
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
            carrito_json, 
            precio_total, 
            CURDATE(), 
            fecha_entrega, 
            lugar_entrega, 
            puntos_total_venta
        );
        
        SET venta_id = LAST_INSERT_ID();

        
		INSERT INTO historial (usuario, fecha, descripcion)
        VALUES (usuario_id, CURDATE(), 'El usuario realizó una compra.');
        
        -- otorgar comision a quien corresponda        
		SELECT porcentaje INTO comision_vendedor_porcentaje FROM comisiones WHERE rol = 'vendedor';
        SELECT porcentaje INTO comision_base_porcentaje FROM comisiones WHERE rol = 'base';
        SELECT porcentaje INTO comision_eventos_porcentaje FROM comisiones WHERE rol = 'eventos';
        SELECT porcentaje INTO comision_premios_porcentaje FROM comisiones WHERE rol = 'premios';
        SELECT porcentaje INTO comision_promotor_porcentaje FROM comisiones WHERE rol = 'promotor';
                
		SELECT nivel INTO distribuidor_nivel FROM usuarios WHERE id = (SELECT distribuidor FROM usuarios WHERE id = usuario_id);
        
		CASE 
			WHEN distribuidor_nivel LIKE '%1%' THEN 
				SELECT porcentaje INTO comision_distribuidor_porcentaje FROM comisiones WHERE rol = 'distribuidor N1';
			WHEN distribuidor_nivel LIKE '%2%' THEN 
				SELECT porcentaje INTO comision_distribuidor_porcentaje FROM comisiones WHERE rol = 'distribuidor N2';
			WHEN distribuidor_nivel LIKE '%3%' THEN 
				SELECT porcentaje INTO comision_distribuidor_porcentaje FROM comisiones WHERE rol = 'distribuidor N3';
			WHEN distribuidor_nivel LIKE '%4%' THEN 
				SELECT porcentaje INTO comision_distribuidor_porcentaje FROM comisiones WHERE rol = 'distribuidor N4';
			WHEN distribuidor_nivel LIKE '%5%' THEN 
				SELECT porcentaje INTO comision_distribuidor_porcentaje FROM comisiones WHERE rol = 'distribuidor N5';
			WHEN distribuidor_nivel LIKE '%DD%' THEN -- NO existe ningun nivel 'DD', nunca entrara en este case
				SELECT porcentaje INTO comision_distribuidor_porcentaje FROM comisiones WHERE rol = 'distribuidor DD';
			ELSE
				SELECT 0 INTO comision_distribuidor_porcentaje;
		END CASE;
        
		SET vend_comision = (precio_total * comision_vendedor_porcentaje * 0.01);
		SET base_comision = (precio_total * comision_base_porcentaje * 0.01);
		SET eventos_comision = (precio_total * comision_eventos_porcentaje * 0.01);
		SET premios_comision = (precio_total * comision_premios_porcentaje * 0.01);
		SET promotor_comision = (precio_total * comision_promotor_porcentaje * 0.01);
		
        SET dist_comision = (precio_total * comision_distribuidor_porcentaje * 0.01);
		SET bolsa_comision = (precio_total * (20-comision_distribuidor_porcentaje) * 0.01);

        -- Solo distribuidores tienen sistema de puntos
        IF rol_usuario = 'distribuidor' THEN
			-- prevenir que los usuarios sumen mas de 9999 puntos 
			UPDATE usuarios
			SET puntos_total =	CASE
									WHEN puntos_total + puntos_total_venta > 9999 THEN 9999
									ELSE puntos_total + puntos_total_venta
								END
			WHERE id = usuario_id AND puntos_total < 9999;
			
			-- Actualizar nivel de usuario
			SELECT puntos_total, nivel INTO puntos_total_usuario, nivel_usuario FROM usuarios WHERE id = usuario_id;

			IF puntos_total_usuario >= 5001 AND nivel_usuario <> 'N6 Diamante' THEN
				UPDATE usuarios SET nivel = 'N6 Diamante' WHERE id = usuario_id;
				INSERT INTO historial (usuario, fecha, descripcion) 
				VALUES (usuario_id, CURDATE(), 'El usuario subió de nivel a N6 Diamante');
			ELSEIF puntos_total_usuario >= 4001 AND nivel_usuario NOT IN ('N6 Diamante', 'N5 Esmeralda') THEN
				UPDATE usuarios SET nivel = 'N5 Esmeralda' WHERE id = usuario_id;
				INSERT INTO historial (usuario, fecha, descripcion) 
				VALUES (usuario_id, CURDATE(), 'El usuario subió de nivel a N5 Esmeralda');
			ELSEIF puntos_total_usuario >= 3001 AND nivel_usuario NOT IN ('N6 Diamante', 'N5 Esmeralda', 'N4 Zafiro') THEN
				UPDATE usuarios SET nivel = 'N4 Zafiro' WHERE id = usuario_id;
				INSERT INTO historial (usuario, fecha, descripcion) 
				VALUES (usuario_id, CURDATE(), 'El usuario subió de nivel a N4 Zafiro');
			ELSEIF puntos_total_usuario >= 2001 AND nivel_usuario NOT IN ('N6 Diamante', 'N5 Esmeralda', 'N4 Zafiro', 'N3 Platino') THEN
				UPDATE usuarios SET nivel = 'N3 Platino' WHERE id = usuario_id;
				INSERT INTO historial (usuario, fecha, descripcion)
				VALUES (usuario_id, CURDATE(), 'El usuario subió de nivel a N3 Platino');
			ELSEIF puntos_total_usuario >= 1001 AND nivel_usuario NOT IN ('N6 Diamante', 'N5 Esmeralda', 'N4 Zafiro', 'N3 Platino', 'N2 Oro') THEN
				UPDATE usuarios SET nivel = 'N2 Oro' WHERE id = usuario_id;
				INSERT INTO historial (usuario, fecha, descripcion)
				VALUES (usuario_id, CURDATE(), 'El usuario subió de nivel a N2 Oro');
			ELSEIF puntos_total_usuario >= 320 AND (nivel_usuario IS NULL OR nivel_usuario NOT IN ('N6 Diamante', 'N5 Esmeralda', 'N4 Zafiro', 'N3 Platino', 'N2 Oro', 'N1 Plata')) THEN
				UPDATE usuarios SET nivel = 'N1 Plata' WHERE id = usuario_id;
				INSERT INTO historial (usuario, fecha, descripcion) 
				VALUES (usuario_id, CURDATE(), 'El usuario subió de nivel a N1 Plata');
			END IF;
		END IF;
        
		-- eliminar todos los productos del carrito del usuario
        DELETE FROM carrito_producto WHERE carrito = carrito_compra_id;

        -- commit transaction
        COMMIT;

    ELSE
        -- rollback transaction si el carrito esta vacio 
        -- no deberia suceder porque se debe ver si el carrito esta vacio para solicitar la compra
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Carrito vacío.';
    END IF;

END $$
DELIMITER ;

-- SP para realizar una venta y regresar los datos de la misma junto con las comisiones generadas x
DELIMITER $$
CREATE PROCEDURE realizar_venta (
    IN usuario_id INT,
    IN fecha_entrega DATE,
    IN lugar_entrega VARCHAR(100)
)
BEGIN
    DECLARE vend_comision DECIMAL(7, 2);
    DECLARE dist_comision DECIMAL(7, 2);
    DECLARE base_comision DECIMAL(7, 2);
    DECLARE eventos_comision DECIMAL(7, 2);
    DECLARE premios_comision DECIMAL(7, 2);
    DECLARE promotor_comision DECIMAL(7, 2);
    DECLARE bolsa_comision DECIMAL(7, 2);
    DECLARE venta_id INT;
   	DECLARE distribuidor_nivel VARCHAR(15);


	-- realizar venta y obtener las comisiones
    CALL realizar_venta_interna(
        usuario_id,
        fecha_entrega,
        lugar_entrega,
        vend_comision,
        dist_comision,
        base_comision,
        eventos_comision,
        premios_comision,
        promotor_comision,
        bolsa_comision,
        venta_id
    );
    
	SELECT nivel INTO distribuidor_nivel FROM usuarios WHERE id = (SELECT distribuidor FROM usuarios WHERE id = usuario_id);

	-- tabla temporal para arrojar los resultados de al venta y las comisiones
	DROP TEMPORARY TABLE IF EXISTS temp_ventas_comisiones;
    CREATE TEMPORARY TABLE IF NOT EXISTS temp_ventas_comisiones (
        id INT,
        usuario INT,
        carrito JSON,
        costo_total FLOAT,
        fecha_venta DATE,
        fecha_entrega DATE,
        lugar_entrega VARCHAR(100),
        puntos_venta INT,
        vendedor_de_usuario VARCHAR(50),
        comision_vendedor DECIMAL(7, 2),
        distribuidor_de_usuario VARCHAR(50),
        nivel_distribuidor VARCHAR(15),
        comision_distribuidor DECIMAL(7, 2),
        comision_promotor DECIMAL(7, 2),
        comision_bolsa DECIMAL(7, 2),
        comision_base DECIMAL(7, 2),
        comision_eventos DECIMAL(7, 2),
        comision_premios DECIMAL(7, 2)
    );

	INSERT INTO temp_ventas_comisiones
    SELECT 
        v.id,
        v.usuario,
        v.carrito,
        v.costo_total,
        v.fecha_venta,
        v.fecha_entrega,
        v.lugar_entrega,
        v.puntos_venta,
        u.vendedor AS vendedor_de_usuario,
        vend_comision AS comision_vendedor,
        u.distribuidor AS distribuidor_de_usuario,
		distribuidor_nivel AS nivel_distribuidor,
        dist_comision AS comision_distribuidor,
        promotor_comision,
        bolsa_comision,
        base_comision,
        eventos_comision,
        premios_comision
    FROM ventas v
    JOIN usuarios u ON v.usuario = u.id
    WHERE v.id = venta_id;

    SELECT * FROM temp_ventas_comisiones;
	
    DROP TEMPORARY TABLE IF EXISTS temp_ventas_comisiones;
END $$
DELIMITER ;

-- SP para establecer los porcentajes de comisiones para los roles x
DELIMITER $$ 
CREATE PROCEDURE modificar_comision (
    IN p_rol VARCHAR(15),
    IN p_nueva_comision DECIMAL(4,1)
)
BEGIN 
    DECLARE v_exists INT;

    SELECT COUNT(*)
    INTO v_exists
    FROM comisiones 
    WHERE rol = p_rol;

    IF v_exists > 0 THEN
        UPDATE comisiones 
        SET porcentaje = p_nueva_comision
        WHERE rol = p_rol;
    ELSE 
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El rol no existe en la tabla comisiones.';
    END IF;
END $$
DELIMITER ;

-- SP para reiniciar el conteo de puntos (call cada trimestre)
DELIMITER $$ 
CREATE PROCEDURE reset_usuarios_puntos_nivel ()
BEGIN
    UPDATE usuarios
    SET puntos_total = 0,
        nivel = NULL
	WHERE rol = 'distribuidor';
END $$ 
DELIMITER ;


-- SP para obtener la red de un usuario_id, usuarios hacia arriba y hacia abajo x
DELIMITER $$
CREATE PROCEDURE obtener_usuario_red (
IN usuario_id INT
)
BEGIN 
	SELECT 
		d.id AS DistribuidorID,
		d.nombre AS DistribuidorNombre,
		v.id AS VendedorID,
		v.nombre AS VendedorNombre,
		p.id AS PromotorID,
		p.nombre AS PromotorNombre
	FROM 
		usuarios d
	LEFT JOIN 
		usuarios v ON v.distribuidor = d.id AND v.rol = 'vendedor'
	LEFT JOIN 
		usuarios p ON p.vendedor = v.id AND p.rol = 'promotor'
	WHERE 
		d.id = usuario_id   	
		AND d.rol = 'distribuidor'

	UNION

	SELECT 
		v.distribuidor AS DistribuidorID,
		d.nombre AS DistribuidorNombre,
		v.id AS VendedorID,
		v.nombre AS VendedorNombre,
		p.id AS PromotorID,
		p.nombre AS PromotorNombre
	FROM 
		usuarios v
	LEFT JOIN 
		usuarios d ON v.distribuidor = d.id AND d.rol = 'distribuidor'
	LEFT JOIN 
		usuarios p ON p.vendedor = v.id AND p.rol = 'promotor'
	WHERE 
		v.id = usuario_id  
		AND v.rol = 'vendedor'

	UNION

	SELECT 
		d.id AS DistribuidorID,
		d.nombre AS DistribuidorNombre,
		v.id AS VendedorID,
		v.nombre AS VendedorNombre,
		p.id AS PromotorID,
		p.nombre AS PromotorNombre
	FROM 
		usuarios p
	LEFT JOIN 
		usuarios v ON p.vendedor = v.id AND v.rol = 'vendedor'
	LEFT JOIN 
		usuarios d ON p.distribuidor = d.id AND d.rol = 'distribuidor'
	WHERE 
		p.id = usuario_id  
		AND p.rol = 'promotor';

END $$
DELIMITER ;

-- SP insertar cliente x
DELIMITER $$
CREATE PROCEDURE insertar_cliente (
    IN c_usuario INT,
    IN c_nombre VARCHAR(50),
    IN c_email VARCHAR(30),
    IN c_telefono VARCHAR(15),
	IN c_locacion VARCHAR(50),
    IN c_intereses VARCHAR(30)
)
BEGIN
	DECLARE usuario_exists INT;
    
    SELECT COUNT(*) INTO usuario_exists FROM usuarios WHERE id = c_usuario;
    
    IF usuario_exists = 0 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe';
	ELSE 		
		START TRANSACTION;
		INSERT INTO clientes (usuario, nombre, email, telefono, locacion, intereses)
		VALUES (c_usuario, c_nombre, c_email, c_telefono, c_locacion, c_intereses);
        
        
        INSERT INTO historial (usuario, fecha, descripcion)
        VALUES (c_usuario, CURDATE(), CONCAT('El usuario registró el cliente ', c_nombre, '.'));
		COMMIT;
	END IF;
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

    START TRANSACTION;

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
            IFNULL(NULLIF(p_puntos_producto, 0), ROUND(p_costo_total / 100)), -- primero revisa si puntos es 0, si es, lo convierte a NULL, luego, si ese valor es NULL, pone puntos_prod por defecto como p_costo_total/100 
            p_cantidad_inventario
        );

    COMMIT;
END $$
DELIMITER ;

-- SP insertar producto en carrito_producto (usuario_id, producto_SKU) x
DELIMITER $$
CREATE PROCEDURE insertar_producto_carrito (
    IN usuario_id INT,
    IN producto_sku VARCHAR(20),
    IN p_cantidad INT
)
BEGIN
    DECLARE carrito_id INT;
    DECLARE cant_disponible INT;
    DECLARE cant_en_carrito INT;

    START TRANSACTION;

    SELECT id INTO carrito_id
    FROM carrito
    WHERE usuario = usuario_id;
    
    SELECT cantidad INTO cant_en_carrito 
    FROM carrito_producto
    WHERE producto = producto_sku AND carrito_id = carrito;

    SELECT cantidad_inventario INTO cant_disponible
    FROM productos
    WHERE sku = producto_sku;

    IF (cant_disponible < p_cantidad + cant_en_carrito) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No hay suficiente inventario.';
    ELSE
        INSERT INTO carrito_producto (carrito, producto, cantidad)
        VALUES (carrito_id, producto_sku, p_cantidad)
        ON DUPLICATE KEY UPDATE cantidad = cantidad + VALUES(cantidad);
        -- si ya existe el producto en ese carrito, se suma la nueva cantidad a la actual 
    END IF;

    COMMIT;
END $$
DELIMITER;

-- SP para obtener los productos en el carrito de un usuario x
DELIMITER $$
CREATE PROCEDURE obtener_productos_en_carrito_usuario (
    IN usuario_id INT
)
BEGIN
    DECLARE carrito_id INT;

    SELECT id INTO carrito_id
    FROM carrito
    WHERE usuario = usuario_id;

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

-- SP para obtener todos los productos en inventario x
DELIMITER $$
CREATE PROCEDURE obtener_productos_todos()
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

-- SP para obtener producto por SKU x
DELIMITER $$
CREATE PROCEDURE obtener_producto (
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
        sku = p_parametro;
END $$
DELIMITER ;

-- SP para obtener un producto por nombre x 
DELIMITER $$
CREATE PROCEDURE obtener_producto_nombre (
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
		nombre_producto = p_parametro;
END $$
DELIMITER ;

-- SP para obtener el inventario de un producto x
DELIMITER $$
CREATE PROCEDURE obtener_producto_inventario (
    IN producto_sku VARCHAR(20)
)
BEGIN

    SELECT cantidad_inventario
    FROM productos
    WHERE sku = producto_sku;
	
END $$
DELIMITER ;

-- SP para obtener un usuario por id x
DELIMITER $$
CREATE PROCEDURE obtener_usuario (
    IN u_id INT
)
BEGIN
    SELECT
        id AS usuario_id,
        nombre AS nombre,
        email AS email,
        telefono AS telefono,
        locacion AS locacion,
        rol AS rol,
        puntos_total AS puntos,
        nivel AS nivel,
        distribuidor AS distribuidor,
        vendedor AS vendedor
    FROM
        usuarios
    WHERE
        id = u_id;
END $$
DELIMITER ;

-- SP para obtener un usuario por nombre, email o telefono x
DELIMITER $$
CREATE PROCEDURE obtener_usuario_parametro (
    IN u_parametro VARCHAR(100)
)
BEGIN
    SELECT
        id AS usuario_id,
        nombre AS nombre,
        email AS email,
        telefono AS telefono,
        locacion AS locacion,
        rol AS rol,
        puntos_total AS puntos,
        nivel AS nivel,
        distribuidor AS distribuidor,
        vendedor AS vendedor
    FROM
        usuarios
    WHERE
        nombre = u_parametro
        OR email = u_parametro
        OR telefono = u_parametro;
END $$
DELIMITER ;

-- SP para obtener a todos los usuarios x
DELIMITER $$
CREATE PROCEDURE obtener_usuarios_todos()
BEGIN
    SELECT
        id AS usuario_id,
        nombre AS nombre,
        email AS email,
        telefono AS telefono,
        locacion AS locacion,
        rol AS rol,
        puntos_total AS puntos,
        nivel AS nivel,
        distribuidor AS distribuidor,
        vendedor AS vendedor
    FROM
        usuarios;
END $$
DELIMITER ;

-- SP para obtener el vendedor y distribuidor de un usuario x
DELIMITER $$
CREATE PROCEDURE obtener_usuario_relaciones (
    IN usuario_id INT
)
BEGIN
    SELECT 
        u.id AS usuario_id,
        u.nombre AS nombre_usuario,
        u.email AS email_usuario,
        u.rol AS rol_usuario,
        v.id AS vendedor_id,
        v.nombre AS nombre_vendedor,
        d.id AS distribuidor_id,
        d.nombre AS nombre_distribuidor
    FROM 
        usuarios u
    LEFT JOIN usuarios v ON u.vendedor = v.id
    LEFT JOIN usuarios d ON u.distribuidor = d.id
    WHERE 
        u.id = usuario_id;
END $$
DELIMITER ;

-- SP para obtener los puntos de un usuario por trimestre x
DELIMITER $$ 
CREATE PROCEDURE obtener_usuario_puntos_trimestre (
	IN p_usuario_id INT,
    IN p_fecha DATE
)
BEGIN
	SELECT u.id AS usuario_id, u.nombre AS nombre, SUM(v.puntos_venta) AS puntos_trimestre
	FROM usuarios u
    JOIN ventas v ON v.usuario = u.id
    WHERE p_usuario_id = u.id
        AND YEAR(p_fecha) = YEAR(v.fecha_venta)
        AND QUARTER(p_fecha) = QUARTER(v.fecha_venta)
	GROUP BY u.id;
END $$
DELIMITER ;

-- SP para obtener los puntos de un usuario por año x 
DELIMITER $$ 
CREATE PROCEDURE obtener_usuario_puntos_anio (
	IN p_usuario_id INT,
    IN p_fecha DATE
)
BEGIN
	SELECT u.id AS usuario_id, u.nombre AS nombre, SUM(v.puntos_venta) AS puntos_anio
	FROM usuarios u
    JOIN ventas v ON v.usuario = u.id
    WHERE p_usuario_id = u.id 
		AND YEAR(p_fecha) = YEAR(v.fecha_venta)
	GROUP BY u.id;
END $$
DELIMITER ;

-- SP para obtener el nombre del distribuidor de un usuario x
DELIMITER $$
CREATE PROCEDURE obtener_usuario_distribuidor (
	IN usuario_id INT
)
BEGIN
	SELECT nombre FROM usuarios WHERE (SELECT distribuidor FROM usuarios WHERE id = usuario_id) = id;
END $$
DELIMITER ;

-- SP para obtener el nombre del vendedor de un usuario x
DELIMITER $$
CREATE PROCEDURE obtener_usuario_vendedor (
	IN usuario_id INT
)
BEGIN
	SELECT nombre FROM usuarios WHERE (SELECT vendedor FROM usuarios WHERE id = usuario_id) = id;
END $$
DELIMITER ;

-- SP para obtener el historial de un usuario x
DELIMITER $$
CREATE PROCEDURE obtener_usuario_historial (
	IN usuario_id INT
)
BEGIN 
	SELECT h.usuario, u.nombre, h.fecha, h.descripcion 
    FROM historial h
    JOIN usuarios u ON h.usuario = u.id
    WHERE usuario = usuario_id;
END $$
DELIMITER ;

-- SP para obtener la lista de distribuidores x
DELIMITER $$
CREATE PROCEDURE obtener_lista_distribuidores ()
BEGIN 
	SELECT nombre FROM usuarios WHERE rol = 'distribuidor';
END $$
DELIMITER ;

-- SP para obtener la lista de vendedores x
DELIMITER $$
CREATE PROCEDURE obtener_lista_vendedores ()
BEGIN 
	SELECT nombre FROM usuarios WHERE rol = 'vendedor';
END $$
DELIMITER ; 

-- SP para obtener a todos los clientes x
DELIMITER $$
CREATE PROCEDURE obtener_clientes_todos()
BEGIN
    SELECT
        c.id AS cliente_id,
        u.nombre AS usuario_nombre,
        c.nombre AS nombre,
        c.email AS email,
        c.telefono AS telefono,
        c.locacion AS locacion,
        c.intereses AS intereses
    FROM
        clientes c
    JOIN
        usuarios u ON u.id = c.usuario;
END $$
DELIMITER ;

-- SP para obtener cliente por id  x
DELIMITER $$
CREATE PROCEDURE obtener_cliente (
    IN c_id INT
)
BEGIN
	SELECT 
		c.id AS cliente_id,
		u.nombre AS usuario,
		c.nombre AS nombre,
		c.email AS email,
		c.telefono AS telefono,
		c.locacion AS locacion,
		c.intereses AS intereses
	FROM 
		clientes c
	JOIN 
		usuarios u ON u.id = c.usuario
	WHERE 
		c.id = c_id;

END $$
DELIMITER ;

-- SP para obtener un cliente por su nombre, email o telefono x
DELIMITER $$
CREATE PROCEDURE obtener_cliente_parametro (
    IN c_parametro VARCHAR(50)
)
BEGIN
    SELECT
        c.id AS cliente_id,
        u.nombre AS usuario,
        c.nombre AS nombre,
        c.email AS email,
        c.telefono AS telefono,
        c.locacion AS locacion,
        c.intereses AS intereses
    FROM
        clientes c 
	JOIN 
		usuarios u ON u.id = c.usuario
    WHERE
        c.nombre = c_parametro
        OR c.email = c_parametro
        OR c.telefono = c_parametro;
END $$
DELIMITER ;

-- SP para obtener un cliente por su usuario x
DELIMITER $$
CREATE PROCEDURE obtener_cliente_por_usuario (
    IN c_usuario_nombre VARCHAR(50)
)
BEGIN
	DECLARE id_usuario INT;

	SELECT id INTO id_usuario FROM usuarios WHERE nombre = c_usuario_nombre;
    
    IF id_usuario IS NULL THEN 
		SELECT 'No existe un usuario con ese nombre.' AS mensaje;
	ELSE 

		SELECT
			c.id AS cliente_id,
			c.usuario AS usuario,
			u.nombre AS nombre,
			c.email AS email,
			c.telefono AS telefono,
			c.locacion AS locacion,
			c.intereses AS intereses
		FROM
			clientes c
		JOIN 
			usuarios u ON u.id = c.usuario
		WHERE
			usuario = id_usuario;

	END IF;
END $$
DELIMITER ;

-- SP para obtener todas las ventas x 
DELIMITER $$
CREATE PROCEDURE obtener_ventas_todas()
BEGIN
    SELECT * FROM ventas;
END$$
DELIMITER ;

-- SP para obtener las ventas de una fecha x
DELIMITER $$
CREATE PROCEDURE obtener_ventas_fecha (
    IN p_fecha DATE
)
BEGIN
    SELECT v.id, u.nombre AS usuario, v.costo_total, v.puntos_venta, v.fecha_venta, v.lugar_entrega, v.carrito
    FROM ventas v
    JOIN usuarios u ON v.usuario = u.id
    WHERE v.fecha_venta = p_fecha
    GROUP BY v.id;
END $$
DELIMITER ;

-- SP para obtener las ventas de una semana x
DELIMITER $$
CREATE PROCEDURE obtener_ventas_semana (
	IN p_fecha DATE
)
BEGIN
	    SELECT v.id, u.nombre AS usuario, v.costo_total, v.puntos_venta, v.fecha_venta, v.lugar_entrega, v.carrito
    FROM ventas v
    JOIN usuarios u ON v.usuario = u.id
    WHERE YEAR(v.fecha_venta) = YEAR(p_fecha) 
      AND MONTH(v.fecha_venta) = MONTH(p_fecha)
      AND WEEK(v.fecha_venta) = WEEK(p_fecha)
    GROUP BY v.id
    ORDER BY v.fecha_venta ASC;
END $$
DELIMITER ;

-- SP para obtener las ventas de un mes x
DELIMITER $$
CREATE PROCEDURE obtener_ventas_mes (
	IN p_fecha DATE
)
BEGIN
	    SELECT v.id, u.nombre AS usuario, v.costo_total, v.puntos_venta, v.fecha_venta, v.lugar_entrega, v.carrito
    FROM ventas v
    JOIN usuarios u ON v.usuario = u.id
    WHERE YEAR(v.fecha_venta) = YEAR(p_fecha) 
      AND MONTH(v.fecha_venta) = MONTH(p_fecha)
    GROUP BY v.id
    ORDER BY v.fecha_venta ASC;
END $$
DELIMITER ;

-- SP para obtener las ventas de un trimestre x 
DELIMITER $$ 
CREATE PROCEDURE obtener_ventas_trimestre (
    IN p_fecha DATE
)
BEGIN
    SELECT v.id, u.nombre AS usuario, v.costo_total, v.puntos_venta, v.fecha_venta, v.lugar_entrega, v.carrito
    FROM ventas v
    JOIN usuarios u ON v.usuario = u.id
    WHERE YEAR(v.fecha_venta) = YEAR(p_fecha)
      AND QUARTER(v.fecha_venta) = QUARTER(p_fecha)
    GROUP BY v.id
    ORDER BY v.fecha_venta ASC;
END $$
DELIMITER ;

-- SP para obtener las ventas de un año x
DELIMITER $$
CREATE PROCEDURE obtener_ventas_anio (
    IN p_fecha DATE
)
BEGIN
    SELECT v.id, u.nombre AS usuario, v.costo_total, v.puntos_venta, v.fecha_venta, v.lugar_entrega, v.carrito
    FROM ventas v
    JOIN usuarios u ON v.usuario = u.id
    WHERE YEAR(v.fecha_venta) = YEAR(p_fecha)
    GROUP BY v.id
    ORDER BY v.fecha_venta ASC;
END $$
DELIMITER ;

-- SP para obtener las ventas que ha realizado un usuario x
DELIMITER $$
CREATE PROCEDURE obtener_ventas_usuario (
    IN p_vendedor_id VARCHAR(100)
)
BEGIN
    SELECT v.id, u.nombre AS usuario, v.costo_total, v.puntos_venta, v.fecha_venta, v.lugar_entrega, v.carrito
    FROM ventas v
    JOIN usuarios u ON v.usuario = u.id
    WHERE v.usuario = p_vendedor_id
    GROUP BY v.id
    ORDER BY v.fecha_venta ASC;
END $$
DELIMITER ;

-- SP para obtener una venta por ID (venta) x
DELIMITER $$
CREATE PROCEDURE obtener_venta_id (
    IN v_id INT
)
BEGIN
    SELECT v.id, u.nombre AS usuario, v.costo_total, v.puntos_venta, v.fecha_venta, v.lugar_entrega, v.carrito
    FROM ventas v
    JOIN usuarios u ON v.usuario = u.id
    WHERE v.id = v_id
    GROUP BY v.id;
END $$
DELIMITER ;

-- SP para obtener top 100 usuarios de una semana x
DELIMITER $$ 
CREATE PROCEDURE obtener_topN_semana (
    IN p_fecha DATE,
    IN top_n INT
)
BEGIN
    SELECT u.id, u.nombre, SUM(v.puntos_venta) AS total_puntos
    FROM ventas v
    JOIN usuarios u ON v.usuario = u.id
    WHERE YEAR(v.fecha_venta) = YEAR(p_fecha) 
      AND WEEK(v.fecha_venta, 1) = WEEK(p_fecha, 1) -- 1 para que la semana empiece en lunes
      AND u.puntos_total > 0
    GROUP BY u.id
    ORDER BY total_puntos DESC
    LIMIT top_n;
END $$
DELIMITER ;

-- SP para obtener top 100 usuarios de un mes x
DELIMITER $$ 
CREATE PROCEDURE obtener_topN_mes (
	IN p_fecha DATE,
    IN top_n INT
)
BEGIN
	SELECT u.id, u.nombre, SUM(v.puntos_venta) AS total_puntos
    FROM ventas v
    JOIN usuarios u ON v.usuario = u.id
    WHERE MONTH(v.fecha_venta) = MONTH(p_fecha)
		AND YEAR(v.fecha_venta) = YEAR(p_fecha)
        AND u.puntos_total > 0
    GROUP BY u.id
    ORDER BY total_puntos DESC
    LIMIT top_n;
END $$
DELIMITER ;

-- SP para obtener top 100 usuarios de un trimestre x
DELIMITER $$ 
CREATE PROCEDURE obtener_topN_trimestre (
    IN p_fecha DATE,
    IN top_n INT
)
BEGIN
    SELECT u.id, u.nombre, SUM(v.puntos_venta) AS total_puntos
    FROM ventas v
    JOIN usuarios u ON v.usuario = u.id
    WHERE QUARTER(v.fecha_venta) = QUARTER(p_fecha)
      AND YEAR(v.fecha_venta) = YEAR(p_fecha)
      AND u.puntos_total > 0
    GROUP BY u.id
    ORDER BY total_puntos DESC
    LIMIT top_n;
END $$
DELIMITER ;

-- SP para obtener reporte trimestral x
DELIMITER $$
CREATE PROCEDURE obtener_reporte_trimestral (
	IN p_fecha DATE
)
BEGIN

	SELECT
		QUARTER(p_fecha) AS trimestre,
		SUM(v.costo_total) AS ingreso_total, 
		SUM(v.puntos_venta) AS total_puntos, 
		SUM(ct.cantidad) AS productos_vendidos
	FROM ventas v
	JOIN JSON_TABLE (
		v.carrito,
        '$[*]' COLUMNS (
			cantidad INT PATH '$.cantidad'	
        )
    ) ct
    WHERE QUARTER(fecha_venta) = QUARTER(p_fecha)
        AND YEAR(fecha_venta) = YEAR(p_fecha);
    
END $$
DELIMITER ;

-- SP para obtener reporte trimestral por red x
DELIMITER $$
CREATE PROCEDURE obtener_red_reporte_trimestral (
    IN p_fecha DATE,
    IN usuario_id INT
)
BEGIN
    DECLARE rol_usuario VARCHAR(15);

    SELECT rol INTO rol_usuario FROM usuarios WHERE id = usuario_id;

    IF rol_usuario = 'distribuidor' THEN
        SELECT
            QUARTER(p_fecha) AS trimestre,
            SUM(v.costo_total) AS ingreso_total, 
            SUM(v.puntos_venta) AS total_puntos, 
            SUM(ct.cantidad) AS productos_vendidos
        FROM ventas v
        JOIN usuarios u ON u.id = v.usuario
        JOIN JSON_TABLE (
            v.carrito,
            '$[*]' COLUMNS (
                cantidad INT PATH '$.cantidad'    
            )
        ) ct
        WHERE (u.id = usuario_id OR u.distribuidor = usuario_id)
            AND QUARTER(fecha_venta) = QUARTER(p_fecha)
            AND YEAR(fecha_venta) = YEAR(p_fecha);
    
    ELSEIF rol_usuario = 'vendedor' THEN
        SELECT
            QUARTER(p_fecha) AS trimestre,
            SUM(v.costo_total) AS ingreso_total, 
            SUM(v.puntos_venta) AS total_puntos, 
            SUM(ct.cantidad) AS productos_vendidos
        FROM ventas v
        JOIN usuarios u ON u.id = v.usuario
        JOIN JSON_TABLE (
            v.carrito,
            '$[*]' COLUMNS (
                cantidad INT PATH '$.cantidad'    
            )
        ) ct
        WHERE (u.id = usuario_id OR u.vendedor = usuario_id)
            AND QUARTER(fecha_venta) = QUARTER(p_fecha)
            AND YEAR(fecha_venta) = YEAR(p_fecha);

    ELSEIF rol_usuario = 'promotor' THEN
        SELECT
            QUARTER(p_fecha) AS trimestre,
            SUM(v.costo_total) AS ingreso_total, 
            SUM(v.puntos_venta) AS total_puntos, 
            SUM(ct.cantidad) AS productos_vendidos
        FROM ventas v
        JOIN JSON_TABLE (
            v.carrito,
            '$[*]' COLUMNS (
                cantidad INT PATH '$.cantidad'    
            )
        ) ct
        WHERE v.usuario = usuario_id
            AND QUARTER(fecha_venta) = QUARTER(p_fecha)
            AND YEAR(fecha_venta) = YEAR(p_fecha);
    END IF;

END $$
DELIMITER ;

-- SP para obtener reporte mensual por red x
DELIMITER $$
CREATE PROCEDURE obtener_red_reporte_mensual (
    IN p_fecha DATE,
    IN usuario_id INT
)
BEGIN
    DECLARE rol_usuario VARCHAR(15);

    SELECT rol INTO rol_usuario FROM usuarios WHERE id = usuario_id;

    IF rol_usuario = 'distribuidor' THEN
        SELECT
            MONTH(p_fecha) AS mes,
            SUM(v.costo_total) AS ingreso_total, 
            SUM(v.puntos_venta) AS total_puntos, 
            SUM(ct.cantidad) AS productos_vendidos
        FROM ventas v
        JOIN usuarios u ON u.id = v.usuario
        JOIN JSON_TABLE (
            v.carrito,
            '$[*]' COLUMNS (
                cantidad INT PATH '$.cantidad'    
            )
        ) ct
        WHERE (u.id = usuario_id OR u.distribuidor = usuario_id)
            AND MONTH(fecha_venta) = MONTH(p_fecha)
            AND YEAR(fecha_venta) = YEAR(p_fecha);
    
    ELSEIF rol_usuario = 'vendedor' THEN
        SELECT
            MONTH(p_fecha) AS mes,
            SUM(v.costo_total) AS ingreso_total, 
            SUM(v.puntos_venta) AS total_puntos, 
            SUM(ct.cantidad) AS productos_vendidos
        FROM ventas v
        JOIN usuarios u ON u.id = v.usuario
        JOIN JSON_TABLE (
            v.carrito,
            '$[*]' COLUMNS (
                cantidad INT PATH '$.cantidad'    
            )
        ) ct
        WHERE (u.id = usuario_id OR u.vendedor = usuario_id)
            AND MONTH(fecha_venta) = MONTH(p_fecha)
            AND YEAR(fecha_venta) = YEAR(p_fecha);

    ELSEIF rol_usuario = 'promotor' THEN
        SELECT
            MONTH(p_fecha) AS mes,
            SUM(v.costo_total) AS ingreso_total, 
            SUM(v.puntos_venta) AS total_puntos, 
            SUM(ct.cantidad) AS productos_vendidos
        FROM ventas v
        JOIN JSON_TABLE (
            v.carrito,
            '$[*]' COLUMNS (
                cantidad INT PATH '$.cantidad'    
            )
        ) ct
        WHERE v.usuario = usuario_id
            AND MONTH(fecha_venta) = MONTH(p_fecha)
            AND YEAR(fecha_venta) = YEAR(p_fecha);
    END IF;

END $$
DELIMITER ;

-- SP para obtener reporte semestral por red x
DELIMITER $$
CREATE PROCEDURE obtener_red_reporte_semestral (
    IN p_fecha DATE,
    IN usuario_id INT
)
BEGIN
    DECLARE rol_usuario VARCHAR(15);

    SELECT rol INTO rol_usuario FROM usuarios WHERE id = usuario_id;

    IF rol_usuario = 'distribuidor' THEN
        SELECT
            MONTH(p_fecha) AS mes,
            SUM(v.costo_total) AS ingreso_total, 
            SUM(ct.cantidad) AS productos_vendidos
        FROM ventas v
        JOIN usuarios u ON u.id = v.usuario
        JOIN JSON_TABLE (
            v.carrito,
            '$[*]' COLUMNS (
                cantidad INT PATH '$.cantidad'    
            )
        ) ct
        WHERE (u.id = usuario_id OR u.distribuidor = usuario_id)
            AND FLOOR( ( MONTH(fecha_venta)-1) / 6 ) + 1 = FLOOR( ( MONTH(p_fecha)-1) / 6 ) + 1 
            AND YEAR(fecha_venta) = YEAR(p_fecha);
    
    ELSEIF rol_usuario = 'vendedor' THEN
        SELECT
            MONTH(p_fecha) AS mes,
            SUM(v.costo_total) AS ingreso_total, 
            SUM(ct.cantidad) AS productos_vendidos
        FROM ventas v
        JOIN usuarios u ON u.id = v.usuario
        JOIN JSON_TABLE (
            v.carrito,
            '$[*]' COLUMNS (
                cantidad INT PATH '$.cantidad'    
            )
        ) ct
        WHERE (u.id = usuario_id OR u.vendedor = usuario_id)
            AND FLOOR( ( MONTH(fecha_venta)-1) / 6 ) + 1 = FLOOR( ( MONTH(p_fecha)-1) / 6 ) + 1 
            AND YEAR(fecha_venta) = YEAR(p_fecha);

    ELSEIF rol_usuario = 'promotor' THEN
        SELECT
            MONTH(p_fecha) AS mes,
            SUM(v.costo_total) AS ingreso_total, 
            SUM(ct.cantidad) AS productos_vendidos
        FROM ventas v
        JOIN JSON_TABLE (
            v.carrito,
            '$[*]' COLUMNS (
                cantidad INT PATH '$.cantidad'    
            )
        ) ct
        WHERE v.usuario = usuario_id
            AND FLOOR( ( MONTH(fecha_venta)-1) / 6 ) + 1 = FLOOR( ( MONTH(p_fecha)-1) / 6 ) + 1 
            AND YEAR(fecha_venta) = YEAR(p_fecha);
    END IF;

END $$
DELIMITER ;

-- SP para modificar los datos de un producto x
DELIMITER $$
CREATE PROCEDURE modificar_producto_datos (
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

-- SP para modificar exclusivamente el inventario de un producto x 
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
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad no es válida.';
	END IF;
    
    COMMIT;
    
END $$
DELIMITER ;

-- SP para modificar la cantidad de productos en un carrito (carrito_producto) x
DELIMITER $$
CREATE PROCEDURE modificar_cantidad_producto_carrito (
    IN usuario_id INT,
    IN producto_sku VARCHAR(20),
    IN nueva_cantidad INT
)
BEGIN
    DECLARE carrito_id INT;
    DECLARE cantidad_actual INT DEFAULT 0;
    DECLARE cantidad_inventario_prod INT DEFAULT 0;

	START TRANSACTION;

    SELECT id INTO carrito_id 
    FROM carrito 
    WHERE usuario = usuario_id;

    SELECT cp.cantidad INTO cantidad_actual
    FROM carrito_producto cp
    WHERE cp.carrito = carrito_id AND cp.producto = producto_sku;

    SELECT cantidad_inventario INTO cantidad_inventario_prod
    FROM productos
    WHERE sku = producto_sku;

    IF nueva_cantidad > cantidad_inventario_prod THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No hay suficiente inventario.';
    ELSEIF nueva_cantidad < 0 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cantidad inválida';
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

-- SP para modificar la informacion de un cliente x
DELIMITER $$
CREATE PROCEDURE modificar_cliente (
    IN c_id INT,
    IN c_nombre VARCHAR(50),
    IN c_email VARCHAR(30),
    IN c_telefono VARCHAR(15),
    IN c_locacion VARCHAR(50),
    IN c_intereses VARCHAR(30)
)
BEGIN
    DECLARE cliente_exists INT;

    SELECT COUNT(*) INTO cliente_exists
    FROM clientes
    WHERE id = c_id;

    IF cliente_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no existe.';
    ELSE
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
    END IF;
END$$
DELIMITER ;

-- SP para modificar el usuario de un cliente x
DELIMITER $$
CREATE PROCEDURE modificar_cliente_usuario (
    IN c_id INT,	
    IN c_usuario INT
)
BEGIN
	DECLARE cliente_nombre VARCHAR(60);
	DECLARE usuario_actual INT;

	START TRANSACTION;

	SELECT nombre, usuario INTO cliente_nombre, usuario_actual FROM clientes WHERE id = c_id; 

	IF usuario_actual = c_usuario THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente ya está asignado a este usuario.';
    ELSE
        UPDATE clientes
        SET 
            usuario = c_usuario
        WHERE id = c_id;

        INSERT INTO historial (usuario, fecha, descripcion) 
        VALUES (usuario_actual, CURDATE(), CONCAT('El cliente ', cliente_nombre, ' fue desasignado del usuario.'));

        INSERT INTO historial (usuario, fecha, descripcion) 
        VALUES (c_usuario, CURDATE(), CONCAT('El cliente ', cliente_nombre, ' fue asignado al usuario.'));
    END IF;
    
    COMMIT;
END$$
DELIMITER ;

-- SP para modificar el vendedor de un usuario x
DELIMITER $$
CREATE PROCEDURE modificar_usuario_vendedor (
    IN usuario_id INT,
    IN nuevo_vendedor INT
)
BEGIN
    DECLARE vend_nombre VARCHAR(60);
    
    START TRANSACTION;

    IF nuevo_vendedor = usuario_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no puede ser su propio vendedor.';
    END IF;

    IF nuevo_vendedor IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = nuevo_vendedor AND rol = 'vendedor') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El vendedor especificado no existe.';
        END IF;
    END IF;

    IF nuevo_vendedor IS NOT NULL THEN
        SELECT nombre INTO vend_nombre
        FROM usuarios
        WHERE id = nuevo_vendedor;
    END IF;

    UPDATE usuarios
    SET vendedor = nuevo_vendedor
    WHERE id = usuario_id;

    IF nuevo_vendedor IS NOT NULL THEN
        INSERT INTO historial (usuario, fecha, descripcion) 
        VALUES (usuario_id, CURDATE(), CONCAT('El usuario cambió de vendedor a ', vend_nombre, '.'));
    END IF;

    COMMIT;

END$$
DELIMITER ;

-- SP para modificar el distribuidor de un usuario x
DELIMITER $$
CREATE PROCEDURE modificar_usuario_distribuidor (
    IN usuario_id INT,
    IN nuevo_distribuidor INT
)
BEGIN
    DECLARE dist_nombre VARCHAR(255);
    
    START TRANSACTION;

    IF nuevo_distribuidor = usuario_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no puede ser su propio distribuidor.';
    END IF;

    IF nuevo_distribuidor IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = nuevo_distribuidor AND rol = 'distribuidor') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El distribuidor especificado no existe.';
        END IF;
    END IF;

    IF nuevo_distribuidor IS NOT NULL THEN
        SELECT nombre INTO dist_nombre
        FROM usuarios
        WHERE id = nuevo_distribuidor;
    END IF;

    UPDATE usuarios
    SET distribuidor = nuevo_distribuidor
    WHERE id = usuario_id;

    IF nuevo_distribuidor IS NOT NULL THEN
        INSERT INTO historial (usuario, fecha, descripcion) 
        VALUES (usuario_id, CURDATE(), CONCAT('El usuario cambió de distribuidor a ', dist_nombre, '.'));
    END IF;

    COMMIT;

END$$
DELIMITER ;

-- SP para eliminar un producto x
DELIMITER $$
CREATE PROCEDURE eliminar_producto (
    IN producto_sku VARCHAR(20)
)
BEGIN
	START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM productos WHERE sku = producto_sku) THEN
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

-- SP para eliminar un producto de un carrito (carrito_producto) x
DELIMITER $$
CREATE PROCEDURE eliminar_producto_carrito (
    IN usuario_id INT,
    IN producto_sku VARCHAR(20)
)
BEGIN
	DECLARE carrito_id INT;

    START TRANSACTION;
    
    SELECT id INTO carrito_id FROM carrito WHERE usuario = usuario_id;
    
    DELETE FROM carrito_producto
    WHERE carrito = carrito_id AND producto = producto_sku;
    
    COMMIT;
END $$
DELIMITER ;

-- SP para eliminar un cliente x
DELIMITER $$
CREATE PROCEDURE eliminar_cliente (
    IN c_id INT
)
BEGIN
    DECLARE cliente_exists INT;
    DECLARE usuario_cliente INT;
  	DECLARE cliente_nombre VARCHAR(60);

	START TRANSACTION;

    SELECT COUNT(*)
    INTO cliente_exists
    FROM clientes
    WHERE id = c_id;

    IF cliente_exists > 0 THEN
    
        SELECT usuario, nombre INTO usuario_cliente, cliente_nombre FROM clientes WHERE id = c_id;
        
        INSERT INTO historial (usuario, fecha, descripcion) 
		VALUES (usuario_cliente, CURDATE(), CONCAT('El cliente ', cliente_nombre, ' fue eliminado.'));
    
        DELETE FROM clientes
        WHERE id = c_id;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no existe.';
    END IF;
    
    COMMIT;
END$$
DELIMITER ;

