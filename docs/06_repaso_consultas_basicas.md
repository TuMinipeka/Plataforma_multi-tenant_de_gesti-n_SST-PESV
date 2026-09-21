# Repaso — Consultas SQL básicas

El enunciado (sección "1. Consultas SQL básicas") dice textualmente que esta parte evalúa:

> `SELECT`, `WHERE`, `ORDER BY`, `DISTINCT`, operadores relacionales, operadores lógicos, `LIKE`,
> `IN`, `BETWEEN`, `IS NULL`, funciones básicas y limitación de resultados.

Nada de `JOIN` todavía (eso es la sección intermedia) — **todas las básicas se resuelven contra
una sola tabla**. Este documento es el repaso teórico con la sintaxis mínima; la respuesta a las
15 preguntas del enunciado está en `sql/07_consultas_basicas.sql`, ya probada contra la base.

## 1. Esqueleto de toda consulta básica

```sql
SELECT [DISTINCT] columna1, columna2, ...
FROM tabla
WHERE condicion
ORDER BY columna [ASC|DESC]
LIMIT n;
```

El orden de escritura es siempre `SELECT → FROM → WHERE → ORDER BY → LIMIT`, aunque el motor las
*ejecuta* en otro orden interno (`FROM → WHERE → SELECT → ORDER BY → LIMIT`) — por eso no puedes
usar en el `WHERE` un alias que definiste en el `SELECT`.

## 2. Cada concepto, con la sintaxis que hay que recordar

| Concepto | Sintaxis | Ejemplo con nuestras tablas |
|---|---|---|
| **Proyección** (elegir columnas) | `SELECT col1, col2 FROM tabla;` | `SELECT tenant_name, contact_email FROM tenants;` |
| **Todas las columnas** | `SELECT * FROM tabla;` | `SELECT * FROM tenants;` |
| **DISTINCT** | `SELECT DISTINCT col FROM tabla;` | `SELECT DISTINCT id_tenant_size FROM tenants;` |
| **Operadores relacionales** | `=`  `<>` o `!=`  `<`  `>`  `<=`  `>=` | `WHERE is_active = TRUE` |
| **Operadores lógicos** | `AND`  `OR`  `NOT` | `WHERE is_active = TRUE AND id_tenant_size = 1` |
| **LIKE** (patrón de texto) | `LIKE 'patron'` — `%` = cualquier cantidad de caracteres, `_` = exactamente uno | `WHERE tenant_name LIKE '%Valle%'` |
| **ILIKE** (LIKE sin distinguir mayúsculas — *extensión de PostgreSQL*, no estándar) | `ILIKE 'patron'` | `WHERE tenant_name ILIKE '%valle%'` |
| **IN** (pertenece a una lista) | `WHERE col IN (v1, v2, ...)` | `WHERE id_tenant_size IN (1, 2)` |
| **BETWEEN** (rango cerrado, incluye los dos extremos) | `WHERE col BETWEEN a AND b` | `WHERE created_at BETWEEN '2026-01-01' AND '2026-12-31'` |
| **IS NULL / IS NOT NULL** | nunca `= NULL`, siempre `IS NULL` | `WHERE id_position IS NULL` |
| **ORDER BY** | `ORDER BY col [ASC\|DESC]`, puede llevar varias columnas separadas por coma | `ORDER BY tenant_name ASC` |
| **LIMIT** (limitar resultados) | `LIMIT n` (y opcional `OFFSET m`) | `LIMIT 5` |
| **Funciones básicas de texto** | `UPPER()`, `LOWER()`, `TRIM()`, `LENGTH()`, `\|\|` (concatenar) | `SELECT first_name \|\| ' ' \|\| last_name FROM persons;` |
| **Funciones básicas de fecha** | `NOW()`, `CURRENT_DATE`, `EXTRACT(YEAR FROM col)` | `WHERE EXTRACT(YEAR FROM created_at) = 2026` |

## 3. Tablas y columnas que usan las 15 preguntas del enunciado

Ninguna requiere `JOIN`; cada pregunta apunta a **una sola tabla**. Recordatorio de nombres reales
(ver `docs/03_modelo_fisico.md` para el diccionario completo):

| Tabla | Columnas relevantes |
|---|---|
| `tenants` | `id_tenant`, `tenant_name`, `contact_email`, `contact_phone`, `is_active`, `created_at`, `id_tenant_size` |
| `persons` | `id_person`, `id_tenant`, `first_name`, `last_name`, `person_email`, `is_active` |
| `countries` | `id_country`, `country_name` |
| `departments` | `id_department`, `department_name`, `id_country` |
| `municipalities` | `id_municipality`, `municipality_name`, `id_department` |
| `positions` | `id_position`, `id_tenant`, `position_name` |
| `tenant_sizes` | `id_tenant_size`, `tenant_size_code`, `tenant_size_name`, `min_workers`, `max_workers` |
| `type_system_sst` | `id_type_system_sst`, `system_code`, `system_name` |
| `modules` | `id_module`, `module_title`, `module_description`, `module_order` |

**Nota de vocabulario:** el enunciado dice "mediante su identificador `tenant_id`" (pregunta 10),
pero en nuestro diccionario esa columna se llama `id_tenant` (convención fijada en el paso 2). Es
la misma idea, solo cambia el nombre — en el examen real usa el nombre que tenga la tabla que te
den.

## 4. Errores típicos a evitar (para hacerlo de memoria sin tropiezos)

1. **`WHERE col = NULL`** nunca funciona — siempre `IS NULL` / `IS NOT NULL`.
2. **Comillas simples para texto**, dobles para nombres de columna/tabla si hace falta (casi nunca
   hace falta si todo está en minúsculas, como en este diseño).
3. **`BETWEEN` es inclusivo** en ambos extremos: `BETWEEN 1 AND 5` incluye el 1 y el 5.
4. **`ORDER BY` va después de `WHERE`**, nunca antes.
5. Booleanos en PostgreSQL: `WHERE is_active` ya es válido (equivale a `= TRUE`); si te piden ser
   explícito, escribe `WHERE is_active = TRUE`.
6. `LIKE` es sensible a mayúsculas por estándar SQL; si el examen es en PostgreSQL puedes usar
   `ILIKE`, pero si piden estándar ANSI, usa `LIKE LOWER('%patron%')` sobre `LOWER(columna)`.

## 5. Cómo practicar

1. Monta la base con `sql/00_examen_completo.sql` (ver `docs/05_dia_del_examen.md`).
2. Lee las 15 preguntas de la sección "1. Consultas SQL básicas" del enunciado.
3. Escribe tu propia consulta en la terminal (`psql`) **sin mirar** `sql/07_consultas_basicas.sql`.
4. Compara tu resultado contra ese archivo solo al final, no antes.
