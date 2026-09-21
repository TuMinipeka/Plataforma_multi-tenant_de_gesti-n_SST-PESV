# Examen SST/PESV — Paso 3: Modelo físico (PostgreSQL 16)

Script: `sql/01_schema.sql`. Crea el esquema `sst` con el tipo `document_status`, **20 tablas**,
59 restricciones declarativas, 2 índices únicos parciales y 26 índices de apoyo. Es la fuente de
verdad del diccionario de datos: cada tabla y columna relevante lleva `COMMENT ON`, consultable
con `\d+ sst.<tabla>` en `psql`.

## 1. Cómo ejecutarlo

Con el contenedor `postgres_db` del proyecto (`pgsqlcontainer/`):

```bash
docker exec -i postgres_db psql -U bkseducate -d bkddb -v ON_ERROR_STOP=1 < examen-sst-pesv/sql/01_schema.sql
```

El script es **idempotente**: empieza con `DROP SCHEMA IF EXISTS sst CASCADE`, así que se puede
relanzar tantas veces como haga falta durante el desarrollo.

## 2. Traducción del modelo conceptual al físico

| Elemento conceptual | Implementación física |
|---------------------|-----------------------|
| Entidad (rectángulo) | `CREATE TABLE` con PK `id_<entidad>` `SERIAL` |
| Atributo identificador (óvalo subrayado) | `PRIMARY KEY` |
| Identificador natural (`country_iso_code`, `tenant_nit`, `person_identification`, `format_code`) | `UNIQUE` (compuesto con `id_tenant` cuando la unicidad es por empresa) |
| Relación 1:N (rombo) | FK en el lado N con **el mismo nombre que la PK** (`persons.id_tenant → tenants.id_tenant`) |
| Relación 1:N por rol (`actualiza`, `crea`, `posee`) | FK `id_person_updated_by`, `id_person_created_by`, `id_person_locked_by` |
| Relación N:M `habilita` (rombo con óvalos) | Tablas puente `tenantsystems` y `tenant_modules` con PK compuesta + los atributos del rombo |
| Entidad asociativa `tenanttemplates` | Tabla con PK propia `id_tenant_template` y `UNIQUE (id_tenant, id_template)` |
| Relación 1:0..1 `genera` | `documents.id_tenant_template` `NOT NULL UNIQUE`; "no iniciado" = ausencia de fila |
| Relación punteada `registra` | `tenant_audit.id_tenant` **sin** FK |
| Dominio `document_status` | `CREATE TYPE ... AS ENUM ('borrador','pendiente','finalizado')` |

## 3. Reglas de negocio que quedaron garantizadas por estructura

| Regla (paso 1) | Mecanismo | Verificado en el motor |
|----------------|-----------|------------------------|
| R3 una persona solo ocupa cargos de su empresa | `FOREIGN KEY (id_position, id_tenant) REFERENCES positions (id_position, id_tenant)` | ✔ rechaza cargo de otra empresa |
| R7 no duplicar módulo por empresa | PK compuesta de `tenant_modules` | ✔ rechaza duplicado |
| R10 porcentaje 0–100 | `CHECK (compliance_percentage BETWEEN 0 AND 100)` | ✔ rechaza 120 |
| Conteos coherentes del indicador | `CHECK (total = finalizados + borrador + pendientes + no iniciados)` | ✔ rechaza 5 ≠ 2 |
| R12 un solo bloqueo activo por documento | `CREATE UNIQUE INDEX ... WHERE is_active` | ✔ rechaza el segundo |
| Una sola plantilla activa por formato | `CREATE UNIQUE INDEX ... WHERE is_active` | ✔ rechaza la segunda |
| `finalized_at` ⇔ estado `finalizado` | `CHECK ((document_status = 'finalizado') = (finalized_at IS NOT NULL))` | ✔ rechaza finalizado sin fecha |
| Correos con formato válido | `CHECK (... ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$')` | — |
| Vencimiento posterior al bloqueo | `CHECK (lock_expires_at > locked_at)` | — |

Las reglas que dependen del **estado de otras filas** (empresa inactiva, sistema habilitado antes
de habilitar módulos, misma empresa en `updated_by`/`created_by`/`locked_by`, `updated_at`
automático, auditoría) van en `06_triggers.sql`, como pide el enunciado.

## 4. Políticas `ON DELETE`

| Política | Dónde | Por qué |
|----------|-------|---------|
| `RESTRICT` | Todas las FK a catálogos y a `tenants`, `persons`, `templates`, `tenanttemplates` | El enunciado exige impedir borrados con dependientes (triggers 8, 9, 10); la FK ya lo garantiza y el trigger añade el mensaje de negocio. |
| `SET NULL` | `persons.id_position`, `tenanttemplates.id_person_updated_by`, `documents.id_person_created_by` | Quitar un cargo o una persona no debe borrar documentos ni asignaciones. |
| `CASCADE` | `editing_locks` (por documento y por persona), `compliance_indicators` (por empresa) | Son datos de control sin valor propio una vez desaparece lo que controlan. |

## 5. Índices

- **FK sin índice automático:** PostgreSQL solo indexa la PK y los `UNIQUE`; cada FK recibió su
  índice (`ix_<tabla>_<columna>`) porque todos los `JOIN` del examen pasan por ellas.
- **Filtros frecuentes:** `tenants.is_active`, `persons (id_tenant, is_active)`,
  `documents.document_status`, `tenant_audit (id_tenant, changed_at DESC)`,
  `compliance_indicators (id_tenant, id_type_system_sst, calculated_at DESC)` para "último indicador".
- **Búsqueda por nombre (consulta básica 5):** índice sobre `lower(tenant_name)` para `ILIKE`
  con prefijo; si se necesitara `%palabra%`, el siguiente paso sería `pg_trgm`.
- **Parciales:** `WHERE is_active` en plantillas y bloqueos, que además implementan reglas de unicidad.

## 6. Cambios respecto al diccionario preliminar del paso 1

El diccionario de `01_normalizacion_4FN.md §9` se escribió antes de fijar la convención de nombres.
Este script es la versión definitiva; las diferencias son solo de nomenclatura:

| Paso 1 | Físico |
|--------|--------|
| `id` | `id_<entidad>` |
| `<tabla>_id` | `id_<entidad>` (mismo nombre que la PK) |
| `updated_by`, `created_by`, `locked_by` | `id_person_updated_by`, `id_person_created_by`, `id_person_locked_by` |
| `code`, `name`, `description`, `title` | con prefijo de entidad (`format_code`, `tenant_name`, …) |
| `positions.description` | `position_name` |
| `expires_at`, `operation`, `field_name` | `lock_expires_at`, `audit_operation`, `audited_field` |

## 7. Siguientes archivos

```text
sql/
├── 01_schema.sql          ✔ este paso
├── 02_seed.sql            datos de prueba (catálogos completos + 3 empresas)
├── 03_vistas.sql          vw_* y vm_template_{sst,pesv}_docs_summary
├── 04_procedimientos.sql  15 procedimientos del enunciado
├── 05_funciones.sql       8 funciones
├── 06_triggers.sql        15 triggers
└── 07_consultas.sql       consultas básicas, intermedias y avanzadas
```
