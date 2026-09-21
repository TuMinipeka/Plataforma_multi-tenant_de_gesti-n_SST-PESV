# Procedimientos, funciones y triggers (enunciado, secciones 5, 6 y 7)

Los tres archivos se escribieron con PL/pgSQL sencillo — parámetros, variables, `IF`, `RAISE`,
subconsultas directas — sin trucos que sean difíciles de reproducir a mano. Cada uno se probó
contra una base recién montada, con el caso que debe fallar y el caso que debe pasar.

> **Las pruebas ya están dentro de los archivos `.sql`.** Justo debajo de cada `CREATE VIEW`,
> `CREATE PROCEDURE`, `CREATE FUNCTION` y `CREATE TRIGGER` hay una llamada de ejemplo que la usa
> (`SELECT`, `CALL`, o un bloque `BEGIN; ... ROLLBACK;` cuando la prueba modifica datos), así que
> al cargar `sql/00_examen_completo.sql` — por pgAdmin o por terminal, ver
> [`00_instalar_docker.md`](00_instalar_docker.md) — quedan ejecutadas automáticamente y puedes ver
> sus resultados en la salida, sin escribir nada aparte. Las llamadas que modifican datos siempre
> terminan en `ROLLBACK`, así que no dejan cambios permanentes ni afectan los datos de prueba.

## Procedimiento vs. función, en una frase

Un **procedimiento** se invoca con `CALL` y no se puede usar dentro de un `SELECT`; una
**función** siempre `RETURN`-a un valor (o una tabla) y sí se puede usar dentro de una consulta,
por ejemplo en el `SELECT` o en el `WHERE`.

## Procedimientos almacenados — `sql/04_procedimientos.sql`

| # | Procedimiento | Qué hace |
|---|---|---|
| 1 | `sp_registrar_tenant` | Registra una organización, validando antes que no exista otra con el mismo NIT |
| 2 | `sp_registrar_persona` | Registra una persona y la asocia a una organización y a un cargo |
| 3 | `sp_cambiar_estado_tenant` | Activa o desactiva una organización |
| 4 | `sp_asignar_modulo` | Asigna un módulo a una organización, evitando duplicados |
| 5 | `sp_habilitar_sistema` | Habilita un sistema SST/PESV para una organización |
| 6 | `sp_asignar_plantilla` | Asigna la plantilla activa de un formato a una organización |
| 7 | `sp_cambiar_cargo_persona` | Cambia el cargo de una persona |
| 8 | `sp_trasladar_persona` | Traslada una persona de una organización a otra, con su nuevo cargo |
| 9 | `sp_deshabilitar_modulos_tenant_inactivo` | Deshabilita todos los módulos de una organización ya inactiva |
| 10 | `sp_eliminar_asignacion_modulo` | Quita un módulo de una organización, validando que no tenga plantillas dependientes |
| 11 | `sp_contar_plantillas_tenant` | Informa por `RAISE NOTICE` cuántas plantillas tiene una organización |
| 12 | `sp_calcular_cumplimiento_tenant` | Calcula el % de cumplimiento (finalizados vs. pendientes) en un parámetro de salida |
| 13 | `sp_documentos_por_etapa` | Cuenta los documentos de una organización en una etapa PHVA, en un parámetro de salida |
| 14 | `sp_actualizar_contacto_tenant` | Actualiza correo, teléfono y dirección de una organización en una sola operación |
| 15 | `sp_asignar_plantilla_segura` | Igual que el 6, pero con `EXCEPTION` para capturar y avisar cualquier error sin abortar |

Ejemplos de uso (los `id_tenant`/`id_module`/etc. son los del `02_seed.sql`):

```sql
CALL sp_registrar_tenant('900123456-7', 'Nueva SAS', 'a@a.com', '3000000000', 'Cra 1', 1, 1);
CALL sp_cambiar_estado_tenant(2, FALSE);
CALL sp_contar_plantillas_tenant(3);                 -- imprime un RAISE NOTICE
CALL sp_calcular_cumplimiento_tenant(4, NULL);        -- el resultado llega en el parametro OUT
```

## Funciones almacenadas — `sql/05_funciones.sql`

| # | Función | Retorna |
|---|---|---|
| 1 | `fn_total_personas_tenant(id_tenant)` | Cantidad de personas de una organización |
| 2 | `fn_porcentaje_cumplimiento_tenant(id_tenant)` | % de documentos finalizados sobre el total generado |
| 3 | `fn_tenant_tiene_modulo(id_tenant, id_module)` | `BOOLEAN`: si el módulo está habilitado |
| 4 | `fn_nombre_completo_persona(id_person)` | Nombre y apellido concatenados |
| 5 | `fn_total_plantillas_tenant_etapa(id_tenant, id_phva_stage)` | Cantidad de plantillas en esa etapa PHVA |
| 6 | `fn_modulos_habilitados_tenant(id_tenant)` | Tabla: módulos habilitados de una organización |
| 7 | `fn_personas_cargos_tenant(id_tenant)` | Tabla: personas de una organización con su cargo |
| 8 | `fn_nivel_cumplimiento_tenant(id_tenant)` | `'Bajo'`, `'Medio'` o `'Alto'` (reutiliza la función 2) |

> **Nota:** la función 2 usa `finalizados / total generado`, la misma definición de
> `compliance_percentage` en las vistas materializadas. El procedimiento 12 usa
> `finalizados / (finalizados + pendientes)` porque así lo pide el enunciado
> ("a partir de sus documentos finalizados y pendientes"). No es un error: son dos ejercicios
> distintos con enunciados distintos.

```sql
SELECT fn_total_personas_tenant(3);
SELECT fn_nivel_cumplimiento_tenant(3);
SELECT * FROM fn_modulos_habilitados_tenant(2);
SELECT * FROM fn_personas_cargos_tenant(3);
```

## Triggers — `sql/06_triggers.sql`

| # | Trigger | Evento | Qué garantiza |
|---|---|---|---|
| 1 | `trg_tenants_updated_at` | `BEFORE UPDATE` en `tenants` | Refresca `updated_at` automáticamente |
| 2 | `trg_persons_updated_at` | `BEFORE UPDATE` en `persons` | Refresca `updated_at` automáticamente |
| 3 | `trg_persons_check_tenant_active` | `BEFORE INSERT` en `persons` | No se registra personal en una empresa inactiva |
| 4 | `trg_tenant_modules_no_duplicado` | `BEFORE INSERT` en `tenant_modules` | Mensaje claro si el módulo ya estaba asignado |
| 5 | `trg_tenanttemplates_check_tenant_active` | `BEFORE INSERT` en `tenanttemplates` | No se asignan plantillas a una empresa inactiva |
| 6 | `trg_persons_check_position_tenant` | `BEFORE INSERT/UPDATE` en `persons` | El cargo debe ser de la misma empresa que la persona |
| 7 | `trg_tenanttemplates_updated_at` | `BEFORE UPDATE` en `tenanttemplates` | Refresca `updated_at` automáticamente |
| 8 | `trg_tenants_check_no_persons` | `BEFORE DELETE` en `tenants` | No se borra una empresa con personas asociadas |
| 9 | `trg_type_system_check_not_in_use` | `BEFORE DELETE` en `type_system_sst` | No se borra un sistema que alguna empresa tenga habilitado |
| 10 | `trg_modules_check_not_in_use` | `BEFORE DELETE` en `modules` | No se borra un módulo asignado a alguna empresa |
| 11 | `trg_compliance_check_range` | `BEFORE INSERT/UPDATE` en `compliance_indicators` | El porcentaje queda entre 0 y 100 |
| 12 | `trg_tenants_audit_datos` | `AFTER UPDATE` en `tenants` | Audita cambios de nombre, correo, teléfono y dirección |
| 13 | `trg_tenants_audit_estado` | `AFTER UPDATE` en `tenants` | Audita el valor anterior y nuevo cuando cambia `is_active` |
| 14 | `trg_tenanttemplates_require_responsible` | `BEFORE UPDATE` en `tenanttemplates` | Exige que quede registrada la persona responsable del cambio |
| 15 | `trg_editing_locks_clean_expired` | `BEFORE INSERT` en `editing_locks` | Marca como inactivos los bloqueos vencidos antes de crear uno nuevo |

### Por qué algunos triggers "repiten" una restricción que ya existe

Los triggers 4, 6, 8, 9, 10 y 11 verifican reglas que **ya** están garantizadas por una `PRIMARY
KEY`, una `FOREIGN KEY` compuesta o un `CHECK` (ver `docs/03_modelo_fisico.md`, sección 3). Eso es
intencional, no redundancia por descuido: el enunciado pide explícitamente esos triggers, y como
un trigger `BEFORE` se ejecuta *antes* que la restricción del motor, el usuario ve el mensaje
propio y claro (`"El modulo 1 ya esta asignado a la organizacion 4"`) en vez del error genérico de
PostgreSQL (`duplicate key value violates unique constraint...`). Se comprobó con pruebas que el
mensaje del trigger es siempre el que aparece primero.

### Sobre el trigger 15 (bloqueos vencidos)

PostgreSQL no tiene una forma nativa de ejecutar un trigger "cada cierto tiempo" — los triggers
solo reaccionan a operaciones `INSERT`/`UPDATE`/`DELETE`. La aproximación práctica y simple que
usa este trigger es limpiar los bloqueos vencidos **justo antes** de que alguien intente tomar uno
nuevo (`BEFORE INSERT`), que es exactamente el momento en que importa que la tabla esté al día.
Se probó insertando un bloqueo ya vencido y comprobando que una segunda persona sí puede tomar un
bloqueo nuevo sobre el mismo documento — el trigger desactivó el vencido automáticamente.

## Cómo se probó

Cada objeto se ejecutó contra una base recién montada con `00_examen_completo.sql` (que ya
incluye estos tres archivos), dentro de transacciones con `ROLLBACK` para no alterar los datos de
prueba entre una verificación y la siguiente:

- Los 15 procedimientos: caso que debe fallar (duplicados, IDs inexistentes) y caso que debe
  pasar, incluyendo los parámetros de salida (`OUT`) y el manejo de excepciones del
  procedimiento 15.
- Las 8 funciones: valores simples y las dos funciones tabulares (`SELECT * FROM fn_...(...)`).
- Los 15 triggers: cada regla de bloqueo se intentó violar (y falló con el mensaje esperado) y
  cada caso válido se intentó y pasó, incluyendo la auditoría (12 y 13) y la limpieza de bloqueos
  vencidos (15).

## Siguiente paso

Con esto quedan completas las siete secciones del enunciado: modelo conceptual, modelo relacional,
modelo físico, vistas, procedimientos, funciones y triggers, más las cuatro baterías de consultas
(básicas, intermedias, avanzadas y orientadas a vistas).
