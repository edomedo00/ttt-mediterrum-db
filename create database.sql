CREATE DATABASE IF NOT EXISTS mediterrum;
USE mediterrum;

CREATE TABLE usuarios (
	id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(60) NOT NULL, 
    email VARCHAR(50) NOT NULL, 
    telefono VARCHAR(15) NOT NULL, 
    locacion VARCHAR(50),
    rol ENUM('promotor', 'vendedor', 'distribuidor', 'administrador') NOT NULL,
    puntos_total INT,
    nivel ENUM('N1 Plata', 'N2 Oro', 'N3 Platino', 'N4 Zafiro', 'N5 Esmeralda', 'N6 Diamante'), 
    distribuidor INT, 
    vendedor INT,
    contrasena VARCHAR(20),
	CONSTRAINT u_unique_email UNIQUE (email),               
    CONSTRAINT u_unique_telefono UNIQUE (telefono)
);

ALTER TABLE usuarios
ADD CONSTRAINT fk_vendedor_de_usuario FOREIGN KEY (vendedor) REFERENCES usuarios(id),
ADD CONSTRAINT fk_distribuidor_de_usuario FOREIGN KEY (distribuidor) REFERENCES usuarios(id);

CREATE TABLE carrito (
    id INT PRIMARY KEY AUTO_INCREMENT,
    usuario INT,
    CONSTRAINT fk_carrito_usuario FOREIGN KEY (usuario) REFERENCES usuarios(id)
);

CREATE TABLE historial (
	id INT AUTO_INCREMENT PRIMARY KEY,
	usuario INT NOT NULL, 
    fecha DATE NOT NULL, 
    descripcion VARCHAR(100),
    CONSTRAINT fk_usuario_historial FOREIGN KEY (usuario) REFERENCES usuarios(id)
);

CREATE TABLE productos (
    sku VARCHAR(20) PRIMARY KEY,
    nombre_producto VARCHAR(30) NOT NULL, 
    costo_total INT NOT NULL, 
    costo_no_iva INT NOT NULL, 
    img VARCHAR(100), 
    descripcion VARCHAR(150), 
    descuento INT, 
    puntos_producto INT,
    cantidad_inventario INT NOT NULL
);

CREATE TABLE carrito_producto (
    carrito INT,
    producto VARCHAR(20),
    cantidad INT NOT NULL,
    PRIMARY KEY (carrito, producto),
    CONSTRAINT fk_carprod_carrito FOREIGN KEY (carrito) REFERENCES carrito(id),
    CONSTRAINT fk_carprod_producto FOREIGN KEY (producto) REFERENCES productos(sku)
);

CREATE TABLE ventas (
	id INT AUTO_INCREMENT PRIMARY KEY, 
    usuario INT NOT NULL, 
    carrito JSON, 
	costo_total FLOAT,
    fecha_venta DATE NOT NULL, 
    fecha_entrega DATE NOT NULL, 
    lugar_entrega VARCHAR(100) NOT NULL, 
    puntos_venta INT NOT NULL,
    CONSTRAINT fk_usuario_ventas FOREIGN KEY (usuario) REFERENCES usuarios(id)
);

CREATE TABLE clientes (
	id  INT AUTO_INCREMENT PRIMARY KEY, 
    usuario INT,
    nombre VARCHAR(60) NOT NULL, 
    email VARCHAR(30) NOT NULL, 
    telefono VARCHAR(15), 
    locacion VARCHAR(50),
    intereses VARCHAR(50),
   	CONSTRAINT c_unique_email UNIQUE (email),               
    CONSTRAINT c_unique_telefono UNIQUE (telefono),
    CONSTRAINT fk_usuario_clientes FOREIGN KEY (usuario) REFERENCES usuarios(id)
);

CREATE TABLE comisiones (
    rol ENUM('vendedor', 'promotor', 'base', 'eventos', 'premios', 'distribuidor N1', 'distribuidor N2', 'distribuidor N3', 'distribuidor N4', 'distribuidor N5', 'distribuidor DD') NOT NULL,
    porcentaje DECIMAL(4,1) NOT NULL
);

INSERT INTO comisiones (rol, porcentaje) VALUES
('base', 50.0),
('eventos', 5.0),
('premios', 5.0),
('promotor', 5.0),
('vendedor', 15.0),
('distribuidor N1', 4.0),
('distribuidor N2', 3.0),
('distribuidor N3', 3.0),
('distribuidor N4', 3.0),
('distribuidor N5', 3.0),
('distribuidor DD', 4.0);
-- comision 'bolsa' se calcula (20 - porcentaje de distribuidor)




