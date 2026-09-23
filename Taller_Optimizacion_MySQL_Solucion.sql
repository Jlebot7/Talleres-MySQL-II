-- ==============================================================================
-- TALLER PRÁCTICO: OPTIMIZACIÓN DE CONSULTAS Y RENDIMIENTO EN MYSQL (BancoDB)
-- SOLUCIÓN COMPLETA Y DIAGNÓSTICO DETALLADO
-- ==============================================================================
-- Objetivo: Que los estudiantes diagnostiquen consultas lentas usando EXPLAIN ANALYZE,
-- identifiquen lecturas completas de tabla (Table Scans), reescriban consultas
-- de forma sargable y apliquen índices compuestos y cubrientes sobre la base de datos bancaria.
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS BancoDB;
USE BancoDB;

-- ------------------------------------------------------------------------------
-- PARTE 0: ESTRUCTURA DE TABLAS E POBLAMIENTO DE DATOS MASIVOS
-- ------------------------------------------------------------------------------

DROP TABLE IF EXISTS historial_transferencias;
DROP TABLE IF EXISTS cuentas;

CREATE TABLE cuentas (
    id_cuenta INT PRIMARY KEY AUTO_INCREMENT,
    titular VARCHAR(100) NOT NULL,
    tipo_cuenta VARCHAR(20) NOT NULL DEFAULT 'Ahorros',
    saldo DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    estado VARCHAR(20) NOT NULL DEFAULT 'Activa',
    fecha_apertura DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE historial_transferencias (
    id_transferencia INT AUTO_INCREMENT PRIMARY KEY,
    cuenta_origen INT NOT NULL,
    cuenta_destino INT NOT NULL,
    monto DECIMAL(12, 2) NOT NULL,
    estado_transferencia VARCHAR(20) NOT NULL DEFAULT 'Exitosa',
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (cuenta_origen) REFERENCES cuentas(id_cuenta),
    FOREIGN KEY (cuenta_destino) REFERENCES cuentas(id_cuenta)
);

-- Procedimiento auxiliar para generar un volumen masivo de prueba
DELIMITER //
CREATE PROCEDURE CargarDatosPrueba()
BEGIN
    DECLARE i INT DEFAULT 1;
    
    -- Insertar 1,000 cuentas
    WHILE i <= 1000 DO
        INSERT INTO cuentas (titular, tipo_cuenta, saldo, estado, fecha_apertura)
        VALUES (
            CONCAT('Cliente_', i),
            IF(i % 2 = 0, 'Ahorros', 'Corriente'),
            ROUND(RAND() * 10000000, 2),
            IF(i % 10 = 0, 'Bloqueada', 'Activa'),
            DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * 365) DAY)
        );
        SET i = i + 1;
    END WHILE;

    -- Insertar 10,000 transferencias
    SET i = 1;
    WHILE i <= 1000 DO
        -- Inserciones en bloques para optimizar velocidad si es necesario
        SET i = i;
    END WHILE;

    SET i = 1;
    WHILE i <= 10000 DO
        INSERT INTO historial_transferencias (cuenta_origen, cuenta_destino, monto, estado_transferencia, fecha)
        VALUES (
            FLOOR(1 + RAND() * 999),
            FLOOR(1 + RAND() * 999),
            ROUND(1000 + RAND() * 500000, 2),
            IF(i % 15 = 0, 'Fallida', 'Exitosa'),
            DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * 180) DAY)
        );
        SET i = i + 1;
    END WHILE;
END //
DELIMITER ;

-- Ejecutar la carga masiva
CALL CargarDatosPrueba();
DROP PROCEDURE IF EXISTS CargarDatosPrueba;


-- ==============================================================================
-- PARTE 1: DEMOSTRACIÓN GUIADA EN CLASE (PROFESOR)
-- ==============================================================================

-- PROBLEMA: Búsqueda de transferencias por estado y rango de fechas sin índice secundario.
-- Analizar el costo de ejecución antes de optimizar:
EXPLAIN ANALYZE
SELECT id_transferencia, cuenta_origen, monto, fecha
FROM historial_transferencias
WHERE estado_transferencia = 'Exitosa'
  AND fecha >= '2026-01-01 00:00:00';

-- DIAGNÓSTICO:
-- Salida típica: Table scan on historial_transferencias (costo elevado, examina las 10,000 filas).

-- SOLUCIÓN DEMOSTRATIVA: Crear índice compuesto ordenado por discriminación (Igualdad -> Rango).
CREATE INDEX idx_transf_estado_fecha ON historial_transferencias(estado_transferencia, fecha);

-- RE-EVALUACIÓN:
EXPLAIN ANALYZE
SELECT id_transferencia, cuenta_origen, monto, fecha
FROM historial_transferencias
WHERE estado_transferencia = 'Exitosa'
  AND fecha >= '2026-01-01 00:00:00';
-- Diagnóstico posterior: Utiliza 'Index range scan' sobre idx_transf_estado_fecha, reduciendo filas leídas.


-- ==============================================================================
-- PARTE 2: EJERCICIOS PRÁCTICOS PARA LOS ESTUDIANTES (SOLUCIONADOS)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- EJERCICIO 1: Diagnóstico de "Non-Sargable Query" (Uso de Funciones en WHERE)
-- ------------------------------------------------------------------------------
-- ENUNCIADO: El sistema ejecuta la siguiente consulta para obtener las transferencias
-- realizadas en un día específico. El desarrollador anterior aplicó la función DATE() 
-- sobre la columna 'fecha'.
-- 
-- BASE INEFICIENTE (A ejecutar y analizar):
EXPLAIN ANALYZE
SELECT * 
FROM historial_transferencias 
WHERE DATE(fecha) = '2026-02-15';

/*
================================================================================
RESPUESTAS Y SOLUCIÓN DEL EJERCICIO 1:
================================================================================
1. ¿Por qué el índice 'idx_transf_estado_fecha' NO es utilizado por MySQL?
   a) Violación de la regla del prefijo más a la izquierda (Leftmost Prefix Rule):
      El índice compuesto está definido como (estado_transferencia, fecha). La consulta
      únicamente filtra por 'fecha' sin incluir 'estado_transferencia'. El árbol B-Tree
      está ordenado en primer nivel por estado; sin conocer el estado, el motor no puede
      saltar directamente a las ramas de fecha.
   b) Pérdida de SARGabilidad (Search Argument Able):
      Al envolver la columna en la función escalar DATE(fecha), MySQL desconoce a priori
      el valor resultante sin ejecutar la función fila por fila en tiempo de ejecución.
      Como el índice contiene valores DATETIME puros (ej. '2026-02-15 10:25:00'), el
      motor no puede hacer un Index Seek ni una búsqueda por rango B-Tree directa. Esto
      fuerza un Full Table Scan (lectura secuencial de las 10,000 filas).

2. Reescritura Sargable:
   Se despeja la columna indexada en el WHERE expresándola como un rango cerrado-abierto
   [inicio_dia, fin_dia). De este modo, la columna 'fecha' no sufre transformaciones
   y puede ser evaluada directamente contra los nodos del índice.
*/

-- Para aprovechar al máximo búsquedas por fecha sola, creamos un índice sobre 'fecha':
CREATE INDEX idx_transf_fecha ON historial_transferencias(fecha);

-- CONSULTA OPTIMIZADA (SARGABLE):
EXPLAIN ANALYZE
SELECT * 
FROM historial_transferencias 
WHERE fecha >= '2026-02-15 00:00:00' 
  AND fecha <  '2026-02-16 00:00:00';

/*
3. Comparación de Planes de Ejecución (EXPLAIN ANALYZE):
   - Consulta Ineficiente:
     Plan: -> Filter: (date(historial_transferencias.fecha) = '2026-02-15')
             -> Table scan on historial_transferencias (cost=~1025, rows=10000)
     Comportamiento: Examina 10,000 registros evaluando la función DATE() 10,000 veces.
   - Consulta Sargable con idx_transf_fecha:
     Plan: -> Index range scan on historial_transferencias using idx_transf_fecha 
              over ('2026-02-15 00:00:00' <= fecha < '2026-02-16 00:00:00') (cost=~20-50, rows=~55)
     Comportamiento: Salta directo al rango del día solicitado en el B-Tree, leyendo únicamente
     las ~55 transferencias de esa fecha. Reducción de I/O y CPU superior al 98%.
*/


-- ------------------------------------------------------------------------------
-- EJERCICIO 2: Optimización mediante Índices Cubrientes (Covering Index)
-- ------------------------------------------------------------------------------
-- ENUNCIADO: La aplicación consulta frecuentemente el saldo y tipo de cuenta de clientes activos
-- para validar autorizaciones rápidas.
--
-- BASE INEFICIENTE:
EXPLAIN ANALYZE
SELECT titular, saldo, tipo_cuenta
FROM cuentas
WHERE estado = 'Activa';

/*
================================================================================
RESPUESTAS Y SOLUCIÓN DEL EJERCICIO 2:
================================================================================
1. Impacto de SELECT * vs seleccionar solo campos necesarios:
   - Con SELECT *: Se piden todas las columnas de la tabla (incluyendo fecha_apertura).
     Aunque exista un índice sobre 'estado', por cada fila que coincida con 'Activa' 
     (que representa ~90% de la tabla según la semilla), el motor tendría que hacer un
     "Key Lookup" / salto aleatorio a la tabla base (clustered index en InnoDB) para traer
     el resto de los datos. Como hacer 900 lookups aleatorios es más costoso que leer las
     páginas de la tabla secuencialmente, el optimizador DESCARTA el índice secundario
     y ejecuta un Full Table Scan.
   - Con campos específicos (titular, saldo, tipo_cuenta): Permite diseñar un
     "Covering Index" (Índice Cubriente). Si todas las columnas del WHERE y del SELECT
     están contenidas dentro de las hojas del índice, el motor NO necesita tocar la tabla
     base, resolviendo la consulta al 100% desde la memoria del índice.

2. Diseño del Índice Cubriente:
   - Columna 1 (Filtro WHERE): 'estado' (para navegar el B-Tree hasta 'Activa').
   - Columnas 2, 3 y 4 (Payload SELECT): 'tipo_cuenta', 'saldo', 'titular'.
*/

-- CREACIÓN DEL ÍNDICE CUBRIENTE:
CREATE INDEX idx_cuentas_estado_cubriente 
ON cuentas(estado, tipo_cuenta, saldo, titular);

-- CONSULTA OPTIMIZADA:
EXPLAIN ANALYZE
SELECT titular, saldo, tipo_cuenta
FROM cuentas
WHERE estado = 'Activa';

/*
3. Verificación con EXPLAIN ANALYZE:
   - Salida del optimizador:
     -> Covering index range scan on cuentas using idx_cuentas_estado_cubriente over (estado = 'Activa')
     (En EXPLAIN tradicional: columna Extra muestra "Using index").
   - Beneficio: Cero lecturas a las páginas de datos de la tabla 'cuentas'. Todo el conjunto
     de resultados se extrae directamente de las páginas del índice B-Tree, disminuyendo
     drásticamente el buffer pool I/O y el tiempo de respuesta.
*/


-- ------------------------------------------------------------------------------
-- EJERCICIO 3: Optimización de Filtros Combinados y JOINs
-- ------------------------------------------------------------------------------
-- ENUNCIADO: Se requiere generar un reporte de los clientes con cuentas activas que hayan realizado
-- transferencias superiores a $300,000 en los últimos 30 días.
--
-- BASE INEFICIENTE:
EXPLAIN ANALYZE
SELECT c.id_cuenta, c.titular, ht.id_transferencia, ht.monto, ht.fecha
FROM cuentas c
JOIN historial_transferencias ht ON c.id_cuenta = ht.cuenta_origen
WHERE c.estado = 'Activa'
  AND ht.monto > 300000.00;

/*
================================================================================
RESPUESTAS Y SOLUCIÓN DEL EJERCICIO 3:
================================================================================
1. Identificación de Tabla Escaneada por Completo (Full Table Scan):
   Al ejecutar EXPLAIN ANALYZE sobre la base ineficiente:
   - La tabla 'historial_transferencias' sufre un FULL TABLE SCAN:
     "-> Table scan on ht (cost=... rows=10000)"
     El motor debe recorrer las 10,000 filas de transferencias comprobando el filtro 'monto > 300000'.
   - O bien, si 'cuentas' es la driving table, se produce "Table scan on c" (1,000 filas)
     porque no hay índice en 'estado'. Y por cada cuenta, hace lookup en historial_transferencias
     filtrando en caliente por monto sin índice.

2. Diseño de Índices Necesarios:
   Para que el optimizador tenga la mejor ruta de acceso posible, creamos:
   a) En 'historial_transferencias': Un índice compuesto sobre (cuenta_origen, monto, fecha)
      o sobre (monto, cuenta_origen, fecha).
      Dado que el JOIN se realiza por (c.id_cuenta = ht.cuenta_origen) y el filtro es (monto > 300000),
      crear el índice (cuenta_origen, monto, fecha) permite conectar eficientemente las cuentas activas
      y filtrar simultáneamente por rango de monto. Además, es CUBRIENTE para ht porque contiene
      id_transferencia (implícito por PK InnoDB), cuenta_origen, monto y fecha.
   b) En 'cuentas': Un índice compuesto sobre (estado, id_cuenta, titular).
      Permite encontrar inmediatamente las cuentas donde estado = 'Activa' sin escanear las
      cuentas bloqueadas y sin hacer bookmark lookup hacia la tabla base.
*/

-- CREACIÓN DE ÍNDICES OPTIMIZADOS:
CREATE INDEX idx_cuentas_estado_id_titular 
ON cuentas(estado, id_cuenta, titular);

CREATE INDEX idx_ht_origen_monto_fecha 
ON historial_transferencias(cuenta_origen, monto, fecha);

-- RE-EVALUACIÓN CON EXPLAIN ANALYZE:
EXPLAIN ANALYZE
SELECT c.id_cuenta, c.titular, ht.id_transferencia, ht.monto, ht.fecha
FROM cuentas c
JOIN historial_transferencias ht ON c.id_cuenta = ht.cuenta_origen
WHERE c.estado = 'Activa'
  AND ht.monto > 300000.00;

/*
3. Justificación del Orden de las Columnas en los Índices:
   Se aplica la regla fundamental de indexación B-Tree:
   [COLUMNAS DE IGUALDAD (=)] -> [COLUMNAS DE RANGO (<, >, BETWEEN)] -> [COLUMNAS CUBRIENTES]

   - Para 'idx_cuentas_estado_id_titular' en tabla cuentas:
     1. 'estado' (Igualdad): Permite posicionarse directamente en el bloque 'Activa'.
     2. 'id_cuenta' y 'titular' (Cubrientes): Proporcionan la llave de unión para el JOIN
        y el dato del cliente sin ir a buscar la fila en disco.

   - Para 'idx_ht_origen_monto_fecha' en tabla historial_transferencias:
     1. 'cuenta_origen' (Igualdad en el JOIN): El JOIN busca 'ht.cuenta_origen = c.id_cuenta'.
        Al estar de primera, por cada cuenta activa encontrada, MySQL salta directamente a sus
        transferencias exactas en el B-Tree.
     2. 'monto' (Rango): Al estar después de la igualdad, MySQL puede aplicar el rango
        'monto > 300000.00' directamente sobre las ramas del índice de esa cuenta, descartando
        transferencias de menor monto sin evaluarlas en CPU.
     3. 'fecha' (Cubriente): Permite proyectar la columna 'fecha' directamente desde el índice,
        evitando cualquier lectura a la tabla física historial_transferencias.
*/

-- ==============================================================================
-- FIN DEL TALLER Y COMPROBACIÓN FINAL
-- ==============================================================================
-- Mostrar todos los índices creados en las tablas:
SHOW INDEX FROM cuentas;
SHOW INDEX FROM historial_transferencias;
