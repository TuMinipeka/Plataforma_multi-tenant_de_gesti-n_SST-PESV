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
