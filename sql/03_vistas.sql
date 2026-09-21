-- =====================================================================
--  Examen SST/PESV - Paso 4: Vistas y vistas materializadas
--  Base de datos : examen   (esquema public)
--  Cubre la seccion "Consultas orientadas a vistas y vistas materializadas"
--  del enunciado (items 1-8) y sirve de base a las avanzadas 10, 22 y 25.
--
--  Debajo de cada vista hay una consulta de prueba (solo SELECT, no
--  modifica datos) que la usa, para comprobar que funciona correctamente.
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

-- Prueba: personas de Constructora Andina con su cargo
SELECT full_name, position_name
FROM vw_tenant_persons
WHERE tenant_nit = '900111222-3'
ORDER BY full_name;

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

-- Prueba: ubicacion de todas las empresas
SELECT tenant_name, municipality_name, department_name, country_name
FROM vw_tenant_geography
ORDER BY tenant_name;

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

-- Prueba: modulos SST habilitados para Transportes del Valle
SELECT module_title, is_enabled
FROM vw_tenant_modules
WHERE tenant_name = 'Transportes del Valle Ltda' AND system_code = 'SST'
ORDER BY module_title;

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

-- Prueba: plantillas por etapa PHVA de todas las empresas
SELECT tenant_name, phva_stage_name, total_templates
FROM vw_tenant_templates_phva
ORDER BY tenant_name, phva_stage_name;

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

-- Prueba: cargos y cuantas personas tiene cada uno, por empresa
SELECT tenant_name, position_name, total_persons
FROM vw_tenant_positions
ORDER BY tenant_name, position_name;

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

-- Prueba: resumen de las 4 empresas
SELECT tenant_name, is_active, total_persons, total_modules, total_templates, total_systems
FROM vw_tenant_summary
ORDER BY tenant_name;

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

-- Prueba: cumplimiento SST de todas las empresas, de menor a mayor
SELECT tenant_name, total_docs, finalized_docs, compliance_percentage
FROM vm_template_sst_docs_summary
ORDER BY compliance_percentage;

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

-- Prueba: cumplimiento PESV de todas las empresas, de mayor a menor
SELECT tenant_name, total_docs, finalized_docs, compliance_percentage
FROM vm_template_pesv_docs_summary
ORDER BY compliance_percentage DESC;

COMMIT;

-- =====================================================================
-- Verificacion rapida (resumen de todo lo anterior en un solo bloque)
-- =====================================================================
\echo === vw_tenant_persons (muestra) ===
SELECT tenant_name, full_name, position_name FROM vw_tenant_persons ORDER BY tenant_name LIMIT 5;

\echo === vw_tenant_summary ===
SELECT * FROM vw_tenant_summary ORDER BY tenant_name;

\echo === vm_template_sst_docs_summary ===
SELECT * FROM vm_template_sst_docs_summary ORDER BY tenant_name;

\echo === vm_template_pesv_docs_summary ===
SELECT * FROM vm_template_pesv_docs_summary ORDER BY tenant_name;
