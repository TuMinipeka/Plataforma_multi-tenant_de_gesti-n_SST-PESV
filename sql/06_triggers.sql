-- =====================================================================
--  Examen SST/PESV - Triggers (enunciado, seccion 7)
--  Cada trigger tiene su propia funcion fn_trg_...() y se declara con
--  DROP TRIGGER IF EXISTS + CREATE TRIGGER para poder re-ejecutar este
--  archivo las veces que haga falta sin que falle por "ya existe".
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
