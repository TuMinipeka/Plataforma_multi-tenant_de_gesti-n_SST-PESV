#!/usr/bin/env bash
# =====================================================================
# Atajo de terminal para el DIA DEL EXAMEN, cuando SI tienes permiso
# para crear/borrar la base de datos completa (por ejemplo, tu propio
# Docker). Si el profesor solo te da una base ya creada sin permiso de
# superusuario, usa en su lugar 00_examen_completo.sql (ver mas abajo).
#
# Uso:
#   bash 00_build_all.sh                              # Docker local (este equipo)
#   DB_HOST=localhost DB_PORT=5432 DB_USER=postgres \
#     DB_NAME=examen MODE=tcp bash 00_build_all.sh     # psql directo por red (Mac del profesor)
#
# Variables:
#   MODE          docker (por defecto) | tcp
#   DB_CONTAINER  contenedor docker con PostgreSQL   (postgres_db)   [solo MODE=docker]
#   DB_HOST/PORT  host y puerto                       (localhost/5432) [solo MODE=tcp]
#   DB_USER       usuario                            (bkseducate en docker, o el que te den)
#   DB_NAME       base de datos                       (examen)
#
# -----------------------------------------------------------------
# ALTERNATIVA MAS SEGURA PARA EL EXAMEN (recomendada):
#   1. Abre pgAdmin, conectate con las credenciales que te de el profesor.
#   2. Abre el Query Tool sobre la base que te asignen.
#   3. Abre y pega el contenido de sql/00_examen_completo.sql.
#   4. Ejecuta todo (F5). Tarda menos de 1 segundo.
# Esto NO requiere CREATE DATABASE ni permisos especiales: solo
# reescribe las tablas dentro de la base que ya tienes abierta.
# -----------------------------------------------------------------
set -euo pipefail

MODE="${MODE:-docker}"
DB_CONTAINER="${DB_CONTAINER:-postgres_db}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-bkseducate}"
DB_NAME="${DB_NAME:-examen}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

t0=$(date +%s%N)

run_sql() {
    if [[ "$MODE" == "tcp" ]]; then
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -q -f "$1"
    else
        docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -q < "$1"
    fi
}

if [[ "$MODE" == "docker" ]]; then
    echo "1/2 recreando base de datos '$DB_NAME' (modo docker, permite DROP/CREATE DATABASE)..."
    docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d postgres -v ON_ERROR_STOP=1 -q \
        -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();" \
        -c "DROP DATABASE IF EXISTS $DB_NAME;" -c "CREATE DATABASE $DB_NAME;"
else
    echo "1/2 modo tcp: se asume que la base '$DB_NAME' ya existe (no se recrea; usa 00_reset.sql internamente)."
fi

echo "2/2 esquema + datos + vistas (archivo unico)..."
run_sql "$DIR/00_examen_completo.sql"

t1=$(date +%s%N)
echo "Listo. Tiempo total: $(( (t1 - t0) / 1000000 )) ms"
