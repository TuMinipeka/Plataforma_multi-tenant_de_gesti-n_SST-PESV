-- =====================================================================
--  Examen SST/PESV - Consultas orientadas a vistas y vistas materializadas
--  (enunciado, seccion 4). Las vistas ya se crean en 03_vistas.sql; este
--  archivo es la consulta que responde cada item apoyandose en ellas.
-- =====================================================================

-- 1. Vista vw_tenant_persons: organizaciones con sus personas y cargos.
SELECT * FROM vw_tenant_persons ORDER BY tenant_name;

-- 2. Vista vw_tenant_geography: informacion geografica consolidada.
SELECT * FROM vw_tenant_geography ORDER BY tenant_name;

-- 3. Vista vw_tenant_modules: modulos habilitados por organizacion y su sistema SST.
SELECT * FROM vw_tenant_modules ORDER BY tenant_name, module_title;

-- 4. Vista vw_tenant_templates_phva: total de plantillas por organizacion y etapa PHVA.
SELECT * FROM vw_tenant_templates_phva ORDER BY tenant_name, phva_stage_code;

-- 5. Vista vw_tenant_positions: total de personas por organizacion y cargo.
SELECT * FROM vw_tenant_positions ORDER BY tenant_name, position_name;

-- 6. Vistas materializadas vm_template_sst_docs_summary / vm_template_pesv_docs_summary:
--    documentos totales, finalizados, pendientes y porcentaje de cumplimiento.
SELECT 'SST' AS sistema, * FROM vm_template_sst_docs_summary
UNION ALL
SELECT 'PESV' AS sistema, * FROM vm_template_pesv_docs_summary
ORDER BY sistema, tenant_name;

-- 7. Actualizar las vistas materializadas y verificar que reflejan los ultimos cambios.
--    Ejemplo: se finaliza un documento y se refresca la vista.
-- UPDATE documents SET document_status = 'finalizado', finalized_at = now()
--     WHERE id_document = 2;
REFRESH MATERIALIZED VIEW CONCURRENTLY vm_template_sst_docs_summary;
REFRESH MATERIALIZED VIEW CONCURRENTLY vm_template_pesv_docs_summary;
SELECT tenant_name, total_docs, finalized_docs, compliance_percentage, calculated_at
FROM vm_template_sst_docs_summary
ORDER BY tenant_name;

-- 8. Columnas que conviene indexar para las consultas de seguimiento por organizacion.
--    Ya implementado en 03_vistas.sql:
--      - id_tenant     -> indice UNICO (ux_vm_..._tenant): exigido por REFRESH CONCURRENTLY
--                         y es la columna por la que siempre se filtra/agrupa por empresa.
--      - compliance_percentage -> indice normal (ix_vm_..._pct): columna usada para
--                         ordenar/filtrar en las avanzadas 11-14 (ranking, promedio, clasificacion).
--    Verificacion de los indices ya creados sobre las vistas materializadas:
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename IN ('vm_template_sst_docs_summary', 'vm_template_pesv_docs_summary')
ORDER BY tablename, indexname;
