# Examen SST/PESV — Paso 2: Modelo conceptual (notación Chen, draw.io)

Este documento traduce el modelo normalizado del paso 1 (`01_normalizacion_4FN.md`) al nivel
**conceptual**: entidades del negocio, sus atributos y las relaciones entre ellas, en el lenguaje
del dominio. El diagrama está en `modelos/conceptual.drawio` (se abre en https://app.diagrams.net).

---

## 1. Convenciones del modelo conceptual

Lo que **sí** va en el diagrama:

| Elemento | Forma en draw.io | Regla |
|----------|---------------------|-------|
| Entidad | Rectángulo | Solo el nombre (el de la tabla). Los atributos van en óvalos alrededor. |
| Atributo identificador | Óvalo con texto **subrayado** | `id_<entidad_en_singular>`: único en todo el modelo (p. ej. `id_tenant`, `id_person`). |
| Atributo | Óvalo unido a la entidad por una línea | Solo los descriptivos; nunca claves foráneas. |
| Relación | Rombo con el verbo | El verbo se lee de izquierda a derecha o de arriba hacia abajo. |
| Cardinalidad | Etiqueta `1`, `N` o `M` en cada extremo de la línea | Se escribe junto a la entidad a la que aplica. |
| Participación opcional | Círculo `○` en el extremo (o `0..1`, `0..N`) | Cuando la entidad puede existir sin la relación. |
| Atributos de una relación N:M | Lista pequeña colgando del rombo | Ejemplo: "habilita" tiene *fecha de habilitación*. |

Lo que **no** va (es del modelo relacional, paso 3):

- Claves foráneas (`id_tenant`, `id_module`, …). En el conceptual la pertenencia se expresa con la línea de relación.
- Tipos de dato, `NOT NULL`, `UNIQUE`, índices.
- Tablas puente sin atributos propios ni relaciones adicionales: se dibujan como **relación N:M**, no como entidad. Por eso `tenantsystems` y `tenant_modules` aparecen como rombos, mientras que `tenanttemplates` sí es entidad (ver 2.2).
- Vistas y vistas materializadas.

**Colores sugeridos por zona** (ayudan a explicar el multi‑tenant al docente):

| Zona | Color de fondo | Qué agrupa |
|------|----------------|------------|
| Catálogos / parametrización | Azul claro | Datos compartidos por todas las empresas, sin dueño. |
| Núcleo multi‑tenant | Verde claro | Todo lo que pertenece a una EMPRESA. |
| Control y seguimiento | Naranja claro | Bloqueos, auditoría, indicadores. |

---

## 2. Entidades y atributos

Los nombres de entidades y atributos son **exactamente los del diccionario de datos del paso 1**
(`01_normalizacion_4FN.md`, sección 9), para que los tres modelos se lean con un solo vocabulario.
Convenciones:

- **Identificador:** clave sustituta con nombre **específico y único** por entidad, con el patrón
  `id_<entidad_en_singular>` (`id_country`, `id_tenant`, `id_person`, …). Se evita el `id` genérico
  porque, al hacer `JOIN` entre varias tablas, columnas homónimas obligan a alias y producen errores
  silenciosos (`USING (id)` no existe); con nombres únicos el identificador se reconoce en cualquier
  consulta, vista o trigger sin mirar la tabla de origen. Los identificadores naturales (`country_iso_code`,
  `tenant_nit`, `person_identification`) se dibujan como atributos normales; en el físico serán `UNIQUE`.
- **Claves foráneas (paso 3):** llevan **el mismo nombre que la PK que referencian** (`id_tenant`
  en `persons` apunta a `tenants.id_tenant`). Ventajas: la FK se identifica a simple vista y permite
  `JOIN … USING (id_tenant)`. Cuando una entidad referencia dos veces a la misma tabla o la referencia
  por un *rol*, el nombre se compone `id_<entidad>_<rol>`: `id_person_updated_by`,
  `id_person_created_by`, `id_person_locked_by`.
- **Estándar de nombres:** `snake_case`, inglés, singular. Todo atributo descriptivo lleva el
  **prefijo de su entidad** para que sea único y autoexplicativo en cualquier consulta:
  `country_iso_code`, `format_code`, `tenant_name`, `module_title`, `document_status`. Se prohíben
  los nombres genéricos (`code`, `name`, `description`, `title`) porque en un `JOIN` de varias tablas
  aparecen repetidos y obligan a alias para distinguirlos. Se exceptúan las columnas de auditoría y
  estado, que son una convención transversal con un único significado: booleanos `is_*`, marcas de
  tiempo `*_at`, conteos `*_docs`.
- **Claves foráneas:** no se dibujan. La última columna de cada tabla indica qué columnas del
  diccionario se omiten por ser FK y qué relación (sección 3) las representa. Así se puede
  verificar que *diccionario = óvalos + FK omitidas*.

### 2.1 Zona azul — catálogos de parametrización

| Entidad | Identificador | Atributos (óvalos) | FK omitidas → relación que las representa |
|---------|---------------|--------------------|---------------------------------------------|
| **countries** | `id_country` | country_iso_code, country_name | — |
| **departments** | `id_department` | department_dane_code, department_name | `id_country` → rel. 1 *tiene* |
| **municipalities** | `id_municipality` | municipality_dane_code, municipality_name | `id_department` → rel. 2 *tiene* |
| **tenant_sizes** | `id_tenant_size` | tenant_size_code, tenant_size_name, min_workers, max_workers | — |
| **type_system_sst** | `id_type_system_sst` | system_code, system_name, system_description, is_active | — |
| **phva_stages** | `id_phva_stage` | phva_stage_code, phva_stage_name, phva_stage_order | — |
| **modules** | `id_module` | module_title, module_description, module_order | `id_type_system_sst` → rel. 5 *agrupa* |
| **formats_sst** | `id_format_sst` | format_code, format_name, format_description, is_mandatory | `id_module` → rel. 6 *contiene*; `id_phva_stage` → rel. 7 *clasifica* |
| **templates** | `id_template` | template_name, template_version, template_content, is_active, created_at, updated_at | `id_format_sst` → rel. 9 *se elabora con* |
| **evaluations** | `id_evaluation` | evaluation_name, evaluation_description, is_active | `id_module` → rel. 8 *contiene* |

### 2.2 Zona verde — núcleo multi‑tenant

| Entidad | Identificador | Atributos (óvalos) | FK omitidas → relación que las representa |
|---------|---------------|--------------------|---------------------------------------------|
| **tenants** | `id_tenant` | tenant_nit, tenant_name, contact_email, contact_phone, tenant_address, is_active, created_at, updated_at | `id_municipality` → rel. 3 *ubica*; `id_tenant_size` → rel. 4 *clasifica* |
| **positions** | `id_position` | position_name | `id_tenant` → rel. 14 *define* |
| **persons** | `id_person` | person_identification, first_name, last_name, person_email, person_phone, is_active, created_at, updated_at | `id_tenant` → rel. 15 *vincula*; `id_position` → rel. 16 *es ocupado por* |
| **tenanttemplates** (asociativa) | `id_tenant_template` | assigned_at, updated_at, is_active | `id_tenant` → rel. 12 *recibe*; `id_template` → rel. 13 *se asigna en*; `id_person_updated_by` → rel. 17 *actualiza* |
| **documents** | `id_document` | document_title, document_content, document_status, created_at, updated_at, finalized_at | `id_tenant_template` → rel. 18 *genera*; `id_person_created_by` → rel. 19 *crea* |

Relaciones N:M que **no** son entidad (se dibujan como rombo) y cuyos atributos pasan a la tabla
puente en el modelo relacional:

| Relación | Atributos propios | Tabla puente (paso 3) |
|----------|-------------------|-----------------------|
| tenants *habilita* type_system_sst | is_active, enabled_at | `tenantsystems (id_tenant, id_type_system_sst)` |
| tenants *habilita* modules | is_enabled, enabled_at | `tenant_modules (id_tenant, id_module)` |

**Por qué `tenanttemplates` sí es entidad y no rombo:** aunque nace de la relación N:M
tenants–templates, de ella dependen otras cosas (`documents` se genera *a partir de la asignación*
y `persons` *la actualiza*). Una relación no puede participar en otras relaciones, así que se
promueve a **entidad asociativa** (rectángulo con doble borde).

### 2.3 Zona naranja — control y seguimiento

| Entidad | Identificador | Atributos (óvalos) | FK omitidas → relación que las representa |
|---------|---------------|--------------------|---------------------------------------------|
| **editing_locks** | `id_editing_lock` | locked_at, lock_expires_at, is_active | `id_document` → rel. 20 *es bloqueado por*; `id_person_locked_by` → rel. 21 *posee* |
| **tenant_audit** | `id_tenant_audit` | audit_operation, audited_field, old_value, new_value, changed_by, changed_at | `id_tenant` → rel. 22 *registra* (línea punteada: sin FK física) |
| **compliance_indicators** | `id_compliance_indicator` | total_docs, finalized_docs, draft_docs, pending_docs, not_started_docs, compliance_percentage, calculated_at | `id_tenant` → rel. 23 *mide*; `id_type_system_sst` → rel. 24 *discrimina* |

### 2.4 Resumen de identificadores (PK) y de las FK que generarán en el paso 3

| Entidad | PK | Referenciada como FK en |
|---------|----|-------------------------|
| countries | `id_country` | departments |
| departments | `id_department` | municipalities |
| municipalities | `id_municipality` | tenants |
| tenant_sizes | `id_tenant_size` | tenants |
| type_system_sst | `id_type_system_sst` | modules, tenantsystems, compliance_indicators |
| phva_stages | `id_phva_stage` | formats_sst |
| modules | `id_module` | formats_sst, evaluations, tenant_modules |
| formats_sst | `id_format_sst` | templates |
| templates | `id_template` | tenanttemplates |
| evaluations | `id_evaluation` | — |
| tenants | `id_tenant` | positions, persons, tenantsystems, tenant_modules, tenanttemplates, compliance_indicators, tenant_audit (sin FK física) |
| positions | `id_position` | persons |
| persons | `id_person` | tenanttemplates (`id_person_updated_by`), documents (`id_person_created_by`), editing_locks (`id_person_locked_by`) |
| tenanttemplates | `id_tenant_template` | documents |
| documents | `id_document` | editing_locks |
| editing_locks | `id_editing_lock` | — |
| tenant_audit | `id_tenant_audit` | — |
| compliance_indicators | `id_compliance_indicator` | — |

Las tablas puente `tenantsystems (id_tenant, id_type_system_sst)` y `tenant_modules (id_tenant,
id_module)` no tienen PK propia: su clave es la pareja de FK.

Total: **18 entidades** (las 20 tablas del paso 1 menos `tenantsystems` y `tenant_modules`, que
son relaciones N:M) y **24 relaciones**.

---

## 2.5 Verificación de normalización sobre el modelo final

Con los nombres definitivos se revisó entidad por entidad que el modelo siga en 4FN y que la
información sea coherente entre el conceptual y el diccionario del paso 1:

| Comprobación | Resultado |
|--------------|-----------|
| **1FN** — todo atributo es atómico y no hay grupos repetitivos | ✔ Las listas (sistemas, módulos, plantillas, personas de una empresa) están en entidades o relaciones propias; ningún óvalo contiene más de un valor. |
| **2FN** — sin dependencias parciales | ✔ Solo las relaciones *habilita* tienen clave compuesta (`id_tenant + id_type_system_sst`, `id_tenant + id_module`) y sus atributos (`is_active`, `is_enabled`, `enabled_at`) dependen de la pareja completa, no de una parte. |
| **3FN** — sin dependencias transitivas | ✔ `tenants` guarda solo `id_municipality` (departamento y país se derivan); `tenanttemplates` guarda solo `id_template` (formato, módulo, etapa y sistema se derivan); `persons` guarda `id_position` y no `position_name`. |
| **FNBC** — todo determinante es clave candidata | ✔ Cada entidad tiene PK sustituta `id_<entidad>` y su clave natural (`country_iso_code`, `tenant_nit`, `person_identification`, `format_code`, `template_name + template_version`) será `UNIQUE`. La única redundancia controlada es `persons.id_tenant` frente a `positions.id_tenant`, justificada en el paso 1 (§6) y validada por FK compuesta + trigger 6. |
| **4FN** — sin dependencias multivaluadas independientes en una misma tabla | ✔ `tenants ↠ sistemas`, `tenants ↠ módulos`, `tenants ↠ plantillas` viven en tres relaciones distintas (`habilita`, `habilita`, `recibe/se asigna en`). |
| Nombres únicos en todo el modelo | ✔ 18 PK distintas (`id_<entidad>`), ningún atributo descriptivo genérico; solo `is_*`, `*_at`, `*_docs` se repiten por convención. |
| Coherencia con el paso 1 | ✔ Mismas 20 tablas (18 entidades + 2 puentes), mismas 24 relaciones y cardinalidades; solo cambian los nombres de columnas, que se propagarán al diccionario en el paso 3. |
| Datos derivados | ✔ Únicamente `compliance_indicators` (instantánea histórica exigida por el trigger 11). No hay porcentajes ni conteos almacenados en `tenants`. |

---

## 3. Relaciones

Lectura: *A* **verbo** *B*. La columna "Participación" indica si la entidad puede existir sin la
relación (opcional) o no (obligatoria).

### 3.1 Geografía y clasificación

| # | Entidad A | Verbo | Entidad B | Cardinalidad | Participación |
|---|-----------|-------|-----------|--------------|---------------|
| 1 | countries | tiene | departments | 1 : N | Departamento obligatoria (no existe sin país) |
| 2 | departments | tiene | municipalities | 1 : N | Municipio obligatoria |
| 3 | municipalities | ubica | tenants | 1 : N | Empresa obligatoria; municipio opcional (puede no tener empresas) |
| 4 | tenant_sizes | clasifica | tenants | 1 : N | Empresa obligatoria |

### 3.2 Jerarquía funcional (catálogo)

| # | Entidad A | Verbo | Entidad B | Cardinalidad | Participación |
|---|-----------|-------|-----------|--------------|---------------|
| 5 | type_system_sst | agrupa | modules | 1 : N | Módulo obligatoria |
| 6 | modules | contiene | formats_sst | 1 : N | Formato obligatoria |
| 7 | phva_stages | clasifica | formats_sst | 1 : N | Formato obligatoria |
| 8 | modules | contiene | evaluations | 1 : N | Evaluación obligatoria |
| 9 | formats_sst | se elabora con | templates | 1 : N | Plantilla obligatoria |

### 3.3 Configuración de la empresa (relaciones N:M — aquí está la 4FN)

| # | Entidad A | Verbo | Entidad B | Cardinalidad | Atributos de la relación | Tabla resultante |
|---|-----------|-------|-----------|--------------|--------------------------|------------------|
| 10 | tenants | habilita | type_system_sst | N : M | activo, fecha de habilitación | `tenantsystems` |
| 11 | tenants | habilita | modules | N : M | habilitado, fecha de habilitación | `tenant_modules` |
| 12 | tenants | recibe | tenanttemplates | 1 : N | — | `tenanttemplates.id_tenant` |
| 13 | templates | se asigna en | tenanttemplates | 1 : N | — | `tenanttemplates.id_template` |

Las relaciones 12 y 13 juntas representan la N:M tenants–templates a través de la entidad
asociativa.

### 3.4 Personas y documentos

| # | Entidad A | Verbo | Entidad B | Cardinalidad | Participación |
|---|-----------|-------|-----------|--------------|---------------|
| 14 | tenants | define | positions | 1 : N | Cargo obligatoria |
| 15 | tenants | vincula | persons | 1 : N | Persona obligatoria |
| 16 | positions | es ocupado por | persons | 1 : N | **Persona opcional** (puede no tener cargo aún) |
| 17 | persons | actualiza | tenanttemplates | 1 : N | Asignación opcional (aún no actualizada por nadie) |
| 18 | tenanttemplates | genera | documents | 1 : 1 | **Documento opcional** ("no iniciado" = sin documento) |
| 19 | persons | crea | documents | 1 : N | Documento opcional |

### 3.5 Control y seguimiento

| # | Entidad A | Verbo | Entidad B | Cardinalidad | Participación |
|---|-----------|-------|-----------|--------------|---------------|
| 20 | documents | es bloqueado por | editing_locks | 1 : N | Bloqueo obligatoria |
| 21 | persons | posee | editing_locks | 1 : N | Bloqueo obligatoria |
| 22 | tenants | registra | tenant_audit | 1 : N | Dibujar con **línea punteada**: en el físico no habrá FK para que la auditoría sobreviva al borrado |
| 23 | tenants | mide | compliance_indicators | 1 : N | Indicador obligatoria |
| 24 | type_system_sst | discrimina | compliance_indicators | 1 : N | Indicador obligatoria (uno por SST y otro por PESV) |

Total: **24 relaciones** (22 de tipo 1:N y 2 de tipo N:M con atributos).

---

## 4. Distribución del diagrama

`tenants` es el centro: casi todo se conecta a ella. El lienzo se organiza en tres franjas
horizontales (las zonas de color) y `tenants` queda en el centro de la franja verde:

| Zona | Fila superior | Fila inferior |
|------|---------------|---------------|
| 1 · Catálogos | countries → departments → municipalities · type_system_sst → modules → evaluations | tenant_sizes · phva_stages → formats_sst → templates |
| 2 · Núcleo | positions · **tenants** · tenanttemplates | persons · documents |
| 3 · Control | tenant_audit · compliance_indicators · editing_locks | |

Los óvalos de cada entidad se agrupan encima (fila superior) o debajo (fila inferior) de su
rectángulo, en filas de tres, para que los rombos de relación queden en los pasillos libres entre
entidades. Los conectores se enrutan en ángulo recto esquivando las figuras.

---

## 5. Lista de verificación del diagrama

- [x] 18 entidades, cada una con su identificador `id_<entidad>` subrayado y único en el modelo.
- [x] Ninguna entidad muestra claves foráneas (`id_*` de otra entidad).
- [x] 24 relaciones con verbo en rombo y cardinalidad en ambos extremos.
- [x] Las dos relaciones N:M `habilita` (con `type_system_sst` y con `modules`) generarán `tenantsystems` y `tenant_modules`.
- [x] `tenanttemplates` dibujada con doble borde (entidad asociativa).
- [x] `positions → persons` y `tenanttemplates → documents` con participación **opcional** (`0..N`, `0..1`).
- [x] `tenants ┄ registra ┄ tenant_audit` en línea punteada (sin FK en el físico).
- [x] Tres zonas de color con título.

Para el informe, exportar desde draw.io con *File → Export as → PNG* a `modelos/conceptual.png`.

---

## 6. Estructura de carpetas

```text
examen-sst-pesv/
├── docs/
│   ├── 01_normalizacion_4FN.md      ✔ hecho
│   ├── 02_modelo_conceptual.md      ✔ este documento
│   └── 03_diccionario_datos.md      (paso 4, se genera desde el SQL)
├── modelos/
│   ├── conceptual.drawio            ✔ hecho (abrir en app.diagrams.net)
│   ├── conceptual.png               ← exportación para el informe
│   └── relacional.dbml              (paso 3)
└── sql/
    ├── 01_schema.sql                (paso 4)
    ├── 02_seed.sql
    ├── 03_vistas.sql
    ├── 04_procedimientos.sql
    ├── 05_funciones.sql
    ├── 06_triggers.sql
    └── 07_consultas.sql
```
