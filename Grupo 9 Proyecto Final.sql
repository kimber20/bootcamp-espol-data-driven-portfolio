DROP DATABASE IF EXISTS transporte_urbano;
CREATE DATABASE transporte_urbano;
USE transporte_urbano;

CREATE TABLE ruta (
  id_ruta   INT PRIMARY KEY AUTO_INCREMENT,
  codigo    VARCHAR(20) NOT NULL,
  nombre    VARCHAR(120) NOT NULL,
  sentido   ENUM('ida','vuelta','circular') NOT NULL DEFAULT 'ida',
  UNIQUE (codigo)
);

CREATE TABLE parada (
  id_parada INT PRIMARY KEY AUTO_INCREMENT,
  codigo    VARCHAR(20) NOT NULL,
  nombre    VARCHAR(120) NOT NULL,
  zona      VARCHAR(50) NULL,
  UNIQUE (codigo)
);

CREATE TABLE ruta_parada (
  id_ruta   INT NOT NULL,
  id_parada INT NOT NULL,
  orden     INT NOT NULL,
  PRIMARY KEY (id_ruta, id_parada),
  FOREIGN KEY (id_ruta)
    REFERENCES ruta(id_ruta)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  FOREIGN KEY (id_parada)
    REFERENCES parada(id_parada)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  UNIQUE (id_ruta, orden),
  CONSTRAINT ck_rp_orden_pos CHECK (orden >= 1)
);

CREATE TABLE calendario_servicio (
  id_servicio INT PRIMARY KEY AUTO_INCREMENT,
  fecha_ini   DATE NOT NULL,
  fecha_fin   DATE NOT NULL,
  lun CHAR(1) NOT NULL DEFAULT '1',
  mar CHAR(1) NOT NULL DEFAULT '1',
  mie CHAR(1) NOT NULL DEFAULT '1',
  jue CHAR(1) NOT NULL DEFAULT '1',
  vie CHAR(1) NOT NULL DEFAULT '1',
  sab CHAR(1) NOT NULL DEFAULT '1',
  dom CHAR(1) NOT NULL DEFAULT '1',
  CHECK (fecha_ini <= fecha_fin),
  CONSTRAINT ck_cal_flags
    CHECK (lun IN ('0','1') AND mar IN ('0','1') AND mie IN ('0','1')
       AND jue IN ('0','1') AND vie IN ('0','1') AND sab IN ('0','1') AND dom IN ('0','1'))
);

CREATE TABLE viaje (
  id_viaje    BIGINT PRIMARY KEY AUTO_INCREMENT,
  id_ruta     INT NOT NULL,
  id_servicio INT NOT NULL,
  hora_salida_programada TIME NOT NULL,
  frecuencia_min INT NULL,
  FOREIGN KEY (id_ruta)
    REFERENCES ruta(id_ruta)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  FOREIGN KEY (id_servicio)
    REFERENCES calendario_servicio(id_servicio)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT ck_viaje_freq_nonneg CHECK (frecuencia_min IS NULL OR frecuencia_min >= 0),
  UNIQUE KEY uq_viaje_ruta_servicio_hora (id_ruta, id_servicio, hora_salida_programada)
);

CREATE TABLE viaje_parada (
  id_viaje  BIGINT NOT NULL,
  id_ruta   INT NOT NULL,
  id_parada INT NOT NULL,
  secuencia INT NOT NULL,
  hora_llegada_programada TIME NOT NULL,
  hora_salida_programada  TIME NOT NULL,
  PRIMARY KEY (id_viaje, id_parada),
  FOREIGN KEY (id_viaje)
    REFERENCES viaje(id_viaje)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  FOREIGN KEY (id_ruta, id_parada)
    REFERENCES ruta_parada(id_ruta, id_parada)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT ck_vp_tiempo_logico CHECK (hora_llegada_programada <= hora_salida_programada)
);

CREATE TABLE usuario (
  id_usuario   BIGINT PRIMARY KEY AUTO_INCREMENT,
  sexo         ENUM('M','F','X') NULL,
  tipo_usuario ENUM('general','estudiante','mayor','discapacidad') DEFAULT 'general'
);

CREATE TABLE abordaje (
  id_abordaje   BIGINT PRIMARY KEY AUTO_INCREMENT,
  id_viaje      BIGINT NOT NULL,
  id_parada     INT NOT NULL,
  id_usuario    BIGINT NOT NULL, -- NOT NULL según observación
  ts_evento     DATETIME NOT NULL,
  direccion     ENUM('sube','baja') NOT NULL,
  tarifa_pagada DECIMAL(6,2) NOT NULL,
  FOREIGN KEY (id_viaje)
    REFERENCES viaje(id_viaje)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  FOREIGN KEY (id_parada)
    REFERENCES parada(id_parada)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  -- Mantener historia: no cascadiar borrado de usuarios
  CONSTRAINT fk_abordaje_usuario
    FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT ck_abordaje_tarifa_nonneg CHECK (tarifa_pagada >= 0)
);

CREATE TABLE costo_operacion (
  id_costo BIGINT PRIMARY KEY AUTO_INCREMENT,
  id_ruta INT NOT NULL,
  fecha DATE NOT NULL,
  UNIQUE (id_ruta, fecha),
  FOREIGN KEY (id_ruta) REFERENCES ruta(id_ruta) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE detalle_costo (
  id_detalle BIGINT PRIMARY KEY AUTO_INCREMENT,
  id_costo BIGINT NOT NULL,
  tipo_costo ENUM('combustible', 'mantenimiento', 'personal', 'otros') NOT NULL,
  monto DECIMAL(10,2) NOT NULL,
  FOREIGN KEY (id_costo) REFERENCES costo_operacion(id_costo) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_costo_no_negativo CHECK (monto >= 0),
  CONSTRAINT uq_costo_tipo UNIQUE (id_costo, tipo_costo)
);

CREATE INDEX idx_ruta_parada_idruta    ON ruta_parada(id_ruta);
CREATE INDEX idx_ruta_parada_idparada  ON ruta_parada(id_parada);

CREATE INDEX idx_viaje_idruta          ON viaje(id_ruta);
CREATE INDEX idx_viaje_idservicio      ON viaje(id_servicio);

CREATE INDEX idx_vp_idviaje            ON viaje_parada(id_viaje);
CREATE INDEX idx_vp_idparada           ON viaje_parada(id_parada);
-- Evitar duplicar secuencias dentro de un viaje
CREATE UNIQUE INDEX uq_vp_viaje_secuencia ON viaje_parada(id_viaje, secuencia);

CREATE INDEX idx_ab_idviaje            ON abordaje(id_viaje);
CREATE INDEX idx_ab_idparada           ON abordaje(id_parada);
CREATE INDEX idx_ab_idusuario          ON abordaje(id_usuario);
CREATE INDEX idx_ab_tsevento           ON abordaje(ts_evento);

CREATE INDEX idx_detalle_costo_costo   ON detalle_costo(id_costo);
CREATE INDEX idx_detalle_costo_tipo    ON detalle_costo(tipo_costo);
-- RUTAS
INSERT INTO ruta SET codigo='R01',  nombre='Terminal Norte - Centro', sentido='ida';
INSERT INTO ruta SET codigo='R01V', nombre='Terminal Norte - Centro', sentido='vuelta';
INSERT INTO ruta SET codigo='R02',  nombre='Universidad - Sur',       sentido='ida';
INSERT INTO ruta SET codigo='R02V', nombre='Universidad - Sur',       sentido='vuelta';
INSERT INTO ruta SET codigo='R03',  nombre='Universidad - Norte',     sentido='ida';
-- PARADAS
INSERT INTO parada SET codigo='P001', nombre='Terminal Norte',     zona='Norte';
INSERT INTO parada SET codigo='P002', nombre='Av. 1 y Calle A',    zona='Norte';
INSERT INTO parada SET codigo='P003', nombre='Av. 2 y Calle B',    zona='Norte';
INSERT INTO parada SET codigo='P004', nombre='Terminal Sur',       zona='Sur';
INSERT INTO parada SET codigo='P010', nombre='Centro',             zona='Centro';
-- RUTA_PARADA (R01)
INSERT INTO ruta_parada (id_ruta, id_parada, orden)
SELECT (SELECT id_ruta FROM ruta WHERE codigo='R01'),
       (SELECT id_parada FROM parada WHERE codigo='P001'),
       1;
INSERT INTO ruta_parada (id_ruta, id_parada, orden)
SELECT (SELECT id_ruta FROM ruta WHERE codigo='R01'),
       (SELECT id_parada FROM parada WHERE codigo='P002'),
       2;
INSERT INTO ruta_parada (id_ruta, id_parada, orden)
SELECT (SELECT id_ruta FROM ruta WHERE codigo='R01'),
       (SELECT id_parada FROM parada WHERE codigo='P010'),
       3;
-- CALENDARIO_SERVICIO
INSERT INTO calendario_servicio (fecha_ini, fecha_fin, lun, mar, mie, jue, vie, sab, dom)
SELECT DATE('2025-09-01'), DATE('2025-12-31'), '1','1','1','1','1','1','1';
-- VIAJE
INSERT INTO viaje (id_ruta, id_servicio, hora_salida_programada, frecuencia_min)
SELECT (SELECT id_ruta FROM ruta WHERE codigo='R01'),
       1,
       '06:00:00',
       15;
-- VIAJE_PARADA
INSERT INTO viaje_parada (id_viaje, id_ruta, id_parada, secuencia, hora_llegada_programada, hora_salida_programada)
SELECT
  (SELECT id_viaje FROM viaje
     WHERE id_ruta=(SELECT id_ruta FROM ruta WHERE codigo='R01')
       AND id_servicio=1
       AND hora_salida_programada='06:00:00'
     ORDER BY id_viaje DESC LIMIT 1),
  (SELECT id_ruta FROM ruta WHERE codigo='R01'),
  (SELECT id_parada FROM parada WHERE codigo='P001'),
  1, '06:00:00','06:00:00';

INSERT INTO viaje_parada (id_viaje, id_ruta, id_parada, secuencia, hora_llegada_programada, hora_salida_programada)
SELECT
  (SELECT id_viaje FROM viaje
     WHERE id_ruta=(SELECT id_ruta FROM ruta WHERE codigo='R01')
       AND id_servicio=1
       AND hora_salida_programada='06:00:00'
     ORDER BY id_viaje DESC LIMIT 1),
  (SELECT id_ruta FROM ruta WHERE codigo='R01'),
  (SELECT id_parada FROM parada WHERE codigo='P002'),
  2, '06:08:00','06:08:00';

INSERT INTO viaje_parada (id_viaje, id_ruta, id_parada, secuencia, hora_llegada_programada, hora_salida_programada)
SELECT
  (SELECT id_viaje FROM viaje
     WHERE id_ruta=(SELECT id_ruta FROM ruta WHERE codigo='R01')
       AND id_servicio=1
       AND hora_salida_programada='06:00:00'
     ORDER BY id_viaje DESC LIMIT 1),
  (SELECT id_ruta FROM ruta WHERE codigo='R01'),
  (SELECT id_parada FROM parada WHERE codigo='P010'),
  3, '06:20:00','06:20:00';
-- USUARIOS
INSERT INTO usuario SET sexo='M', tipo_usuario='estudiante';
INSERT INTO usuario SET sexo='F', tipo_usuario='general';

-- ABORDAJES (todos con usuario válido; id_usuario = 1 o 2)
INSERT INTO abordaje (id_viaje, id_parada, id_usuario, ts_evento, direccion, tarifa_pagada)
SELECT
  (SELECT id_viaje FROM viaje
     WHERE id_ruta=(SELECT id_ruta FROM ruta WHERE codigo='R01')
       AND id_servicio=1
       AND hora_salida_programada='06:00:00'
     ORDER BY id_viaje DESC LIMIT 1),
  (SELECT id_parada FROM parada WHERE codigo='P001'),
  1,
  '2025-09-10 06:00:30',
  'sube',
  0.35;

INSERT INTO abordaje (id_viaje, id_parada, id_usuario, ts_evento, direccion, tarifa_pagada)
SELECT
  (SELECT id_viaje FROM viaje
     WHERE id_ruta=(SELECT id_ruta FROM ruta WHERE codigo='R01')
       AND id_servicio=1
       AND hora_salida_programada='06:00:00'
     ORDER BY id_viaje DESC LIMIT 1),
  (SELECT id_parada FROM parada WHERE codigo='P002'),
  2,
  '2025-09-10 06:08:20',
  'baja',
  0.35;

INSERT INTO abordaje (id_viaje, id_parada, id_usuario, ts_evento, direccion, tarifa_pagada)
SELECT
  (SELECT id_viaje FROM viaje
     WHERE id_ruta=(SELECT id_ruta FROM ruta WHERE codigo='R01')
       AND id_servicio=1
       AND hora_salida_programada='06:00:00'
     ORDER BY id_viaje DESC LIMIT 1),
  (SELECT id_parada FROM parada WHERE codigo='P002'),
  1,
  '2025-09-10 06:08:30',
  'sube',
  0.35;

-- COSTO_OPERACION + DETALLE
INSERT INTO costo_operacion (id_ruta, fecha)
SELECT id_ruta, '2025-09-10' FROM ruta WHERE codigo = 'R01';

SET @idc := (
  SELECT co.id_costo
  FROM costo_operacion co
  JOIN ruta r ON r.id_ruta = co.id_ruta
  WHERE r.codigo = 'R01' AND co.fecha = '2025-09-10'
  LIMIT 1
);

INSERT INTO detalle_costo (id_costo, tipo_costo, monto) VALUES
(@idc, 'combustible', 120.00),
(@idc, 'mantenimiento', 35.00),
(@idc, 'personal', 200.00),
(@idc, 'otros', 15.00);

SELECT vp.*
FROM viaje_parada vp
LEFT JOIN ruta_parada rp
  ON rp.id_ruta = vp.id_ruta AND rp.id_parada = vp.id_parada
WHERE rp.id_ruta IS NULL;

SELECT id_viaje, secuencia, COUNT(*) c
FROM viaje_parada
GROUP BY id_viaje, secuencia
HAVING COUNT(*) > 1;

SELECT r.codigo, co.fecha, SUM(dc.monto) total
FROM costo_operacion co
JOIN detalle_costo dc ON dc.id_costo = co.id_costo
JOIN ruta r ON r.id_ruta = co.id_ruta
GROUP BY r.codigo, co.fecha;
-- 1) ¿Qué rutas tienen mayor ocupación en horas pico?
SELECT r.codigo,
       COUNT(*) AS subidas_pico
FROM abordaje a
JOIN viaje v  ON v.id_viaje = a.id_viaje
JOIN ruta  r  ON r.id_ruta  = v.id_ruta
WHERE a.direccion = 'sube'
  AND (TIME(a.ts_evento) BETWEEN '06:00:00' AND '09:00:00'
       OR TIME(a.ts_evento) BETWEEN '17:00:00' AND '20:00:00')
GROUP BY r.codigo
ORDER BY subidas_pico DESC;
-- 2) ¿Qué horarios presentan menor uso del transporte?
WITH base AS (
  SELECT DATE(a.ts_evento) AS fecha,
         MAKETIME(HOUR(a.ts_evento),
                  IF(MINUTE(a.ts_evento) < 30, 0, 30), 0) AS slot
  FROM abordaje a
  WHERE a.direccion='sube'
)
SELECT b.fecha,
       DATE_FORMAT(b.slot, '%H:%i') AS hhmm_slot,
       COUNT(*) AS subidas
FROM base b
GROUP BY b.fecha, b.slot
ORDER BY subidas ASC, b.fecha ASC, b.slot ASC
LIMIT 10;
-- 3) Métricas para optimizar rutas (consultas listas)
-- 3.1 Tiempo promedio de viaje (programado) por viaje y por ruta
SELECT r.codigo,
       v.id_viaje,
       SEC_TO_TIME(
         TIMESTAMPDIFF(SECOND,
           MIN(vp.hora_salida_programada),
           MAX(vp.hora_llegada_programada)
         )
       ) AS duracion_prog
FROM viaje_parada vp
JOIN viaje v ON v.id_viaje = vp.id_viaje
JOIN ruta  r ON r.id_ruta  = v.id_ruta
GROUP BY r.codigo, v.id_viaje;

-- Promedio por ruta
WITH dur AS (
  SELECT r.codigo, v.id_viaje,
         TIMESTAMPDIFF(SECOND,
           MIN(vp.hora_salida_programada),
           MAX(vp.hora_llegada_programada)) AS segs
  FROM viaje_parada vp
  JOIN viaje v ON v.id_viaje = vp.id_viaje
  JOIN ruta  r ON r.id_ruta  = v.id_ruta
  GROUP BY r.codigo, v.id_viaje
)
SELECT codigo,
       SEC_TO_TIME(AVG(segs)) AS duracion_promedio_prog
FROM dur
GROUP BY codigo;
-- 3.2 Costo por pasajero, ingresos y margen por ruta-fecha
SELECT r.codigo,
       co.fecha,
       SUM(dc.monto)                                  AS costo_total,
       SUM(CASE WHEN a.direccion='sube' THEN 1 ELSE 0 END) AS pasajeros,
       ROUND(SUM(dc.monto) /
             NULLIF(SUM(CASE WHEN a.direccion='sube' THEN 1 ELSE 0 END),0), 2) AS costo_por_pasajero,
       SUM(a.tarifa_pagada)                           AS ingresos,
       ROUND(SUM(a.tarifa_pagada) - SUM(dc.monto), 2) AS margen_aprox
FROM costo_operacion co
JOIN detalle_costo dc ON dc.id_costo = co.id_costo
JOIN ruta r           ON r.id_ruta  = co.id_ruta
LEFT JOIN viaje v     ON v.id_ruta  = r.id_ruta
LEFT JOIN abordaje a  ON a.id_viaje = v.id_viaje AND DATE(a.ts_evento) = co.fecha
GROUP BY r.codigo, co.fecha
ORDER BY co.fecha, r.codigo;
-- 3.3 Pasajeros a bordo por tramo (para detectar cuellos de botella)
WITH mov AS (
  SELECT v.id_viaje, r.codigo, vp.secuencia, vp.id_parada,
         COALESCE(SUM(CASE WHEN a.direccion='sube'  THEN 1 END),0) AS suben,
         COALESCE(SUM(CASE WHEN a.direccion='baja' THEN 1 END),0) AS bajan
  FROM viaje_parada vp
  JOIN viaje v ON v.id_viaje = vp.id_viaje
  JOIN ruta  r ON r.id_ruta  = v.id_ruta
  LEFT JOIN abordaje a
         ON a.id_viaje = vp.id_viaje AND a.id_parada = vp.id_parada
  GROUP BY v.id_viaje, r.codigo, vp.secuencia, vp.id_parada
)
SELECT codigo, id_viaje, secuencia,
       suben, bajan,
       SUM(suben - bajan) OVER (PARTITION BY codigo, id_viaje ORDER BY secuencia)
         AS pasajeros_en_bordo
FROM mov
ORDER BY codigo, id_viaje, secuencia;
-- 3.4 Frecuencia / Headway (si usas la columna frecuencia_min)
SELECT r.codigo,
       AVG(v.frecuencia_min) AS headway_prom_min
FROM viaje v
JOIN ruta r ON r.id_ruta = v.id_ruta
GROUP BY r.codigo;