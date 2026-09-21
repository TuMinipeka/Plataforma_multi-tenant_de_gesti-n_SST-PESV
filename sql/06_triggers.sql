-- =====================================================================
--  Examen SST/PESV - Triggers (enunciado, seccion 7)
--  Cada trigger tiene su propia funcion fn_trg_...() y se declara con
--  DROP TRIGGER IF EXISTS + CREATE TRIGGER para poder re-ejecutar este
--  archivo las veces que haga falta sin que falle por "ya existe".
--
--  Debajo de cada trigger hay una prueba envuelta en BEGIN; ... ROLLBACK;
--  para comprobar que funciona sin dejar cambios permanentes. Cuando el
--  trigger debe impedir una operacion, la prueba usa un bloque DO con
--  EXCEPTION para capturar el error y mostrarlo con RAISE NOTICE, en vez
--  de cortar la ejecucion del script.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Actualizar automaticamente updated_at en tenants.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_tenants_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tenants_updated_at ON tenants;
CREATE TRIGGER trg_tenants_updated_at
    BEFORE UPDATE ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_tenants_updated_at();

-- Prueba: updated_at debe cambiar despues del UPDATE
BEGIN;
SELECT updated_at AS updated_at_antes FROM tenants WHERE tenant_nit = '900111222-3' \gset
UPDATE tenants SET tenant_address = tenant_address WHERE tenant_nit = '900111222-3';
SELECT (updated_at > :'updated_at_antes'::timestamptz) AS se_actualizo
FROM tenants WHERE tenant_nit = '900111222-3';
ROLLBACK;

-- ---------------------------------------------------------------------
-- 2. Actualizar automaticamente updated_at en persons.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_persons_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_persons_updated_at ON persons;
CREATE TRIGGER trg_persons_updated_at
    BEFORE UPDATE ON persons
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_persons_updated_at();

-- Prueba: updated_at debe cambiar despues del UPDATE
BEGIN;
SELECT updated_at AS updated_at_antes FROM persons WHERE person_identification = '71234567' \gset
UPDATE persons SET person_phone = person_phone WHERE person_identification = '71234567';
SELECT (updated_at > :'updated_at_antes'::timestamptz) AS se_actualizo
FROM persons WHERE person_identification = '71234567';
ROLLBACK;

-- ---------------------------------------------------------------------
-- 3. Impedir registrar una persona en una organizacion inactiva.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_persons_check_tenant_active()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT (SELECT is_active FROM tenants WHERE id_tenant = NEW.id_tenant) THEN
        RAISE EXCEPTION 'No se puede registrar una persona en la organizacion % porque esta inactiva',
            NEW.id_tenant;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_persons_check_tenant_active ON persons;
CREATE TRIGGER trg_persons_check_tenant_active
    BEFORE INSERT ON persons
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_persons_check_tenant_active();

-- Prueba: intentar registrar una persona en Logistica Rapida (inactiva) debe fallar
BEGIN;
DO $$
BEGIN
    INSERT INTO persons (id_tenant, person_identification, first_name, last_name)
    VALUES ((SELECT id_tenant FROM tenants WHERE tenant_nit = '900777888-9'), '11111111', 'X', 'Y');
    RAISE NOTICE 'ERROR: no debio permitir el INSERT';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Correcto, el trigger bloqueo el INSERT: %', SQLERRM;
END;
$$;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 4. Impedir asignar un modulo que ya se encuentre previamente
--    asignado a la organizacion (mensaje mas claro que la clave
--    primaria compuesta, que tambien lo bloquearia).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_tenant_modules_no_duplicado()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM tenant_modules
        WHERE id_tenant = NEW.id_tenant AND id_module = NEW.id_module
    ) THEN
        RAISE EXCEPTION 'El modulo % ya esta asignado a la organizacion %', NEW.id_module, NEW.id_tenant;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tenant_modules_no_duplicado ON tenant_modules;
CREATE TRIGGER trg_tenant_modules_no_duplicado
    BEFORE INSERT ON tenant_modules
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_tenant_modules_no_duplicado();

-- Prueba: intentar volver a asignar a Constructora Andina un modulo que ya tiene
BEGIN;
DO $$
BEGIN
    INSERT INTO tenant_modules (id_tenant, id_module, is_enabled)
    VALUES (
        (SELECT id_tenant FROM tenants WHERE tenant_nit = '900111222-3'),
        (SELECT id_module FROM modules WHERE module_title = 'Plan de Emergencias'),
        TRUE
    );
    RAISE NOTICE 'ERROR: no debio permitir el duplicado';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Correcto, el trigger bloqueo el duplicado: %', SQLERRM;
END;
$$;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 5. Impedir asignar plantillas a organizaciones inactivas.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_tenanttemplates_check_tenant_active()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT (SELECT is_active FROM tenants WHERE id_tenant = NEW.id_tenant) THEN
        RAISE EXCEPTION 'No se puede asignar una plantilla a la organizacion % porque esta inactiva',
            NEW.id_tenant;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tenanttemplates_check_tenant_active ON tenanttemplates;
CREATE TRIGGER trg_tenanttemplates_check_tenant_active
    BEFORE INSERT ON tenanttemplates
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_tenanttemplates_check_tenant_active();

-- Prueba: intentar asignar una plantilla a Logistica Rapida (inactiva) debe fallar
BEGIN;
DO $$
BEGIN
    INSERT INTO tenanttemplates (id_tenant, id_template, id_person_updated_by)
    VALUES (
        (SELECT id_tenant FROM tenants WHERE tenant_nit = '900777888-9'),
        (SELECT id_template FROM templates LIMIT 1),
        NULL
    );
    RAISE NOTICE 'ERROR: no debio permitir el INSERT';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Correcto, el trigger bloqueo el INSERT: %', SQLERRM;
END;
$$;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 6. Validar que una persona unicamente pueda asociarse a un cargo
--    perteneciente a su misma organizacion (mensaje mas claro que la
--    clave foranea compuesta, que tambien lo bloquearia).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_persons_check_position_tenant()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.id_position IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM positions
            WHERE id_position = NEW.id_position AND id_tenant = NEW.id_tenant
        ) THEN
            RAISE EXCEPTION 'El cargo % no pertenece a la organizacion %', NEW.id_position, NEW.id_tenant;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_persons_check_position_tenant ON persons;
CREATE TRIGGER trg_persons_check_position_tenant
    BEFORE INSERT OR UPDATE ON persons
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_persons_check_position_tenant();

-- Prueba: asignarle a una persona de Constructora Andina un cargo de Transportes del Valle
BEGIN;
DO $$
BEGIN
    UPDATE persons
    SET id_position = (SELECT id_position FROM positions WHERE position_name = 'Conductor')
    WHERE person_identification = '71234567';
    RAISE NOTICE 'ERROR: no debio permitir el cargo de otra organizacion';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Correcto, el trigger bloqueo el cambio: %', SQLERRM;
END;
$$;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 7. Registrar automaticamente la fecha de actualizacion cuando se
--    modifique una plantilla asignada a una organizacion.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_tenanttemplates_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tenanttemplates_updated_at ON tenanttemplates;
CREATE TRIGGER trg_tenanttemplates_updated_at
    BEFORE UPDATE ON tenanttemplates
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_tenanttemplates_updated_at();

-- Prueba: updated_at debe cambiar despues del UPDATE (trigger 14 exige
-- indicar el responsable, por eso el UPDATE tambien lo incluye)
BEGIN;
SELECT updated_at AS updated_at_antes FROM tenanttemplates LIMIT 1 \gset
UPDATE tenanttemplates
SET id_person_updated_by = (SELECT id_person FROM persons LIMIT 1)
WHERE id_tenant_template = (SELECT id_tenant_template FROM tenanttemplates LIMIT 1);
SELECT (updated_at > :'updated_at_antes'::timestamptz) AS se_actualizo
FROM tenanttemplates LIMIT 1;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 8. Impedir eliminar una organizacion cuando todavia existan
--    personas asociadas a ella.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_tenants_check_no_persons()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM persons WHERE id_tenant = OLD.id_tenant) THEN
        RAISE EXCEPTION 'No se puede eliminar la organizacion %: todavia tiene personas asociadas',
            OLD.id_tenant;
    END IF;
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_tenants_check_no_persons ON tenants;
CREATE TRIGGER trg_tenants_check_no_persons
    BEFORE DELETE ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_tenants_check_no_persons();

-- Prueba: intentar borrar Constructora Andina (tiene personas) debe fallar
BEGIN;
DO $$
BEGIN
    DELETE FROM tenants WHERE tenant_nit = '900111222-3';
    RAISE NOTICE 'ERROR: no debio permitir el DELETE';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Correcto, el trigger bloqueo el DELETE: %', SQLERRM;
END;
$$;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 9. Impedir eliminar un sistema SST cuando existan organizaciones
--    que lo esten utilizando.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_type_system_check_not_in_use()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM tenantsystems WHERE id_type_system_sst = OLD.id_type_system_sst) THEN
        RAISE EXCEPTION 'No se puede eliminar el sistema %: hay organizaciones que lo tienen habilitado',
            OLD.id_type_system_sst;
    END IF;
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_type_system_check_not_in_use ON type_system_sst;
CREATE TRIGGER trg_type_system_check_not_in_use
    BEFORE DELETE ON type_system_sst
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_type_system_check_not_in_use();

-- Prueba: intentar borrar el sistema SST (en uso por las 4 empresas) debe fallar
BEGIN;
DO $$
BEGIN
    DELETE FROM type_system_sst WHERE system_code = 'SST';
    RAISE NOTICE 'ERROR: no debio permitir el DELETE';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Correcto, el trigger bloqueo el DELETE: %', SQLERRM;
END;
$$;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 10. Impedir eliminar un modulo cuando este asignado a una o mas
--     organizaciones.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_modules_check_not_in_use()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM tenant_modules WHERE id_module = OLD.id_module) THEN
        RAISE EXCEPTION 'No se puede eliminar el modulo %: esta asignado a una o mas organizaciones',
            OLD.id_module;
    END IF;
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_modules_check_not_in_use ON modules;
CREATE TRIGGER trg_modules_check_not_in_use
    BEFORE DELETE ON modules
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_modules_check_not_in_use();

-- Prueba: intentar borrar el modulo "Plan de Emergencias" (asignado) debe fallar
BEGIN;
DO $$
BEGIN
    DELETE FROM modules WHERE module_title = 'Plan de Emergencias';
    RAISE NOTICE 'ERROR: no debio permitir el DELETE';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Correcto, el trigger bloqueo el DELETE: %', SQLERRM;
END;
$$;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 11. Validar que el porcentaje de cumplimiento de una organizacion
--     permanezca entre 0 y 100.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_compliance_check_range()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.compliance_percentage < 0 OR NEW.compliance_percentage > 100 THEN
        RAISE EXCEPTION 'El porcentaje de cumplimiento debe estar entre 0 y 100 (recibido: %)',
            NEW.compliance_percentage;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_compliance_check_range ON compliance_indicators;
CREATE TRIGGER trg_compliance_check_range
    BEFORE INSERT OR UPDATE ON compliance_indicators
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_compliance_check_range();

-- Prueba: intentar insertar un indicador con 150% debe fallar
BEGIN;
DO $$
BEGIN
    INSERT INTO compliance_indicators (id_tenant, id_type_system_sst, total_docs, finalized_docs,
        draft_docs, pending_docs, not_started_docs, compliance_percentage, calculated_at)
    VALUES (
        (SELECT id_tenant FROM tenants WHERE tenant_nit = '900111222-3'),
        (SELECT id_type_system_sst FROM type_system_sst WHERE system_code = 'SST'),
        10, 15, 0, 0, 0, 150, now()
    );
    RAISE NOTICE 'ERROR: no debio permitir el porcentaje fuera de rango';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Correcto, el trigger bloqueo el valor invalido: %', SQLERRM;
END;
$$;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 12. Auditoria: registrar en tenant_audit cualquier modificacion de
--     los datos principales de una organizacion (nombre, correo,
--     telefono, direccion). El cambio de estado tiene su propio
--     trigger (13), para dejar cada regla del enunciado en un objeto
--     independiente.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_tenants_audit_datos()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.tenant_name IS DISTINCT FROM OLD.tenant_name THEN
        INSERT INTO tenant_audit (id_tenant, audit_operation, audited_field, old_value, new_value, changed_by)
        VALUES (OLD.id_tenant, 'UPDATE', 'tenant_name', OLD.tenant_name, NEW.tenant_name, current_user);
    END IF;
    IF NEW.contact_email IS DISTINCT FROM OLD.contact_email THEN
        INSERT INTO tenant_audit (id_tenant, audit_operation, audited_field, old_value, new_value, changed_by)
        VALUES (OLD.id_tenant, 'UPDATE', 'contact_email', OLD.contact_email, NEW.contact_email, current_user);
    END IF;
    IF NEW.contact_phone IS DISTINCT FROM OLD.contact_phone THEN
        INSERT INTO tenant_audit (id_tenant, audit_operation, audited_field, old_value, new_value, changed_by)
        VALUES (OLD.id_tenant, 'UPDATE', 'contact_phone', OLD.contact_phone, NEW.contact_phone, current_user);
    END IF;
    IF NEW.tenant_address IS DISTINCT FROM OLD.tenant_address THEN
        INSERT INTO tenant_audit (id_tenant, audit_operation, audited_field, old_value, new_value, changed_by)
        VALUES (OLD.id_tenant, 'UPDATE', 'tenant_address', OLD.tenant_address, NEW.tenant_address, current_user);
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tenants_audit_datos ON tenants;
CREATE TRIGGER trg_tenants_audit_datos
    AFTER UPDATE ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_tenants_audit_datos();

-- Prueba: cambiar el correo de Constructora Andina debe dejar rastro en tenant_audit
BEGIN;
UPDATE tenants SET contact_email = 'auditoria@constructoraandina.com.co' WHERE tenant_nit = '900111222-3';
SELECT audited_field, old_value, new_value FROM tenant_audit
WHERE id_tenant = (SELECT id_tenant FROM tenants WHERE tenant_nit = '900111222-3')
ORDER BY id_tenant_audit DESC LIMIT 1;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 13. Auditoria especifica: guardar el valor anterior y el nuevo
--     cuando se modifique el estado (activa/inactiva) de una
--     organizacion.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_tenants_audit_estado()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
        INSERT INTO tenant_audit (id_tenant, audit_operation, audited_field, old_value, new_value, changed_by)
        VALUES (OLD.id_tenant, 'UPDATE', 'is_active', OLD.is_active::TEXT, NEW.is_active::TEXT, current_user);
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tenants_audit_estado ON tenants;
CREATE TRIGGER trg_tenants_audit_estado
    AFTER UPDATE ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_tenants_audit_estado();

-- Prueba: reactivar Logistica Rapida debe dejar rastro en tenant_audit
BEGIN;
UPDATE tenants SET is_active = TRUE WHERE tenant_nit = '900777888-9';
SELECT audited_field, old_value, new_value FROM tenant_audit
WHERE id_tenant = (SELECT id_tenant FROM tenants WHERE tenant_nit = '900777888-9')
  AND audited_field = 'is_active'
ORDER BY id_tenant_audit DESC LIMIT 1;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 14. Exigir que toda modificacion de una plantilla asignada indique
--     la persona responsable (id_person_updated_by). La base no tiene
--     forma de "adivinar" quien hizo el cambio desde la aplicacion,
--     asi que el trigger obliga a que ese dato siempre quede escrito.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_tenanttemplates_require_responsible()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.id_person_updated_by IS NULL THEN
        RAISE EXCEPTION 'Toda modificacion de una plantilla asignada debe indicar la persona responsable';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tenanttemplates_require_responsible ON tenanttemplates;
CREATE TRIGGER trg_tenanttemplates_require_responsible
    BEFORE UPDATE ON tenanttemplates
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_tenanttemplates_require_responsible();

-- Prueba: modificar una plantilla asignada sin indicar responsable debe fallar
BEGIN;
DO $$
BEGIN
    UPDATE tenanttemplates
    SET id_person_updated_by = NULL
    WHERE id_tenant_template = (SELECT id_tenant_template FROM tenanttemplates LIMIT 1);
    RAISE NOTICE 'ERROR: no debio permitir el UPDATE sin responsable';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Correcto, el trigger exigio el responsable: %', SQLERRM;
END;
$$;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 15. Marcar como inactivos los bloqueos de edicion vencidos.
--     PostgreSQL no ejecuta triggers por horario (no hay un "cron"
--     nativo), asi que la aproximacion practica es limpiar los
--     bloqueos vencidos justo antes de que alguien intente tomar uno
--     nuevo: BEFORE INSERT en editing_locks.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_editing_locks_clean_expired()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE editing_locks
    SET is_active = FALSE
    WHERE is_active AND lock_expires_at < now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_editing_locks_clean_expired ON editing_locks;
CREATE TRIGGER trg_editing_locks_clean_expired
    BEFORE INSERT ON editing_locks
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_editing_locks_clean_expired();

-- Prueba: un bloqueo vencido debe desactivarse solo al intentar crear uno nuevo
-- sobre el mismo documento
BEGIN;
INSERT INTO editing_locks (id_document, id_person_locked_by, locked_at, lock_expires_at, is_active)
VALUES (
    (SELECT id_document FROM documents LIMIT 1),
    (SELECT id_person FROM persons LIMIT 1),
    now() - interval '2 hours',
    now() - interval '1 hour',
    TRUE
);
-- este segundo INSERT dispara el trigger, que primero limpia el vencido de arriba
INSERT INTO editing_locks (id_document, id_person_locked_by, lock_expires_at, is_active)
VALUES (
    (SELECT id_document FROM documents LIMIT 1),
    (SELECT id_person FROM persons OFFSET 1 LIMIT 1),
    now() + interval '1 hour',
    TRUE
);
SELECT is_active, lock_expires_at FROM editing_locks
WHERE id_document = (SELECT id_document FROM documents LIMIT 1)
ORDER BY id_editing_lock;
ROLLBACK;
