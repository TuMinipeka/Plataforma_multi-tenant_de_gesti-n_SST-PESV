# Examen SST/PESV — Paso 4: Vistas y vistas materializadas

Script: `sql/03_vistas.sql`. Base de datos `examen`, esquema `public`. Cubre la sección
"Consultas orientadas a vistas y vistas materializadas" del enunciado (ítems 1–8) y deja lista la
base para las avanzadas 10, 22 y 25.

## 1. Vistas normales (siempre reflejan el dato actual)

| Vista | Enunciado | Qué resuelve |
|---|---|---|
| `vw_tenant_persons` | Vistas #1 | Empresa + persona + cargo. `LEFT JOIN` en `positions` porque una persona puede no tener cargo aún. |
| `vw_tenant_geography` | Vistas #2 | Empresa + municipio + departamento + país, resolviendo la cadena transitiva `tenants → municipalities → departments → countries`. |
| `vw_tenant_modules` | Vistas #3 | Módulos habilitados por empresa junto con el sistema (SST/PESV) al que pertenecen. |
| `vw_tenant_templates_phva` | Vistas #4 | Plantillas activas asignadas por empresa, agrupadas y contadas por etapa PHVA. |
| `vw_tenant_positions` | Vistas #5 | Total de personas por empresa y cargo. `LEFT JOIN` en `persons` para no perder cargos sin nadie asignado. |
| `vw_tenant_summary` | Apoyo (usada por avanzadas 3, 19, 25) | Una fila por empresa con 4 subconsultas escalares: personas, módulos habilitados, plantillas activas y sistemas habilitados. |

Todas son vistas ordinarias (`CREATE OR REPLACE VIEW`): no almacenan datos, se recalculan en cada
consulta, así que siempre están sincronizadas con las tablas base.

## 2. Vistas materializadas

| Vista | Enunciado | Contenido |
|---|---|---|
| `vm_template_sst_docs_summary` | Vistas #6; avanzadas 10, 22, 25 | Por empresa: total de documentos, finalizados, borrador, pendientes, no iniciados y `compliance_percentage`, **solo para plantillas del sistema SST**. |
| `vm_template_pesv_docs_summary` | Igual, sistema PESV |

Diferencia clave con `vw_tenant_summary`: estas **sí** almacenan el resultado físicamente (`WITH
DATA`), porque agregan sobre varias tablas grandes (`tenanttemplates`, `documents`) y se consultan
con frecuencia para dashboards de cumplimiento — no conviene recalcular el `JOIN`+`GROUP BY`
completo en cada lectura.

`not_started_docs` cuenta las asignaciones (`tenanttemplates`) sin fila en `documents`, coherente
con la regla del paso 1: "no iniciado" es ausencia de documento, no un valor de estado.

## 3. Refrescar las vistas materializadas (Vistas #7)

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY vm_template_sst_docs_summary;
REFRESH MATERIALIZED VIEW CONCURRENTLY vm_template_pesv_docs_summary;
```

`CONCURRENTLY` permite seguir consultando la vista mientras se refresca (sin bloqueo de lectura),
pero **exige un índice único** sobre la vista — por eso cada una tiene
`ux_vm_template_..._tenant` en `id_tenant`. Sin ese índice, `REFRESH ... CONCURRENTLY` falla.

## 4. Qué columnas necesitan índice (Vistas #8)

| Columna | Índice creado | Por qué |
|---|---|---|
| `id_tenant` | `UNIQUE` (`ux_vm_..._tenant`) | Es la clave natural de la vista (una fila por empresa); además la exige `REFRESH CONCURRENTLY`. |
| `compliance_percentage` | `ix_vm_..._pct` | Las consultas avanzadas 11–14 filtran/ordenan por este valor (por debajo del promedio, ranking, clasificación bajo/medio/alto). |

No se indexaron `total_docs` ni los conteos individuales: con solo 3–4 empresas por sistema el
optimizador prefiere *seq scan*, y son columnas que casi siempre se leen todas juntas (no se
filtra por una sola).

## 5. Verificación contra los datos del paso 3

```
vm_template_sst_docs_summary:
  Constructora Andina  → 4 docs, 1 finalizado, 25.00 %
  Textiles Bogotá       → 3 docs, 0 finalizados, 0.00 %
  Transportes del Valle → 4 docs, 1 finalizado, 25.00 %

vm_template_pesv_docs_summary:
  Constructora Andina  → 4 docs, 0 finalizados, 0.00 %
  Transportes del Valle → 4 docs, 1 finalizado, 25.00 %
```

Coincide exactamente con los `compliance_indicators` cargados a mano en el seed (paso 3), que eran
una instantánea puntual; estas vistas son el mecanismo que los recalcula en vivo.

Logística Rápida no aparece en ninguna de las dos: al estar inactiva no tiene `tenanttemplates`
(el `JOIN` la excluye), lo cual es correcto — no hay nada que resumir para una empresa sin
plantillas asignadas.

## 6. Siguiente paso

```text
sql/
├── 01_schema.sql          ✔
├── 02_seed.sql             ✔
├── 03_vistas.sql           ✔ este paso
├── 04_procedimientos.sql   siguiente: 15 procedimientos del enunciado
├── 05_funciones.sql        8 funciones
├── 06_triggers.sql         15 triggers
└── 07_consultas.sql        consultas básicas, intermedias y avanzadas
```
