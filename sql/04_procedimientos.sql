-- =====================================================================
--  Examen SST/PESV - Procedimientos almacenados (enunciado, seccion 5)
--  PL/pgSQL simple: parametros, variables, IF, RAISE, manejo de
--  excepciones y operaciones transaccionales basicas.
--
--  Debajo de cada procedimiento hay una llamada de prueba envuelta en
--  BEGIN; ... ROLLBACK; para comprobar que funciona sin dejar cambios
--  permanentes (asi el archivo se puede re-ejecutar las veces que haga
--  falta sin ensuciar los datos de prueba). Los identificadores que
--  necesita cada CALL se buscan primero con SELECT ... \gset, porque
--  PostgreSQL no permite subconsultas directamente dentro de los
--  argumentos de un CALL.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Registrar una nueva organizacion, validando que no exista otra
--    con el mismo NIT.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_registrar_tenant(
    p_tenant_nit      VARCHAR,
    p_tenant_name     VARCHAR,
    p_contact_email   VARCHAR,
    p_contact_phone   VARCHAR,
    p_tenant_address  VARCHAR,
    p_id_municipality INT,
    p_id_tenant_size  INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM tenants WHERE tenant_nit = p_tenant_nit) THEN
        RAISE EXCEPTION 'Ya existe una organizacion registrada con el NIT %', p_tenant_nit;
    END IF;

    INSERT INTO tenants (tenant_nit, tenant_name, contact_email, contact_phone, tenant_address,
                          id_municipality, id_tenant_size)
    VALUES (p_tenant_nit, p_tenant_name, p_contact_email, p_contact_phone, p_tenant_address,
            p_id_municipality, p_id_tenant_size);
END;
$$;

-- Prueba: registrar una organizacion nueva y confirmar que quedo
SELECT id_municipality FROM municipalities WHERE municipality_name = 'Medellin' \gset
SELECT id_tenant_size FROM tenant_sizes WHERE tenant_size_code = 'SMALL' \gset
BEGIN;
CALL sp_registrar_tenant(
    '900999000-1', 'Empresa de Prueba SAS', 'contacto@prueba.com', '3000000000', 'Cl 1 # 1-1',
    :id_municipality, :id_tenant_size
);
SELECT tenant_name FROM tenants WHERE tenant_nit = '900999000-1';
ROLLBACK;

-- ---------------------------------------------------------------------
-- 2. Registrar una nueva persona y asociarla a una organizacion y a
--    un cargo determinado.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_registrar_persona(
    p_id_tenant      INT,
    p_id_position    INT,
    p_identification VARCHAR,
    p_first_name     VARCHAR,
    p_last_name      VARCHAR,
    p_email          VARCHAR,
    p_phone          VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO persons (id_tenant, id_position, person_identification, first_name, last_name,
                          person_email, person_phone)
    VALUES (p_id_tenant, p_id_position, p_identification, p_first_name, p_last_name, p_email, p_phone);
END;
$$;

-- Prueba: registrar una persona nueva en Constructora Andina
SELECT id_tenant FROM tenants WHERE tenant_nit = '900111222-3' \gset
SELECT id_position FROM positions WHERE position_name = 'Supervisor de Obra' AND id_tenant = :id_tenant \gset
BEGIN;
CALL sp_registrar_persona(
    :id_tenant, :id_position, '99999999', 'Prueba', 'Apellido', 'prueba@constructoraandina.com.co', '3000000001'
);
SELECT first_name, last_name FROM persons WHERE person_identification = '99999999';
ROLLBACK;

-- ---------------------------------------------------------------------
-- 3. Cambiar el estado de una organizacion entre activa e inactiva.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_cambiar_estado_tenant(
    p_id_tenant INT,
    p_is_active BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE tenants
    SET is_active = p_is_active
    WHERE id_tenant = p_id_tenant;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una organizacion con id_tenant = %', p_id_tenant;
    END IF;
END;
$$;

-- Prueba: reactivar temporalmente a Logistica Rapida (esta inactiva en la semilla)
SELECT id_tenant FROM tenants WHERE tenant_nit = '900777888-9' \gset
BEGIN;
CALL sp_cambiar_estado_tenant(:id_tenant, TRUE);
SELECT tenant_name, is_active FROM tenants WHERE tenant_nit = '900777888-9';
ROLLBACK;

-- ---------------------------------------------------------------------
-- 4. Asignar un modulo a una organizacion, evitando asignaciones
--    duplicadas.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_asignar_modulo(
    p_id_tenant INT,
    p_id_module INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM tenant_modules
        WHERE id_tenant = p_id_tenant AND id_module = p_id_module
    ) THEN
        RAISE EXCEPTION 'El modulo % ya esta asignado a la organizacion %', p_id_module, p_id_tenant;
    END IF;

    INSERT INTO tenant_modules (id_tenant, id_module, is_enabled)
    VALUES (p_id_tenant, p_id_module, TRUE);
END;
$$;

-- Prueba: asignar a Textiles Bogota un modulo PESV que todavia no tiene
SELECT id_tenant FROM tenants WHERE tenant_nit = '900555666-7' \gset
SELECT id_module FROM modules WHERE module_title = 'Plan de Accion PESV' \gset
BEGIN;
CALL sp_asignar_modulo(:id_tenant, :id_module);
SELECT module_title FROM vw_tenant_modules
WHERE tenant_name = 'Textiles Bogota S.A.' AND module_title = 'Plan de Accion PESV';
ROLLBACK;

-- ---------------------------------------------------------------------
-- 5. Habilitar un sistema SST para una organizacion determinada.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_habilitar_sistema(
    p_id_tenant          INT,
    p_id_type_system_sst INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM tenantsystems
        WHERE id_tenant = p_id_tenant AND id_type_system_sst = p_id_type_system_sst
    ) THEN
        RAISE EXCEPTION 'El sistema % ya esta habilitado para la organizacion %', p_id_type_system_sst, p_id_tenant;
    END IF;

    INSERT INTO tenantsystems (id_tenant, id_type_system_sst, is_active)
    VALUES (p_id_tenant, p_id_type_system_sst, TRUE);
END;
$$;

-- Prueba: habilitar PESV en Textiles Bogota (solo tiene SST habilitado)
SELECT id_tenant FROM tenants WHERE tenant_nit = '900555666-7' \gset
SELECT id_type_system_sst FROM type_system_sst WHERE system_code = 'PESV' \gset
BEGIN;
CALL sp_habilitar_sistema(:id_tenant, :id_type_system_sst);
SELECT system_code FROM tenantsystems ts
JOIN type_system_sst s ON s.id_type_system_sst = ts.id_type_system_sst
WHERE ts.id_tenant = :id_tenant;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 6. Asignar una plantilla a una organizacion indicando el formato
--    correspondiente (el sistema y la etapa PHVA se derivan del
--    formato: formats_sst -> modules -> type_system_sst / phva_stages).
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_asignar_plantilla(
    p_id_tenant             INT,
    p_id_format_sst         INT,
    p_id_person_updated_by  INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_template INT;
BEGIN
    SELECT id_template INTO v_id_template
    FROM templates
    WHERE id_format_sst = p_id_format_sst AND is_active
    LIMIT 1;

    IF v_id_template IS NULL THEN
        RAISE EXCEPTION 'El formato % no tiene una plantilla activa', p_id_format_sst;
    END IF;

    INSERT INTO tenanttemplates (id_tenant, id_template, id_person_updated_by)
    VALUES (p_id_tenant, v_id_template, p_id_person_updated_by);
END;
$$;

-- Prueba: asignar a Textiles Bogota la plantilla del formato F-PESV-001
SELECT id_tenant FROM tenants WHERE tenant_nit = '900555666-7' \gset
SELECT id_format_sst FROM formats_sst WHERE format_code = 'F-PESV-001' \gset
SELECT id_person FROM persons WHERE person_identification = '52345678' \gset
BEGIN;
CALL sp_asignar_plantilla(:id_tenant, :id_format_sst, :id_person);
SELECT COUNT(*) FROM tenanttemplates WHERE id_tenant = :id_tenant;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 7. Cambiar el cargo de una persona dentro de su organizacion.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_cambiar_cargo_persona(
    p_id_person   INT,
    p_id_position INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE persons
    SET id_position = p_id_position
    WHERE id_person = p_id_person;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una persona con id_person = %', p_id_person;
    END IF;
END;
$$;

-- Prueba: cambiar el cargo de Jorge Martinez a "Coordinador SST"
SELECT id_person FROM persons WHERE person_identification = '80123456' \gset
SELECT id_position FROM positions WHERE position_name = 'Coordinador SST'
    AND id_tenant = (SELECT id_tenant FROM tenants WHERE tenant_nit = '900111222-3') \gset
BEGIN;
CALL sp_cambiar_cargo_persona(:id_person, :id_position);
SELECT position_name FROM vw_tenant_persons WHERE person_identification = '80123456';
ROLLBACK;

-- ---------------------------------------------------------------------
-- 8. Trasladar una persona de una organizacion a otra, actualizando
--    las relaciones necesarias (el cargo se limpia primero porque el
--    cargo viejo pertenece a la empresa de origen).
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_trasladar_persona(
    p_id_person          INT,
    p_id_tenant_nuevo    INT,
    p_id_position_nuevo  INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE persons SET id_position = NULL WHERE id_person = p_id_person;

    UPDATE persons
    SET id_tenant   = p_id_tenant_nuevo,
        id_position = p_id_position_nuevo
    WHERE id_person = p_id_person;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una persona con id_person = %', p_id_person;
    END IF;
END;
$$;

-- Prueba: trasladar a Luis Torres de Transportes del Valle a Textiles Bogota
SELECT id_person FROM persons WHERE person_identification = '94512345' \gset
SELECT id_tenant FROM tenants WHERE tenant_nit = '900555666-7' \gset
BEGIN;
CALL sp_trasladar_persona(:id_person, :id_tenant, NULL);
SELECT tenant_name FROM vw_tenant_persons WHERE person_identification = '94512345';
ROLLBACK;

-- ---------------------------------------------------------------------
-- 9. Deshabilitar todos los modulos asociados a una organizacion que
--    haya sido marcada como inactiva.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_deshabilitar_modulos_tenant_inactivo(
    p_id_tenant INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF (SELECT is_active FROM tenants WHERE id_tenant = p_id_tenant) THEN
        RAISE EXCEPTION 'La organizacion % todavia esta activa; no se deshabilitan sus modulos', p_id_tenant;
    END IF;

    UPDATE tenant_modules SET is_enabled = FALSE WHERE id_tenant = p_id_tenant;
END;
$$;

-- Prueba: Logistica Rapida ya esta inactiva en la semilla, asi que el
-- procedimiento debe deshabilitar sus modulos sin error
SELECT id_tenant FROM tenants WHERE tenant_nit = '900777888-9' \gset
BEGIN;
CALL sp_deshabilitar_modulos_tenant_inactivo(:id_tenant);
SELECT COUNT(*) FILTER (WHERE is_enabled) AS modulos_aun_habilitados
FROM tenant_modules WHERE id_tenant = :id_tenant;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 10. Eliminar de manera controlada una asignacion de modulo,
--     validando que no existan plantillas dependientes de ese modulo
--     para esa organizacion.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_eliminar_asignacion_modulo(
    p_id_tenant INT,
    p_id_module INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_dependientes INT;
BEGIN
    SELECT COUNT(*) INTO v_dependientes
    FROM tenanttemplates tt
    JOIN templates tp  ON tp.id_template = tt.id_template
    JOIN formats_sst f ON f.id_format_sst = tp.id_format_sst
    WHERE tt.id_tenant = p_id_tenant AND f.id_module = p_id_module;

    IF v_dependientes > 0 THEN
        RAISE EXCEPTION 'No se puede quitar el modulo %: la organizacion % tiene % plantilla(s) asignada(s) de ese modulo',
            p_id_module, p_id_tenant, v_dependientes;
    END IF;

    DELETE FROM tenant_modules WHERE id_tenant = p_id_tenant AND id_module = p_id_module;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La organizacion % no tenia asignado el modulo %', p_id_tenant, p_id_module;
    END IF;
END;
$$;

-- Prueba: quitarle a Textiles Bogota un modulo que no tiene plantillas
-- dependientes (Plan de Emergencias, que Textiles todavia no tenia asignado)
SELECT id_tenant FROM tenants WHERE tenant_nit = '900555666-7' \gset
SELECT id_module FROM modules WHERE module_title = 'Plan de Emergencias' \gset
BEGIN;
CALL sp_asignar_modulo(:id_tenant, :id_module);
CALL sp_eliminar_asignacion_modulo(:id_tenant, :id_module);
SELECT COUNT(*) FROM tenant_modules WHERE id_tenant = :id_tenant AND id_module = :id_module;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 11. Determinar el numero total de plantillas asociadas a una
--     organizacion y mostrar el resultado con RAISE NOTICE.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_contar_plantillas_tenant(
    p_id_tenant INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total INT;
BEGIN
    SELECT COUNT(*) INTO v_total FROM tenanttemplates WHERE id_tenant = p_id_tenant;
    RAISE NOTICE 'La organizacion % tiene % plantilla(s) asignada(s)', p_id_tenant, v_total;
END;
$$;

-- Prueba: contar plantillas de Constructora Andina (mensaje via RAISE NOTICE)
SELECT id_tenant FROM tenants WHERE tenant_nit = '900111222-3' \gset
CALL sp_contar_plantillas_tenant(:id_tenant);

-- ---------------------------------------------------------------------
-- 12. Determinar el porcentaje de cumplimiento documental de una
--     organizacion a partir de sus documentos finalizados y
--     pendientes (parametro de salida).
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_calcular_cumplimiento_tenant(
    p_id_tenant   INT,
    OUT p_porcentaje NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_finalizados INT;
    v_pendientes  INT;
    v_total       INT;
BEGIN
    SELECT COUNT(*) FILTER (WHERE d.document_status = 'finalizado'),
           COUNT(*) FILTER (WHERE d.document_status = 'pendiente')
      INTO v_finalizados, v_pendientes
    FROM tenanttemplates tt
    JOIN documents d ON d.id_tenant_template = tt.id_tenant_template
    WHERE tt.id_tenant = p_id_tenant;

    v_total := v_finalizados + v_pendientes;

    IF v_total = 0 THEN
        p_porcentaje := 0;
    ELSE
        p_porcentaje := ROUND(100.0 * v_finalizados / v_total, 2);
    END IF;

    RAISE NOTICE 'Cumplimiento de la organizacion % (finalizados vs pendientes): % por ciento',
        p_id_tenant, p_porcentaje;
END;
$$;

-- Prueba: cumplimiento de Transportes del Valle (mensaje via RAISE NOTICE)
SELECT id_tenant FROM tenants WHERE tenant_nit = '900333444-5' \gset
CALL sp_calcular_cumplimiento_tenant(:id_tenant, NULL);

-- ---------------------------------------------------------------------
-- 13. Recibir una organizacion y una etapa PHVA y determinar la
--     cantidad de documentos correspondientes a esa etapa.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_documentos_por_etapa(
    p_id_tenant      INT,
    p_id_phva_stage  INT,
    OUT p_total      INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT COUNT(*) INTO p_total
    FROM documents d
    JOIN tenanttemplates tt ON tt.id_tenant_template = d.id_tenant_template
    JOIN templates tp       ON tp.id_template = tt.id_template
    JOIN formats_sst f      ON f.id_format_sst = tp.id_format_sst
    WHERE tt.id_tenant = p_id_tenant AND f.id_phva_stage = p_id_phva_stage;

    RAISE NOTICE 'La organizacion % tiene % documento(s) en la etapa PHVA %',
        p_id_tenant, p_total, p_id_phva_stage;
END;
$$;

-- Prueba: documentos de Constructora Andina en la etapa "Hacer"
SELECT id_tenant FROM tenants WHERE tenant_nit = '900111222-3' \gset
SELECT id_phva_stage FROM phva_stages WHERE phva_stage_code = 'H' \gset
CALL sp_documentos_por_etapa(:id_tenant, :id_phva_stage, NULL);

-- ---------------------------------------------------------------------
-- 14. Modificar simultaneamente los datos de contacto de una
--     organizacion (la fecha de actualizacion la registra el
--     trigger trg_tenants_updated_at de 06_triggers.sql).
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_actualizar_contacto_tenant(
    p_id_tenant       INT,
    p_contact_email   VARCHAR,
    p_contact_phone   VARCHAR,
    p_tenant_address  VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE tenants
    SET contact_email  = p_contact_email,
        contact_phone  = p_contact_phone,
        tenant_address = p_tenant_address
    WHERE id_tenant = p_id_tenant;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una organizacion con id_tenant = %', p_id_tenant;
    END IF;
END;
$$;

-- Prueba: actualizar el contacto de Textiles Bogota
SELECT id_tenant FROM tenants WHERE tenant_nit = '900555666-7' \gset
BEGIN;
CALL sp_actualizar_contacto_tenant(
    :id_tenant, 'nuevo_correo@textilesbogota.co', '6010000000', 'Nueva direccion 100'
);
SELECT contact_email, contact_phone FROM tenants WHERE tenant_nit = '900555666-7';
ROLLBACK;

-- ---------------------------------------------------------------------
-- 15. Asignar una plantilla con manejo de excepciones: cualquier
--     error durante la operacion queda controlado y se informa con
--     un mensaje claro, sin interrumpir la sesion del usuario.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_asignar_plantilla_segura(
    p_id_tenant             INT,
    p_id_format_sst         INT,
    p_id_person_updated_by  INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_template INT;
BEGIN
    SELECT id_template INTO v_id_template
    FROM templates
    WHERE id_format_sst = p_id_format_sst AND is_active
    LIMIT 1;

    IF v_id_template IS NULL THEN
        RAISE EXCEPTION 'El formato % no tiene una plantilla activa', p_id_format_sst;
    END IF;

    INSERT INTO tenanttemplates (id_tenant, id_template, id_person_updated_by)
    VALUES (p_id_tenant, v_id_template, p_id_person_updated_by);

    RAISE NOTICE 'Plantilla asignada correctamente a la organizacion %', p_id_tenant;

EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'La organizacion % ya tenia asignada esa plantilla; no se realizaron cambios', p_id_tenant;
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'La organizacion % o la persona % no existen; no se realizaron cambios',
            p_id_tenant, p_id_person_updated_by;
    WHEN OTHERS THEN
        RAISE NOTICE 'No se pudo asignar la plantilla (%): %', SQLSTATE, SQLERRM;
END;
$$;

-- Prueba: llamarlo dos veces seguidas con el mismo formato para Textiles
-- Bogota (que no tiene PESV habilitado, por lo que el formato no le esta
-- asignado aun) - la primera vez asigna, la segunda debe avisar "ya tenia
-- asignada esa plantilla" en vez de lanzar un error que interrumpa la sesion
SELECT id_tenant FROM tenants WHERE tenant_nit = '900555666-7' \gset
SELECT id_format_sst FROM formats_sst WHERE format_code = 'F-PESV-002' \gset
SELECT id_person FROM persons WHERE person_identification = '52345678' \gset
BEGIN;
CALL sp_asignar_plantilla_segura(:id_tenant, :id_format_sst, :id_person);
CALL sp_asignar_plantilla_segura(:id_tenant, :id_format_sst, :id_person);
ROLLBACK;
