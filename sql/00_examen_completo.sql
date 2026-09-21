-- =====================================================================
--  EXAMEN SST/PESV - ARCHIVO UNICO DE MONTAJE
--  Uso: pgAdmin -> Query Tool -> pegar todo este archivo -> Execute (F5)
--       o en terminal: psql -h <host> -p <puerto> -U <usuario> -d <bd> -f 00_examen_completo.sql
--  No requiere CREATE DATABASE: corre dentro de la base que ya te den.
--  Es idempotente: se puede volver a ejecutar completo si algo sale mal.
-- =====================================================================

-- ############################## 0. RESET ##############################
-- =====================================================================
--  Reset idempotente: deja la base limpia sin necesitar CREATE/DROP DATABASE
--  (util cuando NO tienes permiso de superusuario para recrear la base,
--  como en el equipo/profesor del examen: solo te dan una base ya creada).
--  Se puede correr las veces que haga falta; no falla si los objetos
--  todavia no existen.
-- =====================================================================

DROP MATERIALIZED VIEW IF EXISTS vm_template_sst_docs_summary CASCADE;
DROP MATERIALIZED VIEW IF EXISTS vm_template_pesv_docs_summary CASCADE;

DROP VIEW IF EXISTS vw_tenant_persons CASCADE;
DROP VIEW IF EXISTS vw_tenant_geography CASCADE;
DROP VIEW IF EXISTS vw_tenant_modules CASCADE;
DROP VIEW IF EXISTS vw_tenant_templates_phva CASCADE;
DROP VIEW IF EXISTS vw_tenant_positions CASCADE;
DROP VIEW IF EXISTS vw_tenant_summary CASCADE;

-- El orden no importa: CASCADE arrastra FKs, indices, triggers y vistas
-- que dependan de cada tabla.
DROP TABLE IF EXISTS
    compliance_indicators,
    tenant_audit,
    editing_locks,
    documents,
    tenanttemplates,
    tenant_modules,
    tenantsystems,
    persons,
    positions,
    tenants,
    evaluations,
    templates,
    formats_sst,
    modules,
    phva_stages,
    type_system_sst,
    tenant_sizes,
    municipalities,
    departments,
    countries
CASCADE;

DROP TYPE IF EXISTS document_status;

-- ############################## 1. ESQUEMA ##############################
-- =====================================================================
--  Examen SST/PESV - Paso 3: Modelo fisico
--  Motor   : PostgreSQL 16
--  Esquema : public (base de datos dedicada, sin envoltorio de esquema)
--  Fuente  : docs/01_normalizacion_4FN.md (4FN) y docs/02_modelo_conceptual.md
--
--  Convenciones
--    PK  : id_<entidad_singular>            (id_tenant, id_person, ...)
--    FK  : mismo nombre que la PK referenciada; FK de rol = id_<entidad>_<rol>
--    Atributos descriptivos con prefijo de entidad (tenant_name, format_code)
--    Columnas transversales sin prefijo: is_*, *_at, *_docs
--    Todo texto en snake_case, ingles, singular
--
--  Uso en examen: crear una base de datos nueva y vacia, y correr este
--  script directo contra el esquema public por defecto. Sin DROP SCHEMA,
--  sin search_path que recordar: se pega y se ejecuta.
--    CREATE DATABASE examen;
--    psql -d examen -f 01_schema.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Dominios
-- ---------------------------------------------------------------------
-- "no iniciado" NO es un estado: es la ausencia de fila en documents
CREATE TYPE document_status AS ENUM ('borrador', 'pendiente', 'finalizado');

-- =====================================================================
-- 1. CATALOGOS DE PARAMETRIZACION (compartidos por todas las empresas)
-- =====================================================================

CREATE TABLE countries (
    id_country        SERIAL        PRIMARY KEY,
    country_iso_code  CHAR(2)       NOT NULL UNIQUE,
    country_name      VARCHAR(100)  NOT NULL UNIQUE,
    CONSTRAINT ck_countries_iso CHECK (country_iso_code ~ '^[A-Z]{2}$')
);

CREATE TABLE departments (
    id_department         SERIAL        PRIMARY KEY,
    id_country            INT           NOT NULL REFERENCES countries (id_country) ON DELETE RESTRICT,
    department_dane_code  VARCHAR(10),
    department_name       VARCHAR(100)  NOT NULL,
    CONSTRAINT uq_departments_name UNIQUE (id_country, department_name)
);

CREATE TABLE municipalities (
    id_municipality         SERIAL        PRIMARY KEY,
    id_department           INT           NOT NULL REFERENCES departments (id_department) ON DELETE RESTRICT,
    municipality_dane_code  VARCHAR(10),
    municipality_name       VARCHAR(100)  NOT NULL,
    CONSTRAINT uq_municipalities_name UNIQUE (id_department, municipality_name)
);

CREATE TABLE tenant_sizes (
    id_tenant_size    SERIAL        PRIMARY KEY,
    tenant_size_code  VARCHAR(20)   NOT NULL UNIQUE,
    tenant_size_name  VARCHAR(50)   NOT NULL,
    min_workers       INT           NOT NULL,
    max_workers       INT,                              -- NULL = sin limite superior
    CONSTRAINT ck_tenant_sizes_min   CHECK (min_workers >= 0),
    CONSTRAINT ck_tenant_sizes_range CHECK (max_workers IS NULL OR max_workers > min_workers)
);

CREATE TABLE type_system_sst (
    id_type_system_sst  SERIAL        PRIMARY KEY,
    system_code         VARCHAR(10)   NOT NULL UNIQUE,   -- SST | PESV
    system_name         VARCHAR(100)  NOT NULL,
    system_description  TEXT,
    is_active           BOOLEAN       NOT NULL DEFAULT TRUE
);

CREATE TABLE phva_stages (
    id_phva_stage     SERIAL        PRIMARY KEY,
    phva_stage_code   CHAR(1)       NOT NULL UNIQUE,     -- P | H | V | A
    phva_stage_name   VARCHAR(50)   NOT NULL,
    phva_stage_order  SMALLINT      NOT NULL UNIQUE,
    CONSTRAINT ck_phva_stages_code CHECK (phva_stage_code IN ('P', 'H', 'V', 'A'))
);

CREATE TABLE modules (
    id_module           SERIAL        PRIMARY KEY,
    id_type_system_sst  INT           NOT NULL REFERENCES type_system_sst (id_type_system_sst) ON DELETE RESTRICT,
    module_title        VARCHAR(150)  NOT NULL,
    module_description  TEXT,
    module_order        SMALLINT      NOT NULL,
    CONSTRAINT uq_modules_title UNIQUE (id_type_system_sst, module_title),
    CONSTRAINT uq_modules_order UNIQUE (id_type_system_sst, module_order)
);

CREATE TABLE formats_sst (
    id_format_sst       SERIAL        PRIMARY KEY,
    id_module           INT           NOT NULL REFERENCES modules (id_module) ON DELETE RESTRICT,
    id_phva_stage       INT           NOT NULL REFERENCES phva_stages (id_phva_stage) ON DELETE RESTRICT,
    format_code         VARCHAR(30)   NOT NULL UNIQUE,
    format_name         VARCHAR(150)  NOT NULL,
    format_description  TEXT,
    is_mandatory        BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_formats_sst_name UNIQUE (id_module, format_name)
);

CREATE TABLE templates (
    id_template       SERIAL        PRIMARY KEY,
    id_format_sst     INT           NOT NULL REFERENCES formats_sst (id_format_sst) ON DELETE RESTRICT,
    template_name     VARCHAR(150)  NOT NULL,
    template_version  SMALLINT      NOT NULL DEFAULT 1,
    template_content  TEXT,
    is_active         BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_templates_version CHECK (template_version >= 1),
    CONSTRAINT uq_templates_format_version UNIQUE (id_format_sst, template_version)
);
-- Solo una version activa por formato
CREATE UNIQUE INDEX uq_templates_one_active
    ON templates (id_format_sst) WHERE is_active;

CREATE TABLE evaluations (
    id_evaluation           SERIAL        PRIMARY KEY,
    id_module               INT           NOT NULL REFERENCES modules (id_module) ON DELETE RESTRICT,
    evaluation_name         VARCHAR(150)  NOT NULL,
    evaluation_description  TEXT,
    is_active               BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_evaluations_name UNIQUE (id_module, evaluation_name)
);

-- =====================================================================
-- 2. NUCLEO MULTI-TENANT
-- =====================================================================

CREATE TABLE tenants (
    id_tenant        SERIAL        PRIMARY KEY,
    id_municipality  INT           NOT NULL REFERENCES municipalities (id_municipality) ON DELETE RESTRICT,
    id_tenant_size   INT           NOT NULL REFERENCES tenant_sizes (id_tenant_size) ON DELETE RESTRICT,
    tenant_nit       VARCHAR(20)   NOT NULL UNIQUE,
    tenant_name      VARCHAR(150)  NOT NULL,
    contact_email    VARCHAR(150)  NOT NULL,
    contact_phone    VARCHAR(30),
    tenant_address   VARCHAR(200),
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_tenants_email CHECK (contact_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$')
);

CREATE TABLE positions (
    id_position    SERIAL        PRIMARY KEY,
    id_tenant      INT           NOT NULL REFERENCES tenants (id_tenant) ON DELETE RESTRICT,
    position_name  VARCHAR(150)  NOT NULL,
    CONSTRAINT uq_positions_name UNIQUE (id_tenant, position_name),
    -- habilita la FK compuesta desde persons (cargo de la misma empresa)
    CONSTRAINT uq_positions_tenant UNIQUE (id_position, id_tenant)
);

CREATE TABLE persons (
    id_person              SERIAL        PRIMARY KEY,
    id_tenant              INT           NOT NULL REFERENCES tenants (id_tenant) ON DELETE RESTRICT,
    id_position            INT,                                   -- NULL = aun sin cargo
    person_identification  VARCHAR(20)   NOT NULL,
    first_name             VARCHAR(100)  NOT NULL,
    last_name              VARCHAR(100)  NOT NULL,
    person_email           VARCHAR(150)  NOT NULL,
    person_phone           VARCHAR(30),
    is_active              BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at             TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ   NOT NULL DEFAULT now(),
    -- unicidad limitada al tenant (aislamiento multi-tenant, R13)
    CONSTRAINT uq_persons_identification UNIQUE (id_tenant, person_identification),
    CONSTRAINT uq_persons_email          UNIQUE (id_tenant, person_email),
    CONSTRAINT ck_persons_email          CHECK (person_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
    -- R3: el cargo debe pertenecer a la misma empresa (garantia estructural; trigger 6 la complementa)
    CONSTRAINT fk_persons_position_same_tenant
        FOREIGN KEY (id_position, id_tenant) REFERENCES positions (id_position, id_tenant)
        ON DELETE SET NULL (id_position)
);

-- Relacion N:M tenants -habilita- type_system_sst
CREATE TABLE tenantsystems (
    id_tenant           INT          NOT NULL REFERENCES tenants (id_tenant) ON DELETE RESTRICT,
    id_type_system_sst  INT          NOT NULL REFERENCES type_system_sst (id_type_system_sst) ON DELETE RESTRICT,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    enabled_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    PRIMARY KEY (id_tenant, id_type_system_sst)
);

-- Relacion N:M tenants -habilita- modules (la PK compuesta implementa R7: sin duplicados)
CREATE TABLE tenant_modules (
    id_tenant   INT          NOT NULL REFERENCES tenants (id_tenant) ON DELETE RESTRICT,
    id_module   INT          NOT NULL REFERENCES modules (id_module) ON DELETE RESTRICT,
    is_enabled  BOOLEAN      NOT NULL DEFAULT TRUE,
    enabled_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    PRIMARY KEY (id_tenant, id_module)
);

-- Entidad asociativa: plantilla asignada a una empresa
CREATE TABLE tenanttemplates (
    id_tenant_template    SERIAL       PRIMARY KEY,
    id_tenant             INT          NOT NULL REFERENCES tenants (id_tenant) ON DELETE RESTRICT,
    id_template           INT          NOT NULL REFERENCES templates (id_template) ON DELETE RESTRICT,
    id_person_updated_by  INT          REFERENCES persons (id_person) ON DELETE SET NULL,
    assigned_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    is_active             BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tenanttemplates_assignment UNIQUE (id_tenant, id_template)
);

-- Documento generado a partir de una asignacion (1:1 opcional)
CREATE TABLE documents (
    id_document           SERIAL           PRIMARY KEY,
    id_tenant_template    INT              NOT NULL UNIQUE REFERENCES tenanttemplates (id_tenant_template) ON DELETE RESTRICT,
    id_person_created_by  INT              REFERENCES persons (id_person) ON DELETE SET NULL,
    document_title        VARCHAR(200)     NOT NULL,
    document_content      TEXT,
    document_status       document_status  NOT NULL DEFAULT 'borrador',
    created_at            TIMESTAMPTZ      NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ      NOT NULL DEFAULT now(),
    finalized_at          TIMESTAMPTZ,
    CONSTRAINT ck_documents_finalized
        CHECK ((document_status = 'finalizado') = (finalized_at IS NOT NULL))
);

-- =====================================================================
-- 3. CONTROL Y SEGUIMIENTO
-- =====================================================================

CREATE TABLE editing_locks (
    id_editing_lock      SERIAL       PRIMARY KEY,
    id_document          INT          NOT NULL REFERENCES documents (id_document) ON DELETE CASCADE,
    id_person_locked_by  INT          NOT NULL REFERENCES persons (id_person) ON DELETE CASCADE,
    locked_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    lock_expires_at      TIMESTAMPTZ  NOT NULL,
    is_active            BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_editing_locks_expiry CHECK (lock_expires_at > locked_at)
);
-- Un solo bloqueo activo por documento (R12)
CREATE UNIQUE INDEX uq_editing_locks_one_active
    ON editing_locks (id_document) WHERE is_active;

-- Bitacora: una fila por campo modificado. SIN FK a tenants a proposito:
-- debe sobrevivir al borrado de la empresa (un AFTER DELETE fallaria con FK).
CREATE TABLE tenant_audit (
    id_tenant_audit  BIGSERIAL     PRIMARY KEY,
    id_tenant        INT           NOT NULL,
    audit_operation  VARCHAR(10)   NOT NULL,
    audited_field    VARCHAR(60),                       -- NULL en INSERT / DELETE completos
    old_value        TEXT,
    new_value        TEXT,
    changed_by       VARCHAR(100)  NOT NULL DEFAULT current_user,
    changed_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_tenant_audit_operation CHECK (audit_operation IN ('INSERT', 'UPDATE', 'DELETE'))
);

-- Unica tabla con datos derivados: instantanea historica del indicador (trigger 11)
CREATE TABLE compliance_indicators (
    id_compliance_indicator  SERIAL         PRIMARY KEY,
    id_tenant                INT            NOT NULL REFERENCES tenants (id_tenant) ON DELETE CASCADE,
    id_type_system_sst       INT            NOT NULL REFERENCES type_system_sst (id_type_system_sst) ON DELETE RESTRICT,
    total_docs               INT            NOT NULL,
    finalized_docs           INT            NOT NULL,
    draft_docs               INT            NOT NULL,
    pending_docs             INT            NOT NULL,
    not_started_docs         INT            NOT NULL,
    compliance_percentage    NUMERIC(5, 2)  NOT NULL,
    calculated_at            TIMESTAMPTZ    NOT NULL DEFAULT now(),
    CONSTRAINT uq_compliance_indicators_snapshot UNIQUE (id_tenant, id_type_system_sst, calculated_at),
    CONSTRAINT ck_compliance_indicators_counts CHECK (
        total_docs >= 0 AND finalized_docs >= 0 AND draft_docs >= 0
        AND pending_docs >= 0 AND not_started_docs >= 0
        AND total_docs = finalized_docs + draft_docs + pending_docs + not_started_docs
    ),
    CONSTRAINT ck_compliance_indicators_percentage CHECK (compliance_percentage BETWEEN 0 AND 100)
);

-- =====================================================================
-- 4. INDICES DE APOYO (FK y filtros frecuentes en las consultas del examen)
-- =====================================================================
CREATE INDEX ix_departments_country        ON departments (id_country);
CREATE INDEX ix_municipalities_department  ON municipalities (id_department);
CREATE INDEX ix_modules_system             ON modules (id_type_system_sst);
CREATE INDEX ix_formats_sst_module         ON formats_sst (id_module);
CREATE INDEX ix_formats_sst_stage          ON formats_sst (id_phva_stage);
CREATE INDEX ix_templates_format           ON templates (id_format_sst);
CREATE INDEX ix_evaluations_module         ON evaluations (id_module);
CREATE INDEX ix_tenants_municipality       ON tenants (id_municipality);
CREATE INDEX ix_tenants_size               ON tenants (id_tenant_size);
CREATE INDEX ix_tenants_active             ON tenants (is_active);
CREATE INDEX ix_tenants_name_trgm          ON tenants (lower(tenant_name));   -- busqueda por nombre
CREATE INDEX ix_positions_tenant           ON positions (id_tenant);
CREATE INDEX ix_persons_tenant             ON persons (id_tenant);
CREATE INDEX ix_persons_position           ON persons (id_position);
CREATE INDEX ix_persons_active             ON persons (id_tenant, is_active);
CREATE INDEX ix_tenant_modules_module      ON tenant_modules (id_module);
CREATE INDEX ix_tenantsystems_system       ON tenantsystems (id_type_system_sst);
CREATE INDEX ix_tenanttemplates_template   ON tenanttemplates (id_template);
CREATE INDEX ix_tenanttemplates_updated_by ON tenanttemplates (id_person_updated_by);
CREATE INDEX ix_documents_status           ON documents (document_status);
CREATE INDEX ix_documents_created_by       ON documents (id_person_created_by);
CREATE INDEX ix_editing_locks_document     ON editing_locks (id_document);
CREATE INDEX ix_editing_locks_person       ON editing_locks (id_person_locked_by);
CREATE INDEX ix_editing_locks_expiry       ON editing_locks (lock_expires_at) WHERE is_active;
CREATE INDEX ix_tenant_audit_tenant        ON tenant_audit (id_tenant, changed_at DESC);
CREATE INDEX ix_compliance_tenant          ON compliance_indicators (id_tenant, id_type_system_sst, calculated_at DESC);

-- =====================================================================
-- 5. DOCUMENTACION EN EL CATALOGO (diccionario de datos consultable)
-- =====================================================================

COMMENT ON TYPE  document_status IS 'Estados de un documento generado; "no iniciado" = sin fila en documents';

COMMENT ON TABLE countries        IS 'Catalogo geografico nivel 1';
COMMENT ON TABLE departments      IS 'Catalogo geografico nivel 2 (departamento / region)';
COMMENT ON TABLE municipalities   IS 'Catalogo geografico nivel 3 (municipio / ciudad); unica FK geografica de tenants';
COMMENT ON TABLE tenant_sizes     IS 'Tamano de empresa por rango de trabajadores';
COMMENT ON TABLE type_system_sst  IS 'Sistemas de gestion: SST, PESV';
COMMENT ON TABLE phva_stages      IS 'Etapas del ciclo PHVA: Planear, Hacer, Verificar, Actuar';
COMMENT ON TABLE modules          IS 'Componentes funcionales de un sistema de gestion';
COMMENT ON TABLE formats_sst      IS 'Documento exigido por un modulo, clasificado en una etapa PHVA';
COMMENT ON TABLE templates        IS 'Documento base (plantilla) con el que se elabora un formato; versionado';
COMMENT ON TABLE evaluations      IS 'Instrumentos de evaluacion asociados a un modulo';
COMMENT ON TABLE tenants          IS 'Empresas / organizaciones (tenant). Raiz del aislamiento logico';
COMMENT ON TABLE positions        IS 'Cargos definidos por cada empresa';
COMMENT ON TABLE persons          IS 'Usuarios o trabajadores; pertenecen a una sola empresa';
COMMENT ON TABLE tenantsystems    IS 'N:M empresa - sistema habilitado';
COMMENT ON TABLE tenant_modules   IS 'N:M empresa - modulo habilitado';
COMMENT ON TABLE tenanttemplates  IS 'Plantilla asignada a una empresa (entidad asociativa)';
COMMENT ON TABLE documents        IS 'Documento generado por la empresa a partir de una asignacion (1:1 opcional)';
COMMENT ON TABLE editing_locks    IS 'Bloqueos de edicion concurrente sobre documentos';
COMMENT ON TABLE tenant_audit     IS 'Auditoria de cambios en tenants; sin FK para sobrevivir al borrado';
COMMENT ON TABLE compliance_indicators IS 'Instantanea historica del porcentaje de cumplimiento por empresa y sistema';

COMMENT ON COLUMN persons.id_tenant   IS 'Redundancia controlada frente a positions.id_tenant; garantizada por FK compuesta';
COMMENT ON COLUMN persons.id_position IS 'NULL mientras la persona no tenga cargo';
COMMENT ON COLUMN documents.finalized_at IS 'Obligatorio si y solo si document_status = finalizado';
COMMENT ON COLUMN tenant_audit.id_tenant IS 'Sin FK: la bitacora conserva el id aunque la empresa se elimine';

-- ############################## 2. DATOS DE PRUEBA ##############################
-- =====================================================================
--  Examen SST/PESV - Paso 3: Datos de prueba (seed)
--  Base de datos : examen   (esquema public)
--  Objetivo: catalogos completos + 4 empresas con personas, asignaciones
--  y documentos en distintos estados, para poder correr despues las
--  consultas basicas, intermedias y avanzadas del enunciado.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Geografia
-- ---------------------------------------------------------------------
INSERT INTO countries (country_iso_code, country_name) VALUES
    ('CO', 'Colombia');

INSERT INTO departments (id_country, department_dane_code, department_name)
SELECT id_country, v.code, v.name
FROM countries, (VALUES ('05','Antioquia'), ('11','Bogota D.C.'), ('76','Valle del Cauca')) AS v(code, name)
WHERE country_iso_code = 'CO';

INSERT INTO municipalities (id_department, municipality_dane_code, municipality_name)
SELECT d.id_department, v.code, v.name
FROM departments d
JOIN (VALUES
        ('Antioquia', '05001', 'Medellin'),
        ('Antioquia', '05088', 'Bello'),
        ('Bogota D.C.', '11001', 'Bogota'),
        ('Valle del Cauca', '76001', 'Cali')
     ) AS v(dept, code, name) ON v.dept = d.department_name;

-- ---------------------------------------------------------------------
-- 2. Tamanos de empresa
-- ---------------------------------------------------------------------
INSERT INTO tenant_sizes (tenant_size_code, tenant_size_name, min_workers, max_workers) VALUES
    ('MICRO',  'Microempresa', 1,   10),
    ('SMALL',  'Pequena',      11,  50),
    ('MEDIUM', 'Mediana',      51,  200),
    ('LARGE',  'Grande',       201, NULL);

-- ---------------------------------------------------------------------
-- 3. Sistemas de gestion y etapas PHVA
-- ---------------------------------------------------------------------
INSERT INTO type_system_sst (system_code, system_name, system_description) VALUES
    ('SST',  'Seguridad y Salud en el Trabajo', 'Sistema de gestion SG-SST segun Decreto 1072 de 2015'),
    ('PESV', 'Plan Estrategico de Seguridad Vial', 'PESV segun Resolucion 40595 de 2022');

INSERT INTO phva_stages (phva_stage_code, phva_stage_name, phva_stage_order) VALUES
    ('P', 'Planear',   1),
    ('H', 'Hacer',     2),
    ('V', 'Verificar', 3),
    ('A', 'Actuar',    4);

-- ---------------------------------------------------------------------
-- 4. Modulos por sistema
-- ---------------------------------------------------------------------
INSERT INTO modules (id_type_system_sst, module_title, module_description, module_order)
SELECT ts.id_type_system_sst, v.title, v.descr, v.ord
FROM type_system_sst ts
JOIN (VALUES
        ('SST', 'Politica y Objetivos SST',        'Definicion de la politica del SG-SST',              1),
        ('SST', 'Identificacion de Peligros',      'Matriz de peligros y valoracion de riesgos',        2),
        ('SST', 'Plan de Emergencias',              'Preparacion y respuesta ante emergencias',          3),
        ('SST', 'Capacitacion en SST',              'Programa de capacitacion e induccion',              4),
        ('PESV', 'Diagnostico de Seguridad Vial',   'Linea base de riesgos viales de la organizacion',   1),
        ('PESV', 'Politica de Seguridad Vial',      'Compromiso formal en seguridad vial',               2),
        ('PESV', 'Plan de Accion PESV',              'Acciones para mitigar el riesgo vial',              3),
        ('PESV', 'Auditoria y Seguimiento PESV',    'Verificacion del cumplimiento del PESV',            4)
     ) AS v(sys, title, descr, ord) ON v.sys = ts.system_code;

-- ---------------------------------------------------------------------
-- 5. Formatos (documento exigido por modulo + etapa PHVA)
-- ---------------------------------------------------------------------
INSERT INTO formats_sst (id_module, id_phva_stage, format_code, format_name, format_description, is_mandatory)
SELECT m.id_module, ph.id_phva_stage, v.code, v.name, v.descr, v.mandatory
FROM (VALUES
        ('Politica y Objetivos SST',      'P', 'F-SST-001', 'Politica SST firmada',            'Documento de politica firmado por representante legal', TRUE),
        ('Identificacion de Peligros',    'H', 'F-SST-002', 'Matriz de Peligros y Riesgos',     'Matriz IPVR actualizada',                                TRUE),
        ('Plan de Emergencias',           'H', 'F-SST-003', 'Plan de Emergencias documentado',  'Plan de preparacion y respuesta',                        TRUE),
        ('Capacitacion en SST',           'V', 'F-SST-004', 'Registro de Capacitaciones',       'Listados de asistencia y contenidos',                    FALSE),
        ('Diagnostico de Seguridad Vial', 'P', 'F-PESV-001','Diagnostico Vial Inicial',         'Resultado del diagnostico de riesgo vial',               TRUE),
        ('Politica de Seguridad Vial',    'P', 'F-PESV-002','Politica de Seguridad Vial firmada','Documento de politica vial firmado',                    TRUE),
        ('Plan de Accion PESV',           'H', 'F-PESV-003','Plan de Accion PESV',              'Cronograma de acciones y responsables',                  TRUE),
        ('Auditoria y Seguimiento PESV',  'V', 'F-PESV-004','Informe de Auditoria PESV',        'Resultados de auditoria interna',                        FALSE),
        -- Etapa "Actuar" del ciclo PHVA (acciones correctivas tras verificar)
        ('Plan de Emergencias',           'A', 'F-SST-005', 'Plan de Mejora de Emergencias',    'Acciones correctivas tras simulacros o eventos reales',  FALSE),
        ('Auditoria y Seguimiento PESV',  'A', 'F-PESV-005','Plan de Mejora PESV',              'Acciones correctivas derivadas de la auditoria',         FALSE)
     ) AS v(mod_title, stage_code, code, name, descr, mandatory)
JOIN modules m      ON m.module_title = v.mod_title
JOIN phva_stages ph ON ph.phva_stage_code = v.stage_code;

-- ---------------------------------------------------------------------
-- 6. Plantillas (una version activa por formato)
-- ---------------------------------------------------------------------
INSERT INTO templates (id_format_sst, template_name, template_version, template_content, is_active)
SELECT f.id_format_sst, 'Plantilla ' || f.format_name || ' v1', 1,
       'Contenido base de la plantilla para ' || f.format_name, TRUE
FROM formats_sst f;

-- ---------------------------------------------------------------------
-- 7. Evaluaciones
-- ---------------------------------------------------------------------
INSERT INTO evaluations (id_module, evaluation_name, evaluation_description, is_active)
SELECT m.id_module, v.name, v.descr, TRUE
FROM (VALUES
        ('Identificacion de Peligros',   'Evaluacion de riesgos por puesto de trabajo',   'Cuestionario aplicado a cada puesto'),
        ('Capacitacion en SST',          'Evaluacion de conocimientos SST',               'Prueba de conocimientos posterior a la capacitacion'),
        ('Diagnostico de Seguridad Vial','Evaluacion de conductores',                     'Evaluacion de aptitud y conocimientos de conduccion'),
        ('Auditoria y Seguimiento PESV', 'Evaluacion de cumplimiento normativo',          'Checklist de cumplimiento de la Resolucion 40595')
     ) AS v(mod_title, name, descr)
JOIN modules m ON m.module_title = v.mod_title;

-- ---------------------------------------------------------------------
-- 8. Empresas (tenants)
-- ---------------------------------------------------------------------
INSERT INTO tenants (id_municipality, id_tenant_size, tenant_nit, tenant_name, contact_email, contact_phone, tenant_address, is_active)
SELECT mu.id_municipality, sz.id_tenant_size, v.nit, v.name, v.email, v.phone, v.address, v.active
FROM (VALUES
        ('Medellin', 'LARGE',  '900111222-3', 'Constructora Andina S.A.S.', 'sst@constructoraandina.com.co', '6042551234', 'Cra 45 # 12-30, Medellin',  TRUE),
        ('Cali',     'MEDIUM', '900333444-5', 'Transportes del Valle Ltda', 'sgsst@transportesdelvalle.com', '6023456789', 'Av 6N # 28-40, Cali',       TRUE),
        ('Bogota',   'SMALL',  '900555666-7', 'Textiles Bogota S.A.',       'talentohumano@textilesbogota.co','6017654321', 'Cl 13 # 68-50, Bogota',     TRUE),
        ('Medellin', 'MICRO',  '900777888-9', 'Logistica Rapida SAS',       'gerencia@logisticarapida.co',   '6044456677', 'Cra 80 # 33-10, Medellin',   FALSE)
     ) AS v(muni, size_code, nit, name, email, phone, address, active)
JOIN municipalities mu ON mu.municipality_name = v.muni
JOIN tenant_sizes sz   ON sz.tenant_size_code = v.size_code;

-- ---------------------------------------------------------------------
-- 9. Sistemas habilitados por empresa
--    Constructora Andina: SST + PESV (tiene flota propia)
--    Transportes del Valle: SST + PESV (empresa de transporte)
--    Textiles Bogota: solo SST (no opera vehiculos)
--    Logistica Rapida: SST + PESV, pero inactiva
-- ---------------------------------------------------------------------
INSERT INTO tenantsystems (id_tenant, id_type_system_sst, is_active, enabled_at)
SELECT t.id_tenant, ts.id_type_system_sst, TRUE, now() - (interval '1 day' * v.days_ago)
FROM (VALUES
        ('900111222-3', 'SST',  400),
        ('900111222-3', 'PESV', 380),
        ('900333444-5', 'SST',  300),
        ('900333444-5', 'PESV', 300),
        ('900555666-7', 'SST',  200),
        ('900777888-9', 'SST',  150),
        ('900777888-9', 'PESV', 150)
     ) AS v(nit, sys_code, days_ago)
JOIN tenants t          ON t.tenant_nit = v.nit
JOIN type_system_sst ts ON ts.system_code = v.sys_code;

-- ---------------------------------------------------------------------
-- 10. Modulos habilitados (solo de los sistemas que cada empresa habilito)
-- ---------------------------------------------------------------------
INSERT INTO tenant_modules (id_tenant, id_module, is_enabled, enabled_at)
SELECT ts.id_tenant, m.id_module, TRUE, ts.enabled_at
FROM tenantsystems ts
JOIN modules m ON m.id_type_system_sst = ts.id_type_system_sst
-- Textiles Bogota no habilita "Plan de Emergencias" (aun en evaluacion)
WHERE NOT (
    ts.id_tenant = (SELECT id_tenant FROM tenants WHERE tenant_nit = '900555666-7')
    AND m.module_title = 'Plan de Emergencias'
);

-- ---------------------------------------------------------------------
-- 11. Cargos por empresa
-- ---------------------------------------------------------------------
INSERT INTO positions (id_tenant, position_name)
SELECT t.id_tenant, v.pos
FROM tenants t
JOIN (VALUES
        ('900111222-3', 'Gerente General'),
        ('900111222-3', 'Coordinador SST'),
        ('900111222-3', 'Supervisor de Obra'),
        ('900333444-5', 'Gerente General'),
        ('900333444-5', 'Coordinador SST'),
        ('900333444-5', 'Conductor'),
        ('900333444-5', 'Supervisor de Flota'),
        ('900555666-7', 'Gerente General'),
        ('900555666-7', 'Coordinador SST'),
        ('900555666-7', 'Auxiliar Administrativo'),
        ('900777888-9', 'Gerente General'),
        ('900777888-9', 'Coordinador SST')
     ) AS v(nit, pos) ON v.nit = t.tenant_nit;

-- ---------------------------------------------------------------------
-- 12. Personas
-- ---------------------------------------------------------------------
INSERT INTO persons (id_tenant, id_position, person_identification, first_name, last_name, person_email, person_phone, is_active)
SELECT t.id_tenant, p.id_position, v.doc, v.first_name, v.last_name, v.email, v.phone, v.active
FROM (VALUES
        ('900111222-3', 'Gerente General',    '71234567', 'Carlos',   'Ramirez',  'carlos.ramirez@constructoraandina.com.co', '3101234567', TRUE),
        ('900111222-3', 'Coordinador SST',    '43567891', 'Diana',    'Gomez',    'diana.gomez@constructoraandina.com.co',    '3112345678', TRUE),
        ('900111222-3', 'Supervisor de Obra', '80123456', 'Jorge',    'Martinez', 'jorge.martinez@constructoraandina.com.co', '3123456789', TRUE),
        ('900333444-5', 'Gerente General',    '16789234', 'Patricia', 'Lopez',    'patricia.lopez@transportesdelvalle.com',   '3134567890', TRUE),
        ('900333444-5', 'Coordinador SST',    '31456789', 'Andres',   'Vargas',   'andres.vargas@transportesdelvalle.com',    '3145678901', TRUE),
        ('900333444-5', 'Conductor',          '94512345', 'Luis',     'Torres',   'luis.torres@transportesdelvalle.com',      '3156789012', TRUE),
        ('900333444-5', 'Conductor',          '98765432', 'Camilo',   'Herrera',  'camilo.herrera@transportesdelvalle.com',   '3157654321', TRUE),
        ('900555666-7', 'Gerente General',    '52345678', 'Monica',   'Castro',   'monica.castro@textilesbogota.co',          '3167890123', TRUE),
        ('900555666-7', 'Coordinador SST',    '11987654', 'Felipe',   'Rojas',    'felipe.rojas@textilesbogota.co',           '3178901234', TRUE),
        ('900555666-7', 'Auxiliar Administrativo', '1010234567', 'Laura', 'Suarez','laura.suarez@textilesbogota.co',          '3189012345', FALSE),
        ('900777888-9', 'Gerente General',    '79456123', 'Ricardo',  'Pena',     'ricardo.pena@logisticarapida.co',          '3190123456', TRUE)
     ) AS v(nit, pos, doc, first_name, last_name, email, phone, active)
JOIN tenants t     ON t.tenant_nit = v.nit
JOIN positions p   ON p.id_tenant = t.id_tenant AND p.position_name = v.pos;

-- ---------------------------------------------------------------------
-- 13. Plantillas asignadas a cada empresa (tenanttemplates)
--     Se asignan las plantillas de los sistemas habilitados por cada una.
-- ---------------------------------------------------------------------
INSERT INTO tenanttemplates (id_tenant, id_template, id_person_updated_by, assigned_at, updated_at, is_active)
SELECT tm.id_tenant, tpl.id_template, coord.id_person,
       tm.enabled_at + interval '2 days', tm.enabled_at + interval '2 days', TRUE
FROM tenant_modules tm
JOIN formats_sst f  ON f.id_module = tm.id_module
JOIN templates tpl  ON tpl.id_format_sst = f.id_format_sst AND tpl.is_active
JOIN LATERAL (
    SELECT p.id_person FROM persons p
    JOIN positions po ON po.id_position = p.id_position
    WHERE p.id_tenant = tm.id_tenant AND po.position_name = 'Coordinador SST'
    LIMIT 1
) coord ON TRUE;

-- ---------------------------------------------------------------------
-- 14. Documentos: se generan solo para ALGUNAS asignaciones
--     (el resto queda "no iniciado" = sin fila en documents, a proposito)
-- ---------------------------------------------------------------------

-- 14a. Documentos FINALIZADOS: la politica SST de Constructora Andina y
--      Transportes del Valle, y la politica PESV de Transportes del Valle.
INSERT INTO documents (id_tenant_template, id_person_created_by, document_title, document_content, document_status, created_at, updated_at, finalized_at)
SELECT tt.id_tenant_template, tt.id_person_updated_by,
       tpl.template_name, 'Documento finalizado y firmado.', 'finalizado',
       tt.assigned_at + interval '5 days', tt.assigned_at + interval '10 days', tt.assigned_at + interval '10 days'
FROM tenanttemplates tt
JOIN templates tpl ON tpl.id_template = tt.id_template
JOIN formats_sst f ON f.id_format_sst = tpl.id_format_sst
JOIN tenants t      ON t.id_tenant = tt.id_tenant
WHERE (t.tenant_nit, f.format_code) IN (
    ('900111222-3', 'F-SST-001'),
    ('900333444-5', 'F-SST-001'),
    ('900333444-5', 'F-PESV-002')
);

-- 14b. Documentos en BORRADOR: la matriz de peligros de Constructora Andina
--      y el diagnostico vial de Transportes del Valle.
INSERT INTO documents (id_tenant_template, id_person_created_by, document_title, document_content, document_status, created_at, updated_at)
SELECT tt.id_tenant_template, tt.id_person_updated_by,
       tpl.template_name, 'Version preliminar en elaboracion.', 'borrador',
       tt.assigned_at + interval '3 days', tt.assigned_at + interval '4 days'
FROM tenanttemplates tt
JOIN templates tpl ON tpl.id_template = tt.id_template
JOIN formats_sst f ON f.id_format_sst = tpl.id_format_sst
JOIN tenants t      ON t.id_tenant = tt.id_tenant
WHERE (t.tenant_nit, f.format_code) IN (
    ('900111222-3', 'F-SST-002'),
    ('900333444-5', 'F-PESV-001')
);

-- 14c. Documentos PENDIENTES (en revision): plan de emergencias de
--      Constructora Andina.
INSERT INTO documents (id_tenant_template, id_person_created_by, document_title, document_content, document_status, created_at, updated_at)
SELECT tt.id_tenant_template, tt.id_person_updated_by,
       tpl.template_name, 'Enviado a revision del coordinador SST.', 'pendiente',
       tt.assigned_at + interval '6 days', tt.assigned_at + interval '7 days'
FROM tenanttemplates tt
JOIN templates tpl ON tpl.id_template = tt.id_template
JOIN formats_sst f ON f.id_format_sst = tpl.id_format_sst
JOIN tenants t      ON t.id_tenant = tt.id_tenant
WHERE (t.tenant_nit, f.format_code) IN (
    ('900111222-3', 'F-SST-003')
);
-- El resto de tenanttemplates queda sin documento => "no iniciado".

-- ---------------------------------------------------------------------
-- 15. Bloqueo de edicion activo (Diana esta editando el borrador
--     de la matriz de peligros de Constructora Andina)
-- ---------------------------------------------------------------------
INSERT INTO editing_locks (id_document, id_person_locked_by, locked_at, lock_expires_at, is_active)
SELECT d.id_document, p.id_person, now() - interval '10 minutes', now() + interval '20 minutes', TRUE
FROM documents d
JOIN tenanttemplates tt ON tt.id_tenant_template = d.id_tenant_template
JOIN templates tpl      ON tpl.id_template = tt.id_template
JOIN formats_sst f      ON f.id_format_sst = tpl.id_format_sst
JOIN tenants t           ON t.id_tenant = tt.id_tenant
JOIN persons p           ON p.id_tenant = t.id_tenant
JOIN positions po        ON po.id_position = p.id_position
WHERE t.tenant_nit = '900111222-3' AND f.format_code = 'F-SST-002' AND po.position_name = 'Coordinador SST';

-- ---------------------------------------------------------------------
-- 16. Auditoria: cambios historicos ilustrativos sobre tenants
--     (en produccion los inserta el trigger 12/13; aqui se cargan a mano
--     porque los triggers aun no se implementan en este paso)
-- ---------------------------------------------------------------------
INSERT INTO tenant_audit (id_tenant, audit_operation, audited_field, old_value, new_value, changed_by, changed_at)
SELECT t.id_tenant, 'UPDATE', 'contact_phone', '6042550000', '6042551234', 'diana.gomez', now() - interval '30 days'
FROM tenants t WHERE t.tenant_nit = '900111222-3';

INSERT INTO tenant_audit (id_tenant, audit_operation, audited_field, old_value, new_value, changed_by, changed_at)
SELECT t.id_tenant, 'UPDATE', 'is_active', 'true', 'false', 'admin', now() - interval '5 days'
FROM tenants t WHERE t.tenant_nit = '900777888-9';

-- ---------------------------------------------------------------------
-- 17. Indicadores de cumplimiento (instantanea historica por empresa/sistema)
--     Calculados a partir de lo realmente cargado en documents/tenanttemplates.
-- ---------------------------------------------------------------------
INSERT INTO compliance_indicators (
    id_tenant, id_type_system_sst, total_docs, finalized_docs, draft_docs,
    pending_docs, not_started_docs, compliance_percentage, calculated_at
)
SELECT
    tt.id_tenant,
    f.id_module_system,
    COUNT(*)                                                    AS total_docs,
    COUNT(*) FILTER (WHERE d.document_status = 'finalizado')    AS finalized_docs,
    COUNT(*) FILTER (WHERE d.document_status = 'borrador')      AS draft_docs,
    COUNT(*) FILTER (WHERE d.document_status = 'pendiente')     AS pending_docs,
    COUNT(*) FILTER (WHERE d.id_document IS NULL)               AS not_started_docs,
    ROUND(100.0 * COUNT(*) FILTER (WHERE d.document_status = 'finalizado') / COUNT(*), 2) AS compliance_percentage,
    now()
FROM tenanttemplates tt
JOIN templates tpl ON tpl.id_template = tt.id_template
JOIN (
    SELECT fs.id_format_sst, m.id_type_system_sst AS id_module_system
    FROM formats_sst fs JOIN modules m ON m.id_module = fs.id_module
) f ON f.id_format_sst = tpl.id_format_sst
LEFT JOIN documents d ON d.id_tenant_template = tt.id_tenant_template
GROUP BY tt.id_tenant, f.id_module_system;

COMMIT;

-- =====================================================================
-- Verificacion rapida
-- =====================================================================
SELECT 'tenants' AS tabla, COUNT(*) FROM tenants
UNION ALL SELECT 'persons', COUNT(*) FROM persons
UNION ALL SELECT 'positions', COUNT(*) FROM positions
UNION ALL SELECT 'tenantsystems', COUNT(*) FROM tenantsystems
UNION ALL SELECT 'tenant_modules', COUNT(*) FROM tenant_modules
UNION ALL SELECT 'tenanttemplates', COUNT(*) FROM tenanttemplates
UNION ALL SELECT 'documents', COUNT(*) FROM documents
UNION ALL SELECT 'editing_locks', COUNT(*) FROM editing_locks
UNION ALL SELECT 'tenant_audit', COUNT(*) FROM tenant_audit
UNION ALL SELECT 'compliance_indicators', COUNT(*) FROM compliance_indicators
ORDER BY 1;

-- ############################## 3. VISTAS ##############################
-- =====================================================================
--  Examen SST/PESV - Paso 4: Vistas y vistas materializadas
--  Base de datos : examen   (esquema public)
--  Cubre la seccion "Consultas orientadas a vistas y vistas materializadas"
--  del enunciado (items 1-8) y sirve de base a las avanzadas 10, 22 y 25.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. vw_tenant_persons
--    Empresas junto con sus personas y el cargo que ocupan.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_tenant_persons AS
SELECT
    t.id_tenant,
    t.tenant_nit,
    t.tenant_name,
    p.id_person,
    p.person_identification,
    p.first_name,
    p.last_name,
    p.first_name || ' ' || p.last_name AS full_name,
    p.person_email,
    po.id_position,
    po.position_name,
    p.is_active AS person_is_active
FROM tenants t
JOIN persons p   ON p.id_tenant = t.id_tenant
LEFT JOIN positions po ON po.id_position = p.id_position;

COMMENT ON VIEW vw_tenant_persons IS
    'Empresas con sus personas y el cargo que ocupan (LEFT JOIN: incluye personas sin cargo aun)';

-- ---------------------------------------------------------------------
-- 2. vw_tenant_geography
--    Empresa con municipio, departamento y pais.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_tenant_geography AS
SELECT
    t.id_tenant,
    t.tenant_name,
    mu.municipality_name,
    d.department_name,
    c.country_name
FROM tenants t
JOIN municipalities mu ON mu.id_municipality = t.id_municipality
JOIN departments d     ON d.id_department = mu.id_department
JOIN countries c        ON c.id_country = d.id_country;

COMMENT ON VIEW vw_tenant_geography IS
    'Ubicacion geografica completa de cada empresa (municipio, departamento, pais)';

-- ---------------------------------------------------------------------
-- 3. vw_tenant_modules
--    Modulos habilitados por empresa y el sistema al que pertenecen.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_tenant_modules AS
SELECT
    t.id_tenant,
    t.tenant_name,
    ts.system_code,
    ts.system_name,
    m.id_module,
    m.module_title,
    tm.is_enabled,
    tm.enabled_at
FROM tenant_modules tm
JOIN tenants t          ON t.id_tenant = tm.id_tenant
JOIN modules m          ON m.id_module = tm.id_module
JOIN type_system_sst ts ON ts.id_type_system_sst = m.id_type_system_sst;

COMMENT ON VIEW vw_tenant_modules IS
    'Modulos habilitados por cada empresa, con el sistema de gestion al que pertenecen';

-- ---------------------------------------------------------------------
-- 4. vw_tenant_templates_phva
--    Cantidad de plantillas asignadas a cada empresa, por etapa PHVA.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_tenant_templates_phva AS
SELECT
    t.id_tenant,
    t.tenant_name,
    ph.phva_stage_code,
    ph.phva_stage_name,
    COUNT(*) AS total_templates
FROM tenanttemplates tt
JOIN tenants t      ON t.id_tenant = tt.id_tenant
JOIN templates tpl  ON tpl.id_template = tt.id_template
JOIN formats_sst f  ON f.id_format_sst = tpl.id_format_sst
JOIN phva_stages ph ON ph.id_phva_stage = f.id_phva_stage
WHERE tt.is_active
GROUP BY t.id_tenant, t.tenant_name, ph.phva_stage_code, ph.phva_stage_name, ph.phva_stage_order
ORDER BY t.tenant_name, ph.phva_stage_order;

COMMENT ON VIEW vw_tenant_templates_phva IS
    'Total de plantillas activas asignadas a cada empresa, agrupadas por etapa PHVA';

-- ---------------------------------------------------------------------
-- 5. vw_tenant_positions
--    Total de personas por empresa y cargo.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_tenant_positions AS
SELECT
    t.id_tenant,
    t.tenant_name,
    po.id_position,
    po.position_name,
    COUNT(p.id_person) AS total_persons
FROM positions po
JOIN tenants t ON t.id_tenant = po.id_tenant
LEFT JOIN persons p ON p.id_position = po.id_position
GROUP BY t.id_tenant, t.tenant_name, po.id_position, po.position_name
ORDER BY t.tenant_name, po.position_name;

COMMENT ON VIEW vw_tenant_positions IS
    'Total de personas registradas por empresa y cargo (LEFT JOIN: incluye cargos sin nadie asignado)';

-- ---------------------------------------------------------------------
-- 6. vw_tenant_summary
--    Vista de apoyo (no pedida explicitamente, pero la usan las avanzadas
--    3, 19 y 25): consolida personas, modulos, plantillas y sistemas
--    habilitados por empresa en una sola fila.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_tenant_summary AS
SELECT
    t.id_tenant,
    t.tenant_name,
    t.is_active,
    (SELECT COUNT(*) FROM persons p WHERE p.id_tenant = t.id_tenant) AS total_persons,
    (SELECT COUNT(*) FROM tenant_modules tm WHERE tm.id_tenant = t.id_tenant AND tm.is_enabled) AS total_modules,
    (SELECT COUNT(*) FROM tenanttemplates tt WHERE tt.id_tenant = t.id_tenant AND tt.is_active) AS total_templates,
    (SELECT COUNT(*) FROM tenantsystems ts WHERE ts.id_tenant = t.id_tenant AND ts.is_active) AS total_systems
FROM tenants t;

COMMENT ON VIEW vw_tenant_summary IS
    'Consolidado por empresa: personas, modulos habilitados, plantillas activas y sistemas habilitados';

-- =====================================================================
-- Vistas materializadas
-- =====================================================================

-- ---------------------------------------------------------------------
-- 7. vm_template_sst_docs_summary
--    Resumen de documentos SST por empresa: total, finalizados,
--    borrador, pendientes, no iniciados y porcentaje de cumplimiento.
-- ---------------------------------------------------------------------
CREATE MATERIALIZED VIEW vm_template_sst_docs_summary AS
SELECT
    t.id_tenant,
    t.tenant_nit,
    t.tenant_name,
    COUNT(*)                                                  AS total_docs,
    COUNT(*) FILTER (WHERE d.document_status = 'finalizado')  AS finalized_docs,
    COUNT(*) FILTER (WHERE d.document_status = 'borrador')    AS draft_docs,
    COUNT(*) FILTER (WHERE d.document_status = 'pendiente')   AS pending_docs,
    COUNT(*) FILTER (WHERE d.id_document IS NULL)             AS not_started_docs,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE d.document_status = 'finalizado') / NULLIF(COUNT(*), 0),
        2
    ) AS compliance_percentage,
    now() AS calculated_at
FROM tenants t
JOIN tenanttemplates tt ON tt.id_tenant = t.id_tenant AND tt.is_active
JOIN templates tpl      ON tpl.id_template = tt.id_template
JOIN formats_sst f      ON f.id_format_sst = tpl.id_format_sst
JOIN modules m           ON m.id_module = f.id_module
JOIN type_system_sst ts  ON ts.id_type_system_sst = m.id_type_system_sst AND ts.system_code = 'SST'
LEFT JOIN documents d    ON d.id_tenant_template = tt.id_tenant_template
GROUP BY t.id_tenant, t.tenant_nit, t.tenant_name
WITH DATA;

-- indice unico requerido para poder usar REFRESH MATERIALIZED VIEW CONCURRENTLY
CREATE UNIQUE INDEX ux_vm_template_sst_docs_summary_tenant
    ON vm_template_sst_docs_summary (id_tenant);
-- columna de filtro/orden mas frecuente en las consultas de indicadores
CREATE INDEX ix_vm_template_sst_docs_summary_pct
    ON vm_template_sst_docs_summary (compliance_percentage);

COMMENT ON MATERIALIZED VIEW vm_template_sst_docs_summary IS
    'Resumen consolidado de documentos del sistema SST por empresa (total/finalizados/borrador/pendientes/no iniciados/porcentaje)';

-- ---------------------------------------------------------------------
-- 8. vm_template_pesv_docs_summary
--    Igual que la anterior, pero para el sistema PESV.
-- ---------------------------------------------------------------------
CREATE MATERIALIZED VIEW vm_template_pesv_docs_summary AS
SELECT
    t.id_tenant,
    t.tenant_nit,
    t.tenant_name,
    COUNT(*)                                                  AS total_docs,
    COUNT(*) FILTER (WHERE d.document_status = 'finalizado')  AS finalized_docs,
    COUNT(*) FILTER (WHERE d.document_status = 'borrador')    AS draft_docs,
    COUNT(*) FILTER (WHERE d.document_status = 'pendiente')   AS pending_docs,
    COUNT(*) FILTER (WHERE d.id_document IS NULL)             AS not_started_docs,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE d.document_status = 'finalizado') / NULLIF(COUNT(*), 0),
        2
    ) AS compliance_percentage,
    now() AS calculated_at
FROM tenants t
JOIN tenanttemplates tt ON tt.id_tenant = t.id_tenant AND tt.is_active
JOIN templates tpl      ON tpl.id_template = tt.id_template
JOIN formats_sst f      ON f.id_format_sst = tpl.id_format_sst
JOIN modules m           ON m.id_module = f.id_module
JOIN type_system_sst ts  ON ts.id_type_system_sst = m.id_type_system_sst AND ts.system_code = 'PESV'
LEFT JOIN documents d    ON d.id_tenant_template = tt.id_tenant_template
GROUP BY t.id_tenant, t.tenant_nit, t.tenant_name
WITH DATA;

CREATE UNIQUE INDEX ux_vm_template_pesv_docs_summary_tenant
    ON vm_template_pesv_docs_summary (id_tenant);
CREATE INDEX ix_vm_template_pesv_docs_summary_pct
    ON vm_template_pesv_docs_summary (compliance_percentage);

COMMENT ON MATERIALIZED VIEW vm_template_pesv_docs_summary IS
    'Resumen consolidado de documentos del sistema PESV por empresa (total/finalizados/borrador/pendientes/no iniciados/porcentaje)';

COMMIT;

-- =====================================================================
-- Verificacion rapida
-- =====================================================================
\echo === vw_tenant_persons (muestra) ===
SELECT tenant_name, full_name, position_name FROM vw_tenant_persons ORDER BY tenant_name LIMIT 5;

\echo === vw_tenant_summary ===
SELECT * FROM vw_tenant_summary ORDER BY tenant_name;

\echo === vm_template_sst_docs_summary ===
SELECT * FROM vm_template_sst_docs_summary ORDER BY tenant_name;

\echo === vm_template_pesv_docs_summary ===
SELECT * FROM vm_template_pesv_docs_summary ORDER BY tenant_name;
