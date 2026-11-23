# Apache Cassandra como entorno para Big Data — Etapa 1

Proyecto grupal (Grupo 5) · Universidad de Talca, Facultad de Ingeniería, Departamento de Ciencias de la Computación · Profesor: Renzo Angles.

## ¿En qué consiste el proyecto?

Se estudia el funcionamiento de **Apache Cassandra** (base de datos NoSQL distribuida, orientada a columnas) como entorno para Big Data. Para ello se levanta un **clúster de 3 nodos con Docker Compose** y se carga un dataset público de Kaggle: [Smart Manufacturing IoT-Cloud Monitoring Dataset](https://www.kaggle.com/) (autor `ziya07`).

- **Dataset:** 100.000 lecturas de sensores (1 por minuto) de 50 máquinas industriales, del 1 de enero al 11 de marzo de 2025.
- **Variables:** temperatura, vibración, humedad, presión, consumo de energía, estado de la máquina, indicador de anomalía, vida remanente estimada, tipo de falla, riesgo de caída y mantención requerida.
- **Modelo de datos:** una tabla por consulta (principio de diseño de Cassandra):
  - `lecturas_por_maquina`: lecturas de una máquina en un mes (clave de partición `(machine_id, mes)`, ordenadas por `ts` descendente).
  - `anomalias_por_tipo`: solo lecturas con falla, por tipo de falla y mes (clave de partición `(failure_type, mes)`).
- **Operaciones de ejemplo:** escritura, consulta y agregación, con consistencia `QUORUM`.

El análisis completo, el diseño y las capturas de evidencia están en el informe: [informe/grupoX-etapa1.pdf](informe/grupoX-etapa1.pdf).

## Estructura del repositorio

```
.
├── docker-compose.yml             # Clúster Cassandra de 3 nodos (cass1, cass2, cass3)
├── cargar.sh                      # Script todo-en-uno: levanta, prepara datos, crea esquema y carga
├── preparar_datos.py              # Transforma el CSV original a los CSV listos para COPY
├── schema.cql                     # Keyspace y tablas
├── operaciones.cql                # Escritura, consultas y agregaciones de ejemplo
├── smart_manufacturing_data.csv   # Dataset original (Kaggle)
├── datos/                         # CSV generados por preparar_datos.py (lecturas.csv, anomalias.csv)
└── informe/                       # Informe LaTeX/PDF y evidencias
```

## Requisitos

| Requisito | Detalle |
|---|---|
| Sistema operativo | Linux, macOS o Windows (10/11 con WSL2) |
| Docker | Docker Engine (Linux) o Docker Desktop (macOS/Windows), con el **daemon activo**. Incluye Docker Compose v2 (`docker compose`) |
| Python | Python 3.6+ (solo librería estándar, no se instalan paquetes) |
| Bash | Necesario para `cargar.sh` (en Windows, usar WSL2 o Git Bash) |
| Memoria RAM | Mínimo **4 GB libres** para Docker con los 3 nodos (cada uno usa un heap de 512 MB). Para un solo nodo bastan ~2 GB |
| Disco | ~2 GB libres (imagen `cassandra:5.0` y volúmenes) |
| Puertos | `9042` libre en el equipo (puerto CQL del nodo `cass1`) |

### Instalar Docker (si no lo tienes)

- **Linux:** seguir la guía oficial de [Docker Engine](https://docs.docker.com/engine/install/) y el paso posterior para usar Docker sin `sudo`. Luego iniciar el daemon:
  ```bash
  sudo systemctl enable --now docker
  ```
- **macOS / Windows:** instalar [Docker Desktop](https://docs.docker.com/desktop/) y **abrirlo** para que el daemon quede corriendo. En Windows, activar el backend WSL2 y ejecutar los comandos desde una terminal de WSL.

Verificar la instalación:

```bash
docker --version
docker compose version
docker info          # si responde sin errores, el daemon está activo
python3 --version
```

> En Docker Desktop, si los nodos se reinician o quedan en estado `Exited`, aumentar la memoria asignada (Settings → Resources) a al menos 4 GB.

## ¿Cómo levantar el proyecto?

### 1. Clonar el repositorio

```bash
git clone <URL-DEL-REPOSITORIO>
cd <carpeta-del-repositorio>
```

### 2. Opción A — Automática (recomendada)

```bash
./cargar.sh
```

Si el archivo no tiene permisos de ejecución: `chmod +x cargar.sh` (o `bash cargar.sh`).

El script realiza, en orden:

1. `docker compose up -d`: levanta los 3 nodos.
2. Espera hasta que los 3 nodos estén en estado `UN` (Up/Normal). **Puede tardar varios minutos** la primera vez, porque los nodos arrancan de forma secuencial.
3. `python3 preparar_datos.py`: genera `datos/lecturas.csv` y `datos/anomalias.csv`.
4. Crea el keyspace y las tablas con `schema.cql`.
5. Carga los datos con `COPY` usando consistencia `QUORUM`.
6. Muestra `nodetool status` al terminar.

### 2. Opción B — Paso a paso

```bash
# 1) Levantar el clúster (3 nodos). Para un solo nodo: docker compose up -d cass1
docker compose up -d

# 2) Esperar a que los 3 nodos aparezcan como UN
docker exec cass1 nodetool status

# 3) Preparar los datos
python3 preparar_datos.py

# 4) Crear keyspace y tablas
docker exec cass1 cqlsh -f /etc/cassandra-lab/schema.cql

# 5) Cargar los datos
docker exec cass1 cqlsh -e "CONSISTENCY QUORUM;
COPY manufactura_iot.lecturas_por_maquina (machine_id,mes,ts,temperature,vibration,humidity,pressure,energy_consumption,machine_status,anomaly_flag,predicted_remaining_life,failure_type,downtime_risk,maintenance_required) FROM '/datos/lecturas.csv' WITH HEADER=true;
COPY manufactura_iot.anomalias_por_tipo (failure_type,mes,ts,machine_id,temperature,vibration,pressure,anomaly_flag,predicted_remaining_life,downtime_risk) FROM '/datos/anomalias.csv' WITH HEADER=true;"
```

> **Modo un solo nodo:** el keyspace usa factor de replicación 3. Con un único nodo, las consultas deben usar `CONSISTENCY ONE` (`operaciones.cql` y `cargar.sh` usan `QUORUM`, por lo que requieren los 3 nodos).

## Verificar que todo funciona

```bash
# Estado del anillo: los 3 nodos deben mostrar "UN"
docker exec cass1 nodetool status

# Conteo de filas cargadas (100.000 en lecturas, 8.101 en anomalías)
docker exec cass1 cqlsh -e "CONSISTENCY QUORUM; SELECT count(*) FROM manufactura_iot.lecturas_por_maquina;"
docker exec cass1 cqlsh -e "CONSISTENCY QUORUM; SELECT count(*) FROM manufactura_iot.anomalias_por_tipo;"
```

## Ejecutar los experimentos

Las operaciones representativas (escribir, consultar, agregar) están en `operaciones.cql`:

```bash
docker exec -it cass1 cqlsh -f /etc/cassandra-lab/operaciones.cql
```

Para explorar de forma interactiva:

```bash
docker exec -it cass1 cqlsh
```

```sql
USE manufactura_iot;
CONSISTENCY QUORUM;
SELECT ts, temperature, vibration, failure_type
FROM lecturas_por_maquina
WHERE machine_id = 15 AND mes = '2025-02' LIMIT 5;
```

| Experimento | Qué hace | Tabla |
|---|---|---|
| 1. Escribir | Inserta una lectura nueva en ambas tablas | `lecturas_por_maquina`, `anomalias_por_tipo` |
| 2. Consultar | Últimas 5 lecturas de la máquina 15 en marzo; últimas 5 fallas por sobrecalentamiento | ambas |
| 3. Agregar | `count`, `avg`, `max`, `sum` y `min` por máquina y mes; conteo de fallas por vibración | ambas |

> Las consultas en Cassandra deben filtrar siempre por la clave de partición completa (por ejemplo `machine_id` **y** `mes`). Esa restricción es parte del diseño que se estudia en el informe.

## Detener y limpiar

```bash
# Detener el clúster conservando los datos
docker compose stop

# Volver a levantarlo (los datos persisten en volúmenes)
docker compose start

# Eliminar contenedores Y datos (volúmenes), para empezar desde cero
docker compose down -v
```

## Problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `Cannot connect to the Docker daemon` | El daemon no está activo | Linux: `sudo systemctl start docker`. macOS/Windows: abrir Docker Desktop |
| `cargar.sh` parece quedar "colgado" | Los nodos tardan en unirse al anillo | Esperar; revisar con `docker logs cass2` o `docker compose ps` |
| Un nodo queda `Exited` o se reinicia | Poca memoria disponible para Docker | Asignar al menos 4 GB, o usar solo `cass1` |
| `port is already allocated` (9042) | Otra instancia de Cassandra usa el puerto | Detenerla o cambiar el puerto en `docker-compose.yml` |
| `Unavailable` / `NoHostAvailable` al consultar con `QUORUM` | No están los 3 nodos arriba (RF=3) | Verificar con `nodetool status`, o usar `CONSISTENCY ONE` |
| `FileNotFoundError` en `preparar_datos.py` | Se ejecutó desde otra carpeta | Ejecutar desde la raíz del repositorio |

## Alcance del proyecto

Este proyecto es de carácter **académico y de investigación**, desarrollado como Etapa 1 del proyecto grupal de unidad. Su objetivo es estudiar y documentar el funcionamiento de Apache Cassandra en un entorno local y reproducible, no ofrecer una solución lista para producción.

En particular:

- El clúster corre en contenedores Docker en una sola máquina, con parámetros de memoria reducidos y sin autenticación, cifrado ni respaldos.
- El dataset es de tamaño moderado (100.000 filas) y se usa con fines demostrativos.
- Los resultados y conclusiones están en el informe y no pretenden generalizarse a otros volúmenes de datos ni a otras configuraciones de hardware.

## Autores y roles

| Integrante | Rol | Contacto |
|---|---|---|
| Gaston Villanueva | Máquinas, investigación del dataset y levantamiento del clúster | gvillanueva19@alumnos.utalca.cl |
| Krisstal Hernandez | Estructuración del proyecto | khernandez22@alumnos.utalca.cl |
| Nicolas Salas | Elaboración del informe | nsalas21@alumnos.utalca.cl |

Profesor: Renzo Angles

## Créditos y recursos externos

Este proyecto fue desarrollado por estudiantes de la **Universidad de Talca** (Facultad de Ingeniería, Departamento de Ciencias de la Computación) y utiliza recursos de terceros, que conservan sus propias licencias y condiciones de uso:

- **Dataset:** *Smart Manufacturing IoT-Cloud Monitoring Dataset*, autor `ziya07`, publicado en Kaggle. Los derechos pertenecen a su autor; consultar la licencia indicada en la página del dataset.
- **Apache Cassandra:** software de la Apache Software Foundation, distribuido bajo licencia Apache 2.0, a través de la imagen oficial de Docker `cassandra:5.0`.
- **Docker / Docker Compose:** utilizados para la instalación reproducible del entorno.

## Licencia

Universidad de Talca
