-- 1. Modificar la tabla para registrar la auditoría completa
ALTER TABLE historial_transferencias 
ADD COLUMN usuario_responsable VARCHAR(50);

-- 2. Eliminar versión anterior si existe
DROP PROCEDURE IF EXISTS TransferirFondos;

-- 3. Crear el procedimiento con las mejoras
DELIMITER //

CREATE PROCEDURE TransferirFondos (
    IN p_origen INT,
    IN p_destino INT,
    IN p_monto DECIMAL(10,2),
    OUT p_codigo_respuesta INT,
    OUT p_titular_origen VARCHAR(100)
)
BEGIN
    DECLARE v_saldo_origen DECIMAL(10,2);

    -- Manejo de errores de base de datos
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_codigo_respuesta = 500;
    END;

    -- Validación previa: Monto válido (Desafío Extra)
    IF p_monto <= 0 THEN
        SET p_codigo_respuesta = 401;
    ELSE
        -- Inicio de la transacción
        START TRANSACTION;

        -- Bloqueo pesimista y lectura de saldo y titular
        SELECT saldo, titular 
        INTO v_saldo_origen, p_titular_origen
        FROM cuentas
        WHERE id_cuenta = p_origen
        FOR UPDATE;

        -- Validación de fondos
        IF v_saldo_origen >= p_monto THEN
            -- Débito cuenta origen
            UPDATE cuentas
            SET saldo = saldo - p_monto
            WHERE id_cuenta = p_origen;

            -- Crédito cuenta destino
            UPDATE cuentas
            SET saldo = saldo + p_monto
            WHERE id_cuenta = p_destino;

            -- Registro en auditoría con el usuario responsable
            INSERT INTO historial_transferencias (cuenta_origen, cuenta_destino, monto, usuario_responsable)
            VALUES (p_origen, p_destino, p_monto, USER());

            COMMIT;
            SET p_codigo_respuesta = 200;
        ELSE
            ROLLBACK;
            SET p_codigo_respuesta = 400;
        END IF;
    END IF;
END //

DELIMITER ;

-- Caso 1: Transferencia exitosa (código 200)
CALL TransferirFondos(1, 2, 1000, @codigo, @titular);
SELECT @codigo AS Codigo, @titular AS TitularOrigen;
SELECT * FROM cuentas;
SELECT * FROM historial_transferencias;

-- Caso 2: Saldo insuficiente (código 400)
CALL TransferirFondos(1, 2, 10000, @codigo, @titular);
SELECT @codigo AS Codigo, @titular AS TitularOrigen;

-- Caso 3: Monto inválido (Desafío Extra - código 401)
CALL TransferirFondos(1, 2, -50, @codigo, @titular);
SELECT @codigo AS Codigo, @titular AS TitularOrigen;