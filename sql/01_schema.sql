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
