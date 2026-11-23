#!/usr/bin/env python3
"""Prepara smart_manufacturing_data.csv para cqlsh COPY (solo librería estándar).

- Renombra timestamp -> ts (evita palabra clave de CQL) y agrega la columna `mes` (bucket de partición).
- Genera datos/lecturas.csv (todas las filas) y datos/anomalias.csv (failure_type != 'Normal').
"""
import csv
from datetime import datetime

COLS = ["machine_id", "mes", "ts", "temperature", "vibration", "humidity", "pressure",
        "energy_consumption", "machine_status", "anomaly_flag", "predicted_remaining_life",
        "failure_type", "downtime_risk", "maintenance_required"]
COLS_ANOM = ["failure_type", "mes", "ts", "machine_id", "temperature", "vibration", "pressure",
             "anomaly_flag", "predicted_remaining_life", "downtime_risk"]

n = na = 0
with open("smart_manufacturing_data.csv", newline="") as f, \
     open("datos/lecturas.csv", "w", newline="") as f1, \
     open("datos/anomalias.csv", "w", newline="") as f2:
    w1, w2 = csv.DictWriter(f1, COLS), csv.DictWriter(f2, COLS_ANOM, extrasaction="ignore")
    w1.writeheader(); w2.writeheader()
    for r in csv.DictReader(f):
        dt = datetime.strptime(r.pop("timestamp"), "%Y-%m-%d %H:%M:%S")
        r["ts"] = dt.strftime("%Y-%m-%d %H:%M:%S.000+0000")  # UTC
        r["mes"] = dt.strftime("%Y-%m")
        w1.writerow(r); n += 1
        if r["failure_type"] != "Normal":
            w2.writerow(r); na += 1
print(f"{n} lecturas -> datos/lecturas.csv ; {na} anomalías -> datos/anomalias.csv")
