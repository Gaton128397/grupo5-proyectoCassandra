-- Ejecutar:  docker exec -it cass1 cqlsh -f /etc/cassandra-lab/operaciones.cql
USE manufactura_iot;
CONSISTENCY QUORUM;

-- 1) ESCRIBIR: insertar una lectura nueva (en ambas tablas, una por consulta)
INSERT INTO lecturas_por_maquina (machine_id, mes, ts, temperature, vibration, humidity, pressure,
  energy_consumption, machine_status, anomaly_flag, predicted_remaining_life, failure_type, downtime_risk, maintenance_required)
VALUES (15, '2025-03', '2025-03-11 10:40:00+0000', 99.5, 45.0, 50.0, 3.0, 4.2, 2, 1, 12, 'Overheating', 1.0, 1);
INSERT INTO anomalias_por_tipo (failure_type, mes, ts, machine_id, temperature, vibration, pressure,
  anomaly_flag, predicted_remaining_life, downtime_risk)
VALUES ('Overheating', '2025-03', '2025-03-11 10:40:00+0000', 15, 99.5, 45.0, 3.0, 1, 12, 1.0);

-- 2) CONSULTAR: últimas 5 lecturas de la máquina 15 en marzo (lectura por partition key, ya ordenada)
SELECT ts, temperature, vibration, pressure, failure_type FROM lecturas_por_maquina
WHERE machine_id = 15 AND mes = '2025-03' LIMIT 5;

-- 2b) CONSULTAR: últimas 5 fallas por sobrecalentamiento en marzo, de todas las máquinas
SELECT ts, machine_id, temperature, predicted_remaining_life FROM anomalias_por_tipo
WHERE failure_type = 'Overheating' AND mes = '2025-03' LIMIT 5;

-- 3) AGREGAR: resumen de una máquina en un mes (agregados nativos dentro de una partición)
SELECT count(*) AS lecturas, avg(temperature) AS temp_prom, max(vibration) AS vib_max,
       sum(anomaly_flag) AS anomalias, min(predicted_remaining_life) AS vida_min
FROM lecturas_por_maquina WHERE machine_id = 15 AND mes = '2025-02';

-- 3b) AGREGAR: cantidad de fallas por vibración en febrero
SELECT count(*) AS fallas_vibracion FROM anomalias_por_tipo
WHERE failure_type = 'Vibration Issue' AND mes = '2025-02';
