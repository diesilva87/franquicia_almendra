create schema franquicia_almendra;
use franquicia_almendra;

-- ========================
-- CREACION DE TABLAS
-- ========================

create table categoria(
id_categoria int not null primary key auto_increment,
categoria varchar(100) not null,
descripcion varchar (1000)
);

create table producto (
id_producto int not null primary key auto_increment,
id_categoria int not null,
nombre varchar(100) not null,
sku varchar(100),
descripcion varchar(150),
constraint fk_productos_categoria
foreign key (id_categoria) references categoria(id_categoria)
);

create table costo(
id_producto int not null primary key,
costo_reposicion decimal(10,2) not null,
constraint fk_costo_producto
foreign key (id_producto) references producto(id_producto)
);

create table franja_horaria(
id_franja int not null primary key auto_increment,
hora time not null,
franja_horaria varchar (50) not null
);

create table precio(
id_producto int not null primary key,
id_categoria int not null,
nombre varchar(100),
precio_unit decimal(10,2) not null,
sku varchar(100),
descripcion varchar(150)
);

create table venta(
id_ticket int not null,
id_item_ticket int not null AUTO_INCREMENT primary key,
id_producto int not null,
fecha date not null,
hora time not null,
id_franja int not null,
cantidad decimal (10,0) not null,

constraint fk_ventas_producto
foreign key (id_producto) references producto (id_producto),
constraint fk_ventas_franja
foreign key (id_franja) references franja_horaria (id_franja)

);

CREATE TABLE stock (
  id_producto INT NOT NULL,
  cantidad_actual INT UNSIGNED NOT NULL,
  fecha_actualizacion DATETIME NOT NULL,
  PRIMARY KEY (id_producto)
);


CREATE TABLE movimiento_stock (
  id_movimiento INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  id_producto INT NOT NULL,
  fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  tipo_movimiento ENUM('INGRESO','EGRESO','AJUSTE') NOT NULL,
  cantidad DECIMAL(10,0) NOT NULL,
  descripcion VARCHAR(200),
  
  CONSTRAINT fk_movimiento_producto
    FOREIGN KEY (id_producto) REFERENCES producto(id_producto)
    ON UPDATE RESTRICT ON DELETE RESTRICT
);



--- VISTAS ---

--- VISTA 1 ---  ESTADO ACTUAL DEL STOCK
-- Muestra el estado actual del stock con datos del producto y su categoría, ordenado por cantidad (de menor a mayor).
-- Se puede ver rápidamente qué productos tienen menos stock y filtrar por categoria.

CREATE OR REPLACE VIEW vw_stock_actual_detalle AS
SELECT
  s.id_producto,
  p.nombre      AS producto,
  c.categoria   AS categoria,  
  s.cantidad_actual,
  s.fecha_actualizacion
FROM stock s
JOIN producto p        ON p.id_producto = s.id_producto
LEFT JOIN categoria c  ON c.id_categoria = p.id_categoria
ORDER BY s.cantidad_actual ASC;



--- VISTA 2 ---  MOVIMIENTOS RECIENTES
-- Lista los movimientos de stock de los últimos 15 días con detalle de producto y tipo de movimiento.

CREATE OR REPLACE VIEW vw_movimientos_recientes AS
SELECT
  ms.id_movimiento,
  ms.fecha,
  ms.tipo_movimiento,
  ms.cantidad,
  ms.descripcion,
  ms.id_producto,
  p.nombre      AS producto,
  c.categoria   AS categoria   -- o c.nombre
FROM movimiento_stock ms
JOIN producto p        ON p.id_producto = ms.id_producto
LEFT JOIN categoria c  ON c.id_categoria = p.id_categoria
WHERE ms.fecha >= NOW() - INTERVAL 15 DAY
ORDER BY ms.fecha DESC;





--- VISTA 3 ---  VENTAS POR FRANJAS HORARIAS
-- Permite ver las ventas por franjas horarias de una hora

CREATE OR REPLACE VIEW vw_ventas_por_franja AS
SELECT
    fh.franja_horaria,
    COUNT(DISTINCT v.id_ticket) AS tickets_emitidos,
    SUM(v.cantidad) AS total_unidades_vendidas
FROM venta v
JOIN franja_horaria fh ON fh.id_franja = v.id_franja
GROUP BY fh.franja_horaria
ORDER BY total_unidades_vendidas DESC;




--- VISTA 4 ---  Facturación y margen por franja horaria
-- Resumen en $ por franja (trae tickets, facturación, costo, margen y %)

CREATE OR REPLACE VIEW vw_facturacion_por_franja AS
SELECT
    fh.franja_horaria,
    COUNT(DISTINCT v.id_ticket)                                 AS tickets_emitidos,
        COALESCE(SUM(pr.precio_unit * v.cantidad), 0)               AS facturacion_bruta,
    COALESCE(SUM(co.costo_reposicion * v.cantidad), 0)          AS costo_total,
    COALESCE(SUM((pr.precio_unit - co.costo_reposicion) * v.cantidad), 0) AS contribucion_marginal,
    CASE
        WHEN COALESCE(SUM(pr.precio_unit * v.cantidad),0) > 0
        THEN ROUND(
            COALESCE(SUM((pr.precio_unit - co.costo_reposicion) * v.cantidad),0)
            / SUM(pr.precio_unit * v.cantidad) * 100, 2)
        ELSE NULL
    END AS margen_porcentual
FROM venta v
JOIN franja_horaria fh ON fh.id_franja = v.id_franja
JOIN precio pr          ON pr.id_producto = v.id_producto
JOIN costo  co          ON co.id_producto = v.id_producto
GROUP BY fh.franja_horaria
ORDER BY facturacion_bruta DESC;




--- VISTA 5 ---  Contribución marginal por categoría ----------------------------
-- Contribucion por categoria de productos

CREATE OR REPLACE VIEW vw_margen_por_categoria AS
SELECT
    c.categoria,
    COUNT(DISTINCT v.id_ticket)                                 AS tickets,
    COALESCE(SUM(v.cantidad), 0)                                AS unidades,
    COALESCE(SUM(pr.precio_unit * v.cantidad), 0)               AS facturacion_bruta,
    COALESCE(SUM(co.costo_reposicion * v.cantidad), 0)          AS costo_total,
    COALESCE(SUM((pr.precio_unit - co.costo_reposicion) * v.cantidad), 0)
                                                                AS contribucion_marginal,
    CASE
        WHEN COALESCE(SUM(pr.precio_unit * v.cantidad), 0) > 0 THEN
            ROUND(
                COALESCE(SUM((pr.precio_unit - co.costo_reposicion) * v.cantidad), 0)
                / SUM(pr.precio_unit * v.cantidad) * 100, 2
            )
        ELSE NULL
    END                                                         AS margen_porcentual
FROM venta v
JOIN producto p        ON p.id_producto = v.id_producto
LEFT JOIN categoria c  ON c.id_categoria = p.id_categoria
JOIN precio pr         ON pr.id_producto = v.id_producto
JOIN costo  co         ON co.id_producto = v.id_producto
GROUP BY c.categoria
ORDER BY contribucion_marginal DESC, facturacion_bruta DESC;




--- FUNCIONES ---

--- FUNCION 1 ---  CONTRIBUCION MARGINAL POR UNIDAD
-- Calcula la contribución marginal por unidad:
-- (precio_unitario − costo_unitario)

DELIMITER //

CREATE FUNCTION fn_contribucion_marginal(
    precio_unitario DECIMAL(10,2),
    costo_unitario DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    RETURN (precio_unitario - costo_unitario);
END;
//

DELIMITER ;



--- FUNCION 2 ---  CONTRIBUCION MARGINAL TOTAL
-- Calcula la contribución marginal total (por producto), multiplicando por las unidades vendidas.
-- (precio_unitario − costo_unitario) × cantidad

DELIMITER //

CREATE FUNCTION fn_margen_total_producto(
    precio_unitario DECIMAL(10,2),
    costo_unitario DECIMAL(10,2),
    cantidad DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    RETURN (precio_unitario - costo_unitario) * cantidad;
END;
//

DELIMITER ;




--- FUNCION 3 ---  % de contribucion marginal por producto
-- Devuelve el margen porcentual unitario de un producto ((precio - costo) / precio * 100).

DELIMITER //

CREATE FUNCTION fn_margen_por_producto(
    p_id_producto INT
)
RETURNS DECIMAL(6,2)
DETERMINISTIC
BEGIN
    DECLARE v_precio DECIMAL(10,2);
    DECLARE v_costo  DECIMAL(10,2);
    DECLARE v_margen DECIMAL(6,2);

    -- Obtener precio unitario y costo de reposición del producto
    SELECT pr.precio_unit, co.costo_reposicion
      INTO v_precio, v_costo
      FROM precio pr
      JOIN costo co ON co.id_producto = pr.id_producto
     WHERE pr.id_producto = p_id_producto;

    -- Evitar divisiones por cero o datos nulos
    IF v_precio IS NULL OR v_precio = 0 THEN
        RETURN NULL;
    END IF;

    SET v_margen = ROUND( (v_precio - v_costo) / v_precio * 100, 2 );

    RETURN v_margen;
END;
//

DELIMITER ;




--- STORED PROCEDURES ---

--- STORED PROCEDURES 1 --- sp_registrar_mov_stock
-- Cada vez que se ejecuta, se inserta un registro en movimiento_stock, y el trigger trg_actualizacion_stock se encarga de actualizar automáticamente la tabla stock --

DELIMITER //
CREATE PROCEDURE sp_registrar_mov_stock (
    IN p_id_producto INT,
    IN p_tipo_movimiento ENUM('INGRESO','EGRESO','AJUSTE'),
    IN p_cantidad DECIMAL(10,0),
    IN p_descripcion VARCHAR(200)
)
BEGIN
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'Cantidad inválida para movimiento de stock';
    END IF;

    INSERT INTO movimiento_stock (id_producto, fecha, tipo_movimiento, cantidad, descripcion)
    VALUES (p_id_producto, NOW(), p_tipo_movimiento, p_cantidad, p_descripcion);

    -- El trigger trg_actualizacion_stock actualiza automáticamente la tabla STOCK
END;
//
DELIMITER ;




--- STORED PROCEDURES 2 --- cont marginal por franja horaria
-- REsumen de ventas y margenes por franjas horarias

DELIMITER //

CREATE PROCEDURE sp_resumen_por_franja_simple(
    IN p_id_franja INT
)
BEGIN
    SELECT
        fh.id_franja,
        fh.franja_horaria,
        COUNT(DISTINCT v.id_ticket)                                      AS tickets,
        COALESCE(SUM(v.cantidad), 0)                                     AS unidades,
        COALESCE(SUM(pr.precio_unit * v.cantidad), 0)                    AS facturacion_bruta,
        COALESCE(SUM(co.costo_reposicion * v.cantidad), 0)               AS costo_total,
        COALESCE(SUM((pr.precio_unit - co.costo_reposicion) * v.cantidad), 0)
                                                                         AS contribucion_marginal,
        CASE
            WHEN COALESCE(SUM(pr.precio_unit * v.cantidad),0) > 0 THEN
                ROUND(
                    COALESCE(SUM((pr.precio_unit - co.costo_reposicion) * v.cantidad),0)
                    / SUM(pr.precio_unit * v.cantidad) * 100, 2
                )
            ELSE NULL
        END                                                               AS margen_porcentual
    FROM venta v
    JOIN franja_horaria fh ON fh.id_franja = v.id_franja
    JOIN precio pr         ON pr.id_producto = v.id_producto
    JOIN costo  co         ON co.id_producto = v.id_producto
    WHERE v.id_franja = p_id_franja;
END;
//
DELIMITER ;




--- TRIGGERS ---

--- TRIGGER 1 --- trg_venta_before_insert

-- Antes de insertar un nuevo ítem en venta, obtener el precio y costo vigentes del producto y guardarlos como snapshot en los campos precio_unitario y costo_unitario --

DELIMITER //
CREATE TRIGGER trg_venta_before_insert
BEFORE INSERT ON venta
FOR EACH ROW
BEGIN
    DECLARE v_precio DECIMAL(10,2);
    DECLARE v_costo  DECIMAL(10,2);

    SELECT precio_unit INTO v_precio
      FROM precio
     WHERE id_producto = NEW.id_producto
     LIMIT 1;

    SELECT costo_reposicion INTO v_costo
      FROM costo
     WHERE id_producto = NEW.id_producto
     LIMIT 1;

    IF v_precio IS NULL OR v_costo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El producto no tiene precio o costo definido';
    END IF;
END;
//
DELIMITER ;



--- TRIGGER 2 --- Evita stock negativo

-- Antes de agregar un movimiento de stock se valida que haya stock


DELIMITER //


CREATE TRIGGER trg_ms_before_insert
BEFORE INSERT ON movimiento_stock
FOR EACH ROW
BEGIN
    IF NEW.tipo_movimiento = 'EGRESO' THEN
        IF (SELECT COALESCE(cantidad_actual,0)
              FROM stock
             WHERE id_producto = NEW.id_producto) < NEW.cantidad THEN
            SIGNAL SQLSTATE '45000'
              SET MESSAGE_TEXT = 'Stock insuficiente';
        END IF;
    END IF;
END//


--- TRIGGER 3 --- Actualizacion de stock

-- Se actualiza el stock con los egresos e ingresos
 

CREATE TRIGGER trg_actualizacion_stock
AFTER INSERT ON movimiento_stock
FOR EACH ROW
BEGIN
    -- Si existe el producto en stock, ajusta; si no, lo crea según tipo
    IF EXISTS (SELECT 1 FROM stock WHERE id_producto = NEW.id_producto) THEN
        CASE NEW.tipo_movimiento
            WHEN 'INGRESO' THEN
                UPDATE stock
                   SET cantidad_actual   = cantidad_actual + NEW.cantidad,
                       fecha_actualizacion = NEW.fecha
                 WHERE id_producto = NEW.id_producto;
            WHEN 'EGRESO' THEN
                UPDATE stock
                   SET cantidad_actual   = cantidad_actual - NEW.cantidad,
                       fecha_actualizacion = NEW.fecha
                 WHERE id_producto = NEW.id_producto;
            WHEN 'AJUSTE' THEN
                UPDATE stock
                   SET cantidad_actual   = NEW.cantidad,
                       fecha_actualizacion = NEW.fecha
                 WHERE id_producto = NEW.id_producto;
        END CASE;
    ELSE
        CASE NEW.tipo_movimiento
            WHEN 'INGRESO' THEN
                INSERT INTO stock (id_producto, cantidad_actual, fecha_actualizacion)
                VALUES (NEW.id_producto, NEW.cantidad, NEW.fecha);
            WHEN 'EGRESO' THEN
                -- No debería ocurrir por la validación previa, pero por seguridad:
                SIGNAL SQLSTATE '45000'
                  SET MESSAGE_TEXT = 'No existe stock inicial para egreso';
            WHEN 'AJUSTE' THEN
                INSERT INTO stock (id_producto, cantidad_actual, fecha_actualizacion)
                VALUES (NEW.id_producto, NEW.cantidad, NEW.fecha);
        END CASE;
    END IF;
END//

DELIMITER ;



--- TRIGGER 4 --- Asignacion franja horaria de la venta

-- Asigna automáticamente la franja horaria correspondiente a una venta

DELIMITER //
CREATE TRIGGER tr_venta_set_id_franja
BEFORE INSERT ON venta
FOR EACH ROW
BEGIN
    DECLARE cat INT;
    SELECT id_franja INTO cat FROM franja_horaria WHERE hora = NEW.hora;
    SET NEW.id_franja = cat;
END//
DELIMITER ;


--- TRIGGER 5 --- tr_precio_set_categoria

-- Asigna automáticamente el precio del producto vendido

DELIMITER //
CREATE TRIGGER tr_precio_set_categoria
BEFORE INSERT ON precio
FOR EACH ROW
BEGIN
    DECLARE cat INT;
    SELECT id_categoria INTO cat FROM producto WHERE id_producto = NEW.id_producto;
    SET NEW.id_categoria = cat;
END//
DELIMITER ;


--- TRIGGER 6 --- tr_precio_set_nombre

-- Completa el nombre del producto vendido

DELIMITER //
CREATE TRIGGER tr_precio_set_nombre
BEFORE INSERT ON precio
FOR EACH ROW
BEGIN
    DECLARE cat varchar(100);
    SELECT nombre INTO cat FROM producto WHERE id_producto = NEW.id_producto;
    SET NEW.nombre = cat;
END//
DELIMITER ;


--- TRIGGER 7 --- tr_precio_set_sku

-- Completa el sku del producto vendido

DELIMITER //
CREATE TRIGGER tr_precio_set_sku
BEFORE INSERT ON precio
FOR EACH ROW
BEGIN
    DECLARE cat INT;
    SELECT sku INTO cat FROM producto WHERE id_producto = NEW.id_producto;
    SET NEW.sku = cat;
END//
DELIMITER ;


--- TRIGGER 8 --- tr_precio_set_descripcion

-- Completa la descripcion del producto vendido

DELIMITER //
CREATE TRIGGER tr_precio_set_descripcion
BEFORE INSERT ON precio
FOR EACH ROW
BEGIN
    DECLARE cat varchar(150);
    SELECT descripcion INTO cat FROM producto WHERE id_producto = NEW.id_producto;
    SET NEW.descripcion = cat;
END//
DELIMITER ;