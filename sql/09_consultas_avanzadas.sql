-- =====================================================================
--  Examen SST/PESV - Consultas SQL avanzadas (enunciado, seccion 3)
--  Subconsultas, CTE, funciones de ventana, agregaciones condicionales.
-- =====================================================================

-- 1. Organizacion con la mayor cantidad de personas registradas.
SELECT t.tenant_name, COUNT(p.id_person) AS total_personas
FROM tenants t
JOIN persons p ON p.id_tenant = t.id_tenant
GROUP BY t.tenant_name
ORDER BY total_personas DESC
LIMIT 1;

-- 2. Organizaciones con mas personas que el promedio general de personas por organizacion.
SELECT t.tenant_name, COUNT(p.id_person) AS total_personas
FROM tenants t
JOIN persons p ON p.id_tenant = t.id_tenant
GROUP BY t.tenant_name
HAVING COUNT(p.id_person) > (
    SELECT AVG(cnt)
    FROM (SELECT COUNT(*) AS cnt FROM persons GROUP BY id_tenant) sub
)
ORDER BY total_personas DESC;

-- 3. Organizaciones que tienen habilitados TODOS los modulos de un sistema (ej. SST).
SELECT t.tenant_name
FROM tenants t
JOIN tenant_modules tm  ON tm.id_tenant = t.id_tenant AND tm.is_enabled
JOIN modules m          ON m.id_module = tm.id_module
JOIN type_system_sst ts ON ts.id_type_system_sst = m.id_type_system_sst AND ts.system_code = 'SST'
GROUP BY t.tenant_name
HAVING COUNT(DISTINCT m.id_module) = (
    SELECT COUNT(*)
    FROM modules mm
    JOIN type_system_sst tss ON tss.id_type_system_sst = mm.id_type_system_sst
    WHERE tss.system_code = 'SST'
);

-- 4. Organizaciones con al menos un modulo configurado pero sin plantillas asignadas.
SELECT DISTINCT t.tenant_name
FROM tenants t
JOIN tenant_modules tm ON tm.id_tenant = t.id_tenant
LEFT JOIN tenanttemplates tt ON tt.id_tenant = t.id_tenant
WHERE tt.id_tenant_template IS NULL;

-- 5. Organizaciones con plantillas asociadas a TODAS las etapas PHVA disponibles.
SELECT t.tenant_name
FROM tenants t
JOIN tenanttemplates tt ON tt.id_tenant = t.id_tenant
JOIN templates tp       ON tp.id_template = tt.id_template
JOIN formats_sst f      ON f.id_format_sst = tp.id_format_sst
GROUP BY t.tenant_name
HAVING COUNT(DISTINCT f.id_phva_stage) = (SELECT COUNT(*) FROM phva_stages);

-- 6. Cantidad de plantillas asignadas a cada organizacion, discriminadas por etapa PHVA.
SELECT t.tenant_name, ph.phva_stage_name, COUNT(*) AS total_plantillas
FROM tenanttemplates tt
JOIN tenants t      ON t.id_tenant = tt.id_tenant
JOIN templates tp   ON tp.id_template = tt.id_template
JOIN formats_sst f  ON f.id_format_sst = tp.id_format_sst
JOIN phva_stages ph ON ph.id_phva_stage = f.id_phva_stage
GROUP BY t.tenant_name, ph.phva_stage_name, ph.phva_stage_order
ORDER BY t.tenant_name, ph.phva_stage_order;

-- 7. La misma informacion anterior, pivotada en columnas P / H / V / A.
SELECT
    t.tenant_name,
    SUM(CASE WHEN ph.phva_stage_code = 'P' THEN 1 ELSE 0 END) AS planear,
    SUM(CASE WHEN ph.phva_stage_code = 'H' THEN 1 ELSE 0 END) AS hacer,
    SUM(CASE WHEN ph.phva_stage_code = 'V' THEN 1 ELSE 0 END) AS verificar,
    SUM(CASE WHEN ph.phva_stage_code = 'A' THEN 1 ELSE 0 END) AS actuar
FROM tenanttemplates tt
JOIN tenants t      ON t.id_tenant = tt.id_tenant
JOIN templates tp   ON tp.id_template = tt.id_template
JOIN formats_sst f  ON f.id_format_sst = tp.id_format_sst
JOIN phva_stages ph ON ph.id_phva_stage = f.id_phva_stage
GROUP BY t.tenant_name
ORDER BY t.tenant_name;

-- 8. Porcentaje que representa cada etapa PHVA sobre el total de plantillas de una organizacion.
SELECT
    t.tenant_name,
    ph.phva_stage_name,
    COUNT(*) AS total_etapa,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY t.tenant_name), 2) AS porcentaje
FROM tenanttemplates tt
JOIN tenants t      ON t.id_tenant = tt.id_tenant
JOIN templates tp   ON tp.id_template = tt.id_template
JOIN formats_sst f  ON f.id_format_sst = tp.id_format_sst
JOIN phva_stages ph ON ph.id_phva_stage = f.id_phva_stage
GROUP BY t.tenant_name, ph.phva_stage_name
ORDER BY t.tenant_name, ph.phva_stage_name;

-- 9. Etapa PHVA con la mayor cantidad de plantillas dentro de cada organizacion.
SELECT tenant_name, phva_stage_name, total_etapa
FROM (
    SELECT
        t.tenant_name,
        ph.phva_stage_name,
        COUNT(*) AS total_etapa,
        ROW_NUMBER() OVER (PARTITION BY t.tenant_name ORDER BY COUNT(*) DESC) AS posicion
    FROM tenanttemplates tt
    JOIN tenants t      ON t.id_tenant = tt.id_tenant
    JOIN templates tp   ON tp.id_template = tt.id_template
    JOIN formats_sst f  ON f.id_format_sst = tp.id_format_sst
    JOIN phva_stages ph ON ph.id_phva_stage = f.id_phva_stage
    GROUP BY t.tenant_name, ph.phva_stage_name
) ranking
WHERE posicion = 1
ORDER BY tenant_name;

-- 10. Porcentaje de documentos finalizados frente al total, por organizacion
--     (SST y PESV combinados), usando las vistas de resumen.
SELECT
    tenant_name,
    SUM(total_docs) AS total_docs,
    SUM(finalized_docs) AS finalized_docs,
    ROUND(100.0 * SUM(finalized_docs) / NULLIF(SUM(total_docs), 0), 2) AS compliance_percentage
FROM (
    SELECT tenant_name, total_docs, finalized_docs FROM vm_template_sst_docs_summary
    UNION ALL
    SELECT tenant_name, total_docs, finalized_docs FROM vm_template_pesv_docs_summary
) combinado
GROUP BY tenant_name
ORDER BY tenant_name;

-- 11. Organizaciones cuyo porcentaje de cumplimiento esta por debajo del promedio general.
WITH resumen AS (
    SELECT
        tenant_name,
        ROUND(100.0 * SUM(finalized_docs) / NULLIF(SUM(total_docs), 0), 2) AS compliance_percentage
    FROM (
        SELECT tenant_name, total_docs, finalized_docs FROM vm_template_sst_docs_summary
        UNION ALL
        SELECT tenant_name, total_docs, finalized_docs FROM vm_template_pesv_docs_summary
    ) combinado
    GROUP BY tenant_name
)
SELECT tenant_name, compliance_percentage
FROM resumen
WHERE compliance_percentage < (SELECT AVG(compliance_percentage) FROM resumen)
ORDER BY compliance_percentage;

-- 12. Clasificacion de organizaciones por nivel de cumplimiento (bajo / medio / alto).
WITH resumen AS (
    SELECT
        tenant_name,
        ROUND(100.0 * SUM(finalized_docs) / NULLIF(SUM(total_docs), 0), 2) AS compliance_percentage
    FROM (
        SELECT tenant_name, total_docs, finalized_docs FROM vm_template_sst_docs_summary
        UNION ALL
        SELECT tenant_name, total_docs, finalized_docs FROM vm_template_pesv_docs_summary
    ) combinado
    GROUP BY tenant_name
)
SELECT
    tenant_name,
    compliance_percentage,
    CASE
        WHEN compliance_percentage < 40 THEN 'Bajo'
        WHEN compliance_percentage < 70 THEN 'Medio'
        ELSE 'Alto'
    END AS nivel_cumplimiento
FROM resumen
ORDER BY compliance_percentage DESC;

-- 13. Ranking de organizaciones segun su porcentaje de cumplimiento (funcion de ventana).
WITH resumen AS (
    SELECT
        tenant_name,
        ROUND(100.0 * SUM(finalized_docs) / NULLIF(SUM(total_docs), 0), 2) AS compliance_percentage
    FROM (
        SELECT tenant_name, total_docs, finalized_docs FROM vm_template_sst_docs_summary
        UNION ALL
        SELECT tenant_name, total_docs, finalized_docs FROM vm_template_pesv_docs_summary
    ) combinado
    GROUP BY tenant_name
)
SELECT
    tenant_name,
    compliance_percentage,
    RANK() OVER (ORDER BY compliance_percentage DESC) AS ranking
FROM resumen
ORDER BY ranking;

-- 14. Porcentaje de cumplimiento de cada organizacion y su diferencia frente al promedio general.
WITH resumen AS (
    SELECT
        tenant_name,
        ROUND(100.0 * SUM(finalized_docs) / NULLIF(SUM(total_docs), 0), 2) AS compliance_percentage
    FROM (
        SELECT tenant_name, total_docs, finalized_docs FROM vm_template_sst_docs_summary
        UNION ALL
        SELECT tenant_name, total_docs, finalized_docs FROM vm_template_pesv_docs_summary
    ) combinado
    GROUP BY tenant_name
)
SELECT
    tenant_name,
    compliance_percentage,
    ROUND(AVG(compliance_percentage) OVER (), 2) AS promedio_general,
    ROUND(compliance_percentage - AVG(compliance_percentage) OVER (), 2) AS diferencia
FROM resumen
ORDER BY tenant_name;

-- 15. Cantidad acumulada de documentos finalizados por organizacion (funcion de ventana).
WITH resumen AS (
    SELECT tenant_name, SUM(finalized_docs) AS finalized_docs
    FROM (
        SELECT tenant_name, finalized_docs FROM vm_template_sst_docs_summary
        UNION ALL
        SELECT tenant_name, finalized_docs FROM vm_template_pesv_docs_summary
    ) combinado
    GROUP BY tenant_name
)
SELECT
    tenant_name,
    finalized_docs,
    SUM(finalized_docs) OVER (ORDER BY tenant_name) AS acumulado
FROM resumen
ORDER BY tenant_name;

-- 16. Organizaciones que comparten el mismo municipio pero tienen distinto tamano empresarial.
SELECT
    t1.tenant_name AS organizacion_1,
    t2.tenant_name AS organizacion_2,
    m.municipality_name
FROM tenants t1
JOIN tenants t2        ON t1.id_municipality = t2.id_municipality AND t1.id_tenant < t2.id_tenant
JOIN municipalities m  ON m.id_municipality = t1.id_municipality
WHERE t1.id_tenant_size <> t2.id_tenant_size;

-- 17. Personas cuyo cargo es ocupado por mas gente que el promedio de ocupacion
--     de los cargos dentro de su propia organizacion.
WITH ocupacion AS (
    SELECT po.id_tenant, po.id_position, COUNT(p.id_person) AS total_ocupantes
    FROM positions po
    JOIN persons p ON p.id_position = po.id_position
    GROUP BY po.id_tenant, po.id_position
),
promedio_tenant AS (
    SELECT id_tenant, AVG(total_ocupantes) AS promedio
    FROM ocupacion
    GROUP BY id_tenant
)
SELECT p.first_name || ' ' || p.last_name AS nombre_completo, t.tenant_name,
       po.position_name, o.total_ocupantes
FROM persons p
JOIN positions po           ON po.id_position = p.id_position
JOIN tenants t               ON t.id_tenant = p.id_tenant
JOIN ocupacion o              ON o.id_position = po.id_position
JOIN promedio_tenant pt       ON pt.id_tenant = p.id_tenant
WHERE o.total_ocupantes > pt.promedio
ORDER BY t.tenant_name;

-- 18. CTE: cantidad de personas por organizacion, y luego solo las que superan el promedio.
WITH personas_por_tenant AS (
    SELECT id_tenant, COUNT(*) AS total_personas
    FROM persons
    GROUP BY id_tenant
)
SELECT t.tenant_name, ppt.total_personas
FROM personas_por_tenant ppt
JOIN tenants t ON t.id_tenant = ppt.id_tenant
WHERE ppt.total_personas > (SELECT AVG(total_personas) FROM personas_por_tenant)
ORDER BY ppt.total_personas DESC;

-- 19. CTE: consolidado de modulos, plantillas y personas por organizacion.
WITH resumen AS (
    SELECT
        t.id_tenant,
        t.tenant_name,
        (SELECT COUNT(*) FROM tenant_modules tm WHERE tm.id_tenant = t.id_tenant AND tm.is_enabled) AS total_modulos,
        (SELECT COUNT(*) FROM tenanttemplates tt WHERE tt.id_tenant = t.id_tenant)                  AS total_plantillas,
        (SELECT COUNT(*) FROM persons p WHERE p.id_tenant = t.id_tenant)                            AS total_personas
    FROM tenants t
)
SELECT tenant_name, total_modulos, total_plantillas, total_personas
FROM resumen
ORDER BY tenant_name;

-- 20. Organizaciones a las que les falta alguna etapa PHVA en sus plantillas asignadas.
SELECT t.tenant_name, ph.phva_stage_name AS etapa_faltante
FROM tenants t
CROSS JOIN phva_stages ph
WHERE NOT EXISTS (
    SELECT 1
    FROM tenanttemplates tt
    JOIN templates tp  ON tp.id_template = tt.id_template
    JOIN formats_sst f ON f.id_format_sst = tp.id_format_sst
    WHERE tt.id_tenant = t.id_tenant AND f.id_phva_stage = ph.id_phva_stage
)
ORDER BY t.tenant_name, ph.phva_stage_name;

-- 21. Ultima fecha de actualizacion registrada por organizacion, segun sus plantillas.
SELECT t.tenant_name, MAX(tt.updated_at) AS ultima_actualizacion
FROM tenants t
JOIN tenanttemplates tt ON tt.id_tenant = t.id_tenant
GROUP BY t.tenant_name
ORDER BY t.tenant_name;

-- 22. Organizaciones con registros documentales pendientes (vm_template_sst / vm_template_pesv).
SELECT tenant_name, 'SST' AS sistema, pending_docs, not_started_docs
FROM vm_template_sst_docs_summary
WHERE pending_docs > 0 OR not_started_docs > 0
UNION ALL
SELECT tenant_name, 'PESV' AS sistema, pending_docs, not_started_docs
FROM vm_template_pesv_docs_summary
WHERE pending_docs > 0 OR not_started_docs > 0
ORDER BY tenant_name;

-- 23. Informe consolidado por organizacion (total, finalizados, borrador, no iniciados,
--     pendientes y porcentaje de cumplimiento), integrando SST y PESV.
SELECT
    tenant_name,
    SUM(total_docs)       AS total_docs,
    SUM(finalized_docs)   AS finalized_docs,
    SUM(draft_docs)       AS draft_docs,
    SUM(not_started_docs) AS not_started_docs,
    SUM(pending_docs)     AS pending_docs,
    ROUND(100.0 * SUM(finalized_docs) / NULLIF(SUM(total_docs), 0), 2) AS compliance_percentage
FROM (
    SELECT tenant_name, total_docs, finalized_docs, draft_docs, not_started_docs, pending_docs
    FROM vm_template_sst_docs_summary
    UNION ALL
    SELECT tenant_name, total_docs, finalized_docs, draft_docs, not_started_docs, pending_docs
    FROM vm_template_pesv_docs_summary
) todo
GROUP BY tenant_name
ORDER BY tenant_name;

-- 24. Comparar cumplimiento SST vs PESV por organizacion; diferencia mayor a 10 puntos.
SELECT
    COALESCE(s.tenant_name, p.tenant_name) AS tenant_name,
    COALESCE(s.compliance_percentage, 0) AS cumplimiento_sst,
    COALESCE(p.compliance_percentage, 0) AS cumplimiento_pesv,
    ABS(COALESCE(s.compliance_percentage, 0) - COALESCE(p.compliance_percentage, 0)) AS diferencia
FROM vm_template_sst_docs_summary s
FULL JOIN vm_template_pesv_docs_summary p ON p.id_tenant = s.id_tenant
WHERE ABS(COALESCE(s.compliance_percentage, 0) - COALESCE(p.compliance_percentage, 0)) > 10
ORDER BY diferencia DESC;

-- 25. Vista que consolide personas, modulos, plantillas y sistemas habilitados
--     por organizacion (ya construida como vw_tenant_summary en 03_vistas.sql).
SELECT * FROM vw_tenant_summary ORDER BY tenant_name;
