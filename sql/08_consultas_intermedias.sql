-- =====================================================================
--  Examen SST/PESV - Consultas SQL intermedias (enunciado, seccion 2)
--  INNER JOIN, LEFT JOIN, funciones agregadas, GROUP BY, HAVING.
-- =====================================================================

-- 1. Personas con su nombre completo y la organizacion a la que pertenecen.
SELECT p.first_name || ' ' || p.last_name AS nombre_completo, t.tenant_name
FROM persons p
JOIN tenants t ON t.id_tenant = p.id_tenant
ORDER BY t.tenant_name, nombre_completo;

-- 2. Cada persona junto con el cargo que desempena (LEFT JOIN: puede no tener cargo).
SELECT p.first_name || ' ' || p.last_name AS nombre_completo, po.position_name
FROM persons p
LEFT JOIN positions po ON po.id_position = p.id_position
ORDER BY nombre_completo;

-- 3. Cada organizacion junto con el tamano de empresa que tiene asignado.
SELECT t.tenant_name, ts.tenant_size_name
FROM tenants t
JOIN tenant_sizes ts ON ts.id_tenant_size = t.id_tenant_size
ORDER BY t.tenant_name;

-- 4. Cada organizacion con ciudad, departamento y pais.
SELECT t.tenant_name, m.municipality_name, d.department_name, c.country_name
FROM tenants t
JOIN municipalities m ON m.id_municipality = t.id_municipality
JOIN departments d    ON d.id_department = m.id_department
JOIN countries c      ON c.id_country = d.id_country
ORDER BY t.tenant_name;

-- 5. Cuantas personas hay registradas en cada organizacion.
SELECT t.tenant_name, COUNT(p.id_person) AS total_personas
FROM tenants t
LEFT JOIN persons p ON p.id_tenant = t.id_tenant
GROUP BY t.tenant_name
ORDER BY t.tenant_name;

-- 6. Organizaciones con mas de una cantidad determinada de personas (ej. mas de 2).
SELECT t.tenant_name, COUNT(p.id_person) AS total_personas
FROM tenants t
JOIN persons p ON p.id_tenant = t.id_tenant
GROUP BY t.tenant_name
HAVING COUNT(p.id_person) > 2
ORDER BY total_personas DESC;

-- 7. Modulos habilitados para cada organizacion (tenant_modules).
SELECT t.tenant_name, m.module_title
FROM tenant_modules tm
JOIN tenants t  ON t.id_tenant = tm.id_tenant
JOIN modules m  ON m.id_module = tm.id_module
WHERE tm.is_enabled
ORDER BY t.tenant_name, m.module_title;

-- 8. Cuantos modulos tiene habilitados cada organizacion.
SELECT t.tenant_name, COUNT(tm.id_module) AS total_modulos
FROM tenants t
JOIN tenant_modules tm ON tm.id_tenant = t.id_tenant AND tm.is_enabled
GROUP BY t.tenant_name
ORDER BY t.tenant_name;

-- 9. Sistemas SST habilitados para cada organizacion (tenantsystems + type_system_sst).
SELECT t.tenant_name, ts.system_name
FROM tenantsystems tsy
JOIN tenants t          ON t.id_tenant = tsy.id_tenant
JOIN type_system_sst ts ON ts.id_type_system_sst = tsy.id_type_system_sst
WHERE tsy.is_active
ORDER BY t.tenant_name, ts.system_name;

-- 10. Modulos existentes junto con el sistema SST al que pertenecen.
SELECT m.module_title, ts.system_name
FROM modules m
JOIN type_system_sst ts ON ts.id_type_system_sst = m.id_type_system_sst
ORDER BY ts.system_name, m.module_order;

-- 11. Formatos registrados, mostrando el modulo al que pertenece cada uno.
SELECT f.format_name, m.module_title
FROM formats_sst f
JOIN modules m ON m.id_module = f.id_module
ORDER BY m.module_title, f.format_name;

-- 12. Cuantos formatos se encuentran asociados a cada modulo.
SELECT m.module_title, COUNT(f.id_format_sst) AS total_formatos
FROM modules m
JOIN formats_sst f ON f.id_module = m.id_module
GROUP BY m.module_title
ORDER BY m.module_title;

-- 13. Plantillas asignadas a cada organizacion (tenanttemplates).
SELECT t.tenant_name, tp.template_name
FROM tenanttemplates tt
JOIN tenants t     ON t.id_tenant = tt.id_tenant
JOIN templates tp  ON tp.id_template = tt.id_template
ORDER BY t.tenant_name, tp.template_name;

-- 14. Cada plantilla asignada, indicando organizacion, sistema SST y etapa PHVA.
SELECT t.tenant_name, tp.template_name, ts.system_name, ph.phva_stage_name
FROM tenanttemplates tt
JOIN tenants t           ON t.id_tenant = tt.id_tenant
JOIN templates tp        ON tp.id_template = tt.id_template
JOIN formats_sst f       ON f.id_format_sst = tp.id_format_sst
JOIN modules m           ON m.id_module = f.id_module
JOIN type_system_sst ts  ON ts.id_type_system_sst = m.id_type_system_sst
JOIN phva_stages ph      ON ph.id_phva_stage = f.id_phva_stage
ORDER BY t.tenant_name, ph.phva_stage_order;

-- 15. Cuantas plantillas tiene asignada cada organizacion.
SELECT t.tenant_name, COUNT(tt.id_tenant_template) AS total_plantillas
FROM tenants t
LEFT JOIN tenanttemplates tt ON tt.id_tenant = t.id_tenant
GROUP BY t.tenant_name
ORDER BY t.tenant_name;

-- 16. Organizaciones sin personas registradas (combinacion externa tenants/persons).
SELECT t.tenant_name
FROM tenants t
LEFT JOIN persons p ON p.id_tenant = t.id_tenant
WHERE p.id_person IS NULL;

-- 17. Modulos que todavia no han sido asignados a ninguna organizacion.
SELECT m.module_title
FROM modules m
LEFT JOIN tenant_modules tm ON tm.id_module = m.id_module
WHERE tm.id_module IS NULL;

-- 18. Etapas PHVA con el numero de plantillas (del catalogo) asociadas a cada una.
SELECT ph.phva_stage_name, COUNT(tp.id_template) AS total_plantillas
FROM phva_stages ph
JOIN formats_sst f ON f.id_phva_stage = ph.id_phva_stage
JOIN templates tp  ON tp.id_format_sst = f.id_format_sst
GROUP BY ph.phva_stage_name, ph.phva_stage_order
ORDER BY ph.phva_stage_order;

-- 19. Cuantas organizaciones estan registradas en cada municipio.
SELECT m.municipality_name, COUNT(t.id_tenant) AS total_organizaciones
FROM municipalities m
JOIN tenants t ON t.id_municipality = m.id_municipality
GROUP BY m.municipality_name
ORDER BY m.municipality_name;

-- 20. Cargos de cada organizacion y cuantas personas ocupan cada uno.
SELECT t.tenant_name, po.position_name, COUNT(p.id_person) AS total_personas
FROM positions po
JOIN tenants t ON t.id_tenant = po.id_tenant
LEFT JOIN persons p ON p.id_position = po.id_position
GROUP BY t.tenant_name, po.position_name
ORDER BY t.tenant_name, po.position_name;
