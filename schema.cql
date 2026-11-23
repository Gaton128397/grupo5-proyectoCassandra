-- Keyspace: RF=3 sobre el datacenter del anillo (con 1 solo nodo funciona con CONSISTENCY ONE)
CREATE KEYSPACE IF NOT EXISTS manufactura_iot
  WITH replication = {'class': 'NetworkTopologyStrategy', 'datacenter_manufactura': 3};

USE manufactura_iot;

-- Consulta principal: lecturas de una máquina en un mes, de la más reciente a la más antigua.
-- `mes` acota el tamaño de cada partición (< 1.000 filas), evitando particiones que crecen sin límite.
CREATE TABLE IF NOT EXISTS lecturas_por_maquina (
  machine_id               int,
  mes                      text,
  ts                       timestamp,
  temperature              float,
  vibration                float,
  humidity                 float,
  pressure                 float,
  energy_consumption       float,
  machine_status           int,
  anomaly_flag             int,
  predicted_remaining_life int,
  failure_type             text,
  downtime_risk            float,
  maintenance_required     int,
  PRIMARY KEY ((machine_id, mes), ts)
) WITH CLUSTERING ORDER BY (ts DESC);

-- Tabla desnormalizada (una tabla por consulta): solo lecturas con falla, por tipo de falla y mes.
CREATE TABLE IF NOT EXISTS anomalias_por_tipo (
  failure_type             text,
  mes                      text,
  ts                       timestamp,
  machine_id               int,
  temperature              float,
  vibration                float,
  pressure                 float,
  anomaly_flag             int,
  predicted_remaining_life int,
  downtime_risk            float,
  PRIMARY KEY ((failure_type, mes), ts, machine_id)
) WITH CLUSTERING ORDER BY (ts DESC, machine_id ASC);
