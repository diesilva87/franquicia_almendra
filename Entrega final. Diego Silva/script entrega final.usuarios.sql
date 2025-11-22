-- ========================
-- CREACION DE USUARIOS
-- ========================

-- USUARIO 1: SOLO VISUALIZACION

CREATE USER 'usuario_visualiza'@'%' IDENTIFIED BY 'Visualiza123';

GRANT SELECT ON franquicia_almendra.* TO 'usuario_visualiza'@'%';

FLUSH PRIVILEGES;


-- USUARIO 2: OPERACIONES

CREATE USER 'usuario_operaciones'@'%' IDENTIFIED BY 'Operaciones123';

-- Permisos sobre stock
GRANT SELECT, INSERT, UPDATE ON franquicia_almendra.stock TO 'usuario_operaciones'@'%';

-- Permisos sobre movimientos de stock
GRANT SELECT, INSERT ON franquicia_almendra.movimiento_stock TO 'usuario_operaciones'@'%';

-- Permiso para precios
GRANT SELECT, UPDATE ON franquicia_almendra.precio TO 'usuario_operaciones'@'%';

-- Permitir usar SP para registrar movimientos
GRANT EXECUTE ON PROCEDURE franquicia_almendra.sp_registrar_mov_stock TO 'usuario_operaciones'@'%';

FLUSH PRIVILEGES;