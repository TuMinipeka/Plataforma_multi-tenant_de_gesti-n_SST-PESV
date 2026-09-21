-- =====================================================================
--  Examen SST/PESV - Consultas SQL basicas (enunciado, seccion 1)
--  Ninguna usa JOIN: cada una resuelve contra una sola tabla.
--  Repaso teorico en docs/06_repaso_consultas_basicas.md
-- =====================================================================

-- 1. Todos los registros de tenants.
SELECT * FROM tenants;

-- 2. Nombre, correo de contacto y telefono de todas las organizaciones.
SELECT tenant_name, contact_email, contact_phone
FROM tenants;

-- 3. Personas: nombres, apellidos y correo electronico.
SELECT first_name, last_name, person_email
FROM persons;

-- 4. Personas cuyo estado se encuentre activo.
SELECT *
FROM persons
WHERE is_active = TRUE;

-- 5. Organizaciones cuyo nombre contenga una palabra dada (ej. "Valle").
SELECT *
FROM tenants
WHERE tenant_name LIKE '%Valle%';

-- 6. Todos los paises, ordenados alfabeticamente por nombre.
SELECT *
FROM countries
ORDER BY country_name;

-- 7. Departamentos/regiones de un pais determinado (id_country = 1).
SELECT *
FROM departments
WHERE id_country = 1;

-- 8. Municipios/ciudades de un departamento especifico (id_department = 1).
SELECT *
FROM municipalities
WHERE id_department = 1;

-- 9. Todos los cargos, ordenados por descripcion.
SELECT *
FROM positions
ORDER BY position_name;

-- 10. Personas de una organizacion determinada (identificador de empresa = 3).
SELECT *
FROM persons
WHERE id_tenant = 3;

-- 11. Organizaciones actualmente habilitadas/activas.
SELECT *
FROM tenants
WHERE is_active = TRUE;

-- 12. Organizaciones registradas dentro de un periodo, por fecha de creacion.
SELECT *
FROM tenants
WHERE created_at BETWEEN CURRENT_DATE - INTERVAL '1 year' AND CURRENT_DATE + INTERVAL '1 day';

-- 13. Diferentes tamanos de empresa.
SELECT *
FROM tenant_sizes;

-- 14. Diferentes tipos de sistemas SST registrados.
SELECT *
FROM type_system_sst;

-- 15. Modulos: titulo, descripcion y orden de presentacion.
SELECT module_title, module_description, module_order
FROM modules
ORDER BY module_order;

-- =====================================================================
-- Variantes que cubren DISTINCT / IN / IS NULL (no pedidas literalmente
-- por una pregunta especifica, pero exigidas por el enunciado como
-- conceptos a dominar en esta seccion).
-- =====================================================================

-- DISTINCT: tamanos de empresa que realmente tienen al menos una organizacion.
SELECT DISTINCT id_tenant_size
FROM tenants;

-- IN: organizaciones de tamano MICRO o SMALL (id_tenant_size 1 o 2).
SELECT tenant_name, id_tenant_size
FROM tenants
WHERE id_tenant_size IN (1, 2);

-- IS NULL: personas que todavia no tienen cargo asignado.
SELECT first_name, last_name
FROM persons
WHERE id_position IS NULL;
