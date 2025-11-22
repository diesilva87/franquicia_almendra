use franquicia_almendra;

-- TRANSACCIÓN 1: Venta + salida de stock (operación completa)

-- Registra una venta y descuenta el stock usando el SP sp_registrar_mov_stock.
-- Si algo falla, se revierte todo.

START TRANSACTION;

    -- 1) Insertar la venta (la franja horaria se completa con el trigger tr_venta_set_id_franja)
    INSERT INTO venta (id_ticket, id_producto, fecha, hora, cantidad)
    VALUES (10001, 5, CURDATE(), '09:00:00', 3);

    -- 2) Registrar el egreso de stock asociado a la venta
    CALL sp_registrar_mov_stock(
        5,                     -- p_id_producto
        'EGRESO',              -- p_tipo_movimiento
        3,                     -- p_cantidad
        'Venta ticket 10001'   -- p_descripcion
    );

COMMIT;


-- TRANSACCIÓN 2: Ingreso de mercadería (reposiciones)

-- Usa el mismo SP de movimientos de stock para registrar un ingreso.
-- La tabla STOCK se actualiza con el trigger trg_actualizacion_stock.

START TRANSACTION;

    CALL sp_registrar_mov_stock(
        12,                               -- p_id_producto
        'INGRESO',                        -- p_tipo_movimiento
        50,                               -- p_cantidad
        'Reposición de mercadería prov X' -- p_descripcion
    );

COMMIT;


-- TRANSACCIÓN 3: Actualización masiva de precios por categoría

-- Aplica aumentos por categoría dentro de una única transacción.
-- Si alguna actualización falla, se revierte todo.

SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

    -- Aumenta 10% los productos de la categoría 1
    UPDATE precio
       SET precio_unit = precio_unit * 1.10
     WHERE id_categoria = 1;

    -- Aumenta 5% los productos de la categoría 2
    UPDATE precio
       SET precio_unit = precio_unit * 1.05
     WHERE id_categoria = 2;

    -- Aumenta 15% los productos de la categoría 3
    UPDATE precio
       SET precio_unit = precio_unit * 1.15
     WHERE id_categoria = 3;

COMMIT;