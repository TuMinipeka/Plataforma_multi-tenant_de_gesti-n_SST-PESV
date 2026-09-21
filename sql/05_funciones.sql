-- =====================================================================
--  Examen SST/PESV - Funciones almacenadas (enunciado, seccion 6)
--  Diferencia con los procedimientos: una funcion siempre RETURN-a un
--  valor (o una tabla) y se usa dentro de un SELECT; un procedimiento
--  se invoca con CALL y no se puede usar dentro de una consulta.
--
--  Debajo de cada funcion hay una llamada de prueba (solo SELECT, no
--  modifica datos) que demuestra que funciona correctamente.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Cantidad total de personas asociadas a una organizacion.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_total_personas_tenant(p_id_tenant INT)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_total INT;
BEGIN
    SELECT COUNT(*) INTO v_total FROM persons WHERE id_tenant = p_id_tenant;
    RETURN v_total;
END;
$$;

-- Prueba: personas registradas en Constructora Andina
SELECT fn_total_personas_tenant(
    (SELECT id_tenant FROM tenants WHERE tenant_nit = '900111222-3')
) AS total_personas;

-- ---------------------------------------------------------------------
-- 2. Porcentaje de cumplimiento documental de una organizacion
--    (documentos finalizados sobre el total de documentos generados).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_porcentaje_cumplimiento_tenant(p_id_tenant INT)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_finalizados INT;
    v_total       INT;
BEGIN
    SELECT COUNT(*) FILTER (WHERE d.document_status = 'finalizado'), COUNT(*)
      INTO v_finalizados, v_total
    FROM tenanttemplates tt
    JOIN documents d ON d.id_tenant_template = tt.id_tenant_template
    WHERE tt.id_tenant = p_id_tenant;

    IF v_total = 0 THEN
        RETURN 0;
    END IF;

    RETURN ROUND(100.0 * v_finalizados / v_total, 2);
END;
$$;

-- Prueba: porcentaje de cumplimiento de Transportes del Valle
SELECT fn_porcentaje_cumplimiento_tenant(
    (SELECT id_tenant FROM tenants WHERE tenant_nit = '900333444-5')
) AS porcentaje_cumplimiento;

-- ---------------------------------------------------------------------
-- 3. Determina si una organizacion tiene habilitado un modulo
--    especifico.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_tenant_tiene_modulo(p_id_tenant INT, p_id_module INT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM tenant_modules
        WHERE id_tenant = p_id_tenant AND id_module = p_id_module AND is_enabled
    );
END;
$$;

-- Prueba: Constructora Andina, modulo "Plan de Emergencias" (deberia ser TRUE)
SELECT fn_tenant_tiene_modulo(
    (SELECT id_tenant FROM tenants WHERE tenant_nit = '900111222-3'),
    (SELECT id_module FROM modules WHERE module_title = 'Plan de Emergencias')
) AS tiene_modulo;

-- ---------------------------------------------------------------------
-- 4. Nombre completo de una persona a partir de su identificador.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_nombre_completo_persona(p_id_person INT)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    v_nombre VARCHAR;
BEGIN
    SELECT first_name || ' ' || last_name INTO v_nombre
    FROM persons WHERE id_person = p_id_person;

    IF v_nombre IS NULL THEN
        RAISE EXCEPTION 'No existe una persona con id_person = %', p_id_person;
    END IF;

    RETURN v_nombre;
END;
$$;

-- Prueba: nombre completo de la persona con documento 71234567
SELECT fn_nombre_completo_persona(
    (SELECT id_person FROM persons WHERE person_identification = '71234567')
) AS nombre_completo;

-- ---------------------------------------------------------------------
-- 5. Cantidad de plantillas existentes para una organizacion y una
--    etapa PHVA determinada.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_total_plantillas_tenant_etapa(p_id_tenant INT, p_id_phva_stage INT)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_total INT;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM tenanttemplates tt
    JOIN templates tp  ON tp.id_template = tt.id_template
    JOIN formats_sst f ON f.id_format_sst = tp.id_format_sst
    WHERE tt.id_tenant = p_id_tenant AND f.id_phva_stage = p_id_phva_stage;

    RETURN v_total;
END;
$$;

-- Prueba: plantillas de Textiles Bogota en la etapa "Planear"
SELECT fn_total_plantillas_tenant_etapa(
    (SELECT id_tenant FROM tenants WHERE tenant_nit = '900555666-7'),
    (SELECT id_phva_stage FROM phva_stages WHERE phva_stage_code = 'P')
) AS total_plantillas_etapa_p;

-- ---------------------------------------------------------------------
-- 6. Funcion tabular: todos los modulos habilitados para una
--    organizacion.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_modulos_habilitados_tenant(p_id_tenant INT)
RETURNS TABLE (id_module INT, module_title VARCHAR)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT m.id_module, m.module_title
    FROM tenant_modules tm
    JOIN modules m ON m.id_module = tm.id_module
    WHERE tm.id_tenant = p_id_tenant AND tm.is_enabled
    ORDER BY m.module_title;
END;
$$;

-- Prueba: modulos habilitados de Constructora Andina
SELECT * FROM fn_modulos_habilitados_tenant(
    (SELECT id_tenant FROM tenants WHERE tenant_nit = '900111222-3')
);

-- ---------------------------------------------------------------------
-- 7. Funcion tabular: personas de una organizacion junto con sus
--    respectivos cargos.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_personas_cargos_tenant(p_id_tenant INT)
RETURNS TABLE (id_person INT, full_name VARCHAR, position_name VARCHAR)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT p.id_person, (p.first_name || ' ' || p.last_name)::VARCHAR, po.position_name
    FROM persons p
    LEFT JOIN positions po ON po.id_position = p.id_position
    WHERE p.id_tenant = p_id_tenant
    ORDER BY p.first_name;
END;
$$;

-- Prueba: personas y cargos de Transportes del Valle
SELECT * FROM fn_personas_cargos_tenant(
    (SELECT id_tenant FROM tenants WHERE tenant_nit = '900333444-5')
);

-- ---------------------------------------------------------------------
-- 8. Clasifica el nivel de cumplimiento de una organizacion como
--    bajo, medio o alto, reutilizando la funcion 2.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_nivel_cumplimiento_tenant(p_id_tenant INT)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    v_porcentaje NUMERIC;
BEGIN
    v_porcentaje := fn_porcentaje_cumplimiento_tenant(p_id_tenant);

    IF v_porcentaje < 40 THEN
        RETURN 'Bajo';
    ELSIF v_porcentaje < 70 THEN
        RETURN 'Medio';
    ELSE
        RETURN 'Alto';
    END IF;
END;
$$;

-- Prueba: nivel de cumplimiento de las 4 empresas, de una vez
SELECT tenant_name, fn_nivel_cumplimiento_tenant(id_tenant) AS nivel_cumplimiento
FROM tenants
ORDER BY tenant_name;
