#!/usr/bin/env bash
# Levanta el anillo, prepara el dataset y lo carga con COPY. Ejecutar desde etapa1/
set -euo pipefail
cd "$(dirname "$0")"

docker compose up -d
echo "Esperando a que los 3 nodos estén UN (Up/Normal)..."
until [ "$(docker exec cass1 nodetool status 2>/dev/null | grep -c '^UN')" -ge 3 ]; do sleep 10; done

python3 preparar_datos.py
docker exec cass1 cqlsh -f /etc/cassandra-lab/schema.cql
docker exec cass1 cqlsh -e "CONSISTENCY QUORUM;
COPY manufactura_iot.lecturas_por_maquina (machine_id,mes,ts,temperature,vibration,humidity,pressure,energy_consumption,machine_status,anomaly_flag,predicted_remaining_life,failure_type,downtime_risk,maintenance_required) FROM '/datos/lecturas.csv' WITH HEADER=true;
COPY manufactura_iot.anomalias_por_tipo (failure_type,mes,ts,machine_id,temperature,vibration,pressure,anomaly_flag,predicted_remaining_life,downtime_risk) FROM '/datos/anomalias.csv' WITH HEADER=true;"
docker exec cass1 nodetool status
