-- =====================================================================
--  Examen SST/PESV - Paso 3: Datos de prueba (seed)
--  Base de datos : examen   (esquema public)
--  Objetivo: catalogos completos + 4 empresas con personas, asignaciones
--  y documentos en distintos estados, para poder correr despues las
--  consultas basicas, intermedias y avanzadas del enunciado.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Geografia
-- ---------------------------------------------------------------------
INSERT INTO countries (country_iso_code, country_name) VALUES
    ('CO', 'Colombia');

INSERT INTO departments (id_country, department_dane_code, department_name)
SELECT id_country, v.code, v.name
FROM countries, (VALUES ('05','Antioquia'), ('11','Bogota D.C.'), ('76','Valle del Cauca')) AS v(code, name)
WHERE country_iso_code = 'CO';

INSERT INTO municipalities (id_department, municipality_dane_code, municipality_name)
SELECT d.id_department, v.code, v.name
FROM departments d
JOIN (VALUES
        ('Antioquia', '05001', 'Medellin'),
        ('Antioquia', '05088', 'Bello'),
        ('Bogota D.C.', '11001', 'Bogota'),
        ('Valle del Cauca', '76001', 'Cali')
     ) AS v(dept, code, name) ON v.dept = d.department_name;

-- ---------------------------------------------------------------------
-- 2. Tamanos de empresa
-- ---------------------------------------------------------------------
INSERT INTO tenant_sizes (tenant_size_code, tenant_size_name, min_workers, max_workers) VALUES
    ('MICRO',  'Microempresa', 1,   10),
    ('SMALL',  'Pequena',      11,  50),
    ('MEDIUM', 'Mediana',      51,  200),
    ('LARGE',  'Grande',       201, NULL);

-- ---------------------------------------------------------------------
-- 3. Sistemas de gestion y etapas PHVA
-- ---------------------------------------------------------------------
INSERT INTO type_system_sst (system_code, system_name, system_description) VALUES
    ('SST',  'Seguridad y Salud en el Trabajo', 'Sistema de gestion SG-SST segun Decreto 1072 de 2015'),
    ('PESV', 'Plan Estrategico de Seguridad Vial', 'PESV segun Resolucion 40595 de 2022');

INSERT INTO phva_stages (phva_stage_code, phva_stage_name, phva_stage_order) VALUES
    ('P', 'Planear',   1),
    ('H', 'Hacer',     2),
    ('V', 'Verificar', 3),
    ('A', 'Actuar',    4);

-- ---------------------------------------------------------------------
-- 4. Modulos por sistema
-- ---------------------------------------------------------------------
INSERT INTO modules (id_type_system_sst, module_title, module_description, module_order)
SELECT ts.id_type_system_sst, v.title, v.descr, v.ord
FROM type_system_sst ts
JOIN (VALUES
        ('SST', 'Politica y Objetivos SST',        'Definicion de la politica del SG-SST',              1),
        ('SST', 'Identificacion de Peligros',      'Matriz de peligros y valoracion de riesgos',        2),
        ('SST', 'Plan de Emergencias',              'Preparacion y respuesta ante emergencias',          3),
        ('SST', 'Capacitacion en SST',              'Programa de capacitacion e induccion',              4),
        ('PESV', 'Diagnostico de Seguridad Vial',   'Linea base de riesgos viales de la organizacion',   1),
        ('PESV', 'Politica de Seguridad Vial',      'Compromiso formal en seguridad vial',               2),
        ('PESV', 'Plan de Accion PESV',              'Acciones para mitigar el riesgo vial',              3),
        ('PESV', 'Auditoria y Seguimiento PESV',    'Verificacion del cumplimiento del PESV',            4)
     ) AS v(sys, title, descr, ord) ON v.sys = ts.system_code;

-- ---------------------------------------------------------------------
-- 5. Formatos (documento exigido por modulo + etapa PHVA)
-- ---------------------------------------------------------------------
INSERT INTO formats_sst (id_module, id_phva_stage, format_code, format_name, format_description, is_mandatory)
SELECT m.id_module, ph.id_phva_stage, v.code, v.name, v.descr, v.mandatory
FROM (VALUES
        ('Politica y Objetivos SST',      'P', 'F-SST-001', 'Politica SST firmada',            'Documento de politica firmado por representante legal', TRUE),
        ('Identificacion de Peligros',    'H', 'F-SST-002', 'Matriz de Peligros y Riesgos',     'Matriz IPVR actualizada',                                TRUE),
        ('Plan de Emergencias',           'H', 'F-SST-003', 'Plan de Emergencias documentado',  'Plan de preparacion y respuesta',                        TRUE),
        ('Capacitacion en SST',           'V', 'F-SST-004', 'Registro de Capacitaciones',       'Listados de asistencia y contenidos',                    FALSE),
        ('Diagnostico de Seguridad Vial', 'P', 'F-PESV-001','Diagnostico Vial Inicial',         'Resultado del diagnostico de riesgo vial',               TRUE),
        ('Politica de Seguridad Vial',    'P', 'F-PESV-002','Politica de Seguridad Vial firmada','Documento de politica vial firmado',                    TRUE),
        ('Plan de Accion PESV',           'H', 'F-PESV-003','Plan de Accion PESV',              'Cronograma de acciones y responsables',                  TRUE),
        ('Auditoria y Seguimiento PESV',  'V', 'F-PESV-004','Informe de Auditoria PESV',        'Resultados de auditoria interna',                        FALSE),
        -- Etapa "Actuar" del ciclo PHVA (acciones correctivas tras verificar)
        ('Plan de Emergencias',           'A', 'F-SST-005', 'Plan de Mejora de Emergencias',    'Acciones correctivas tras simulacros o eventos reales',  FALSE),
        ('Auditoria y Seguimiento PESV',  'A', 'F-PESV-005','Plan de Mejora PESV',              'Acciones correctivas derivadas de la auditoria',         FALSE)
     ) AS v(mod_title, stage_code, code, name, descr, mandatory)
JOIN modules m      ON m.module_title = v.mod_title
JOIN phva_stages ph ON ph.phva_stage_code = v.stage_code;

-- ---------------------------------------------------------------------
-- 6. Plantillas (una version activa por formato)
-- ---------------------------------------------------------------------
INSERT INTO templates (id_format_sst, template_name, template_version, template_content, is_active)
SELECT f.id_format_sst, 'Plantilla ' || f.format_name || ' v1', 1,
       'Contenido base de la plantilla para ' || f.format_name, TRUE
FROM formats_sst f;

-- ---------------------------------------------------------------------
-- 7. Evaluaciones
-- ---------------------------------------------------------------------
INSERT INTO evaluations (id_module, evaluation_name, evaluation_description, is_active)
SELECT m.id_module, v.name, v.descr, TRUE
FROM (VALUES
        ('Identificacion de Peligros',   'Evaluacion de riesgos por puesto de trabajo',   'Cuestionario aplicado a cada puesto'),
        ('Capacitacion en SST',          'Evaluacion de conocimientos SST',               'Prueba de conocimientos posterior a la capacitacion'),
        ('Diagnostico de Seguridad Vial','Evaluacion de conductores',                     'Evaluacion de aptitud y conocimientos de conduccion'),
        ('Auditoria y Seguimiento PESV', 'Evaluacion de cumplimiento normativo',          'Checklist de cumplimiento de la Resolucion 40595')
     ) AS v(mod_title, name, descr)
JOIN modules m ON m.module_title = v.mod_title;

-- ---------------------------------------------------------------------
-- 8. Empresas (tenants)
-- ---------------------------------------------------------------------
INSERT INTO tenants (id_municipality, id_tenant_size, tenant_nit, tenant_name, contact_email, contact_phone, tenant_address, is_active)
SELECT mu.id_municipality, sz.id_tenant_size, v.nit, v.name, v.email, v.phone, v.address, v.active
FROM (VALUES
        ('Medellin', 'LARGE',  '900111222-3', 'Constructora Andina S.A.S.', 'sst@constructoraandina.com.co', '6042551234', 'Cra 45 # 12-30, Medellin',  TRUE),
        ('Cali',     'MEDIUM', '900333444-5', 'Transportes del Valle Ltda', 'sgsst@transportesdelvalle.com', '6023456789', 'Av 6N # 28-40, Cali',       TRUE),
        ('Bogota',   'SMALL',  '900555666-7', 'Textiles Bogota S.A.',       'talentohumano@textilesbogota.co','6017654321', 'Cl 13 # 68-50, Bogota',     TRUE),
        ('Medellin', 'MICRO',  '900777888-9', 'Logistica Rapida SAS',       'gerencia@logisticarapida.co',   '6044456677', 'Cra 80 # 33-10, Medellin',   FALSE)
     ) AS v(muni, size_code, nit, name, email, phone, address, active)
JOIN municipalities mu ON mu.municipality_name = v.muni
JOIN tenant_sizes sz   ON sz.tenant_size_code = v.size_code;

-- ---------------------------------------------------------------------
-- 9. Sistemas habilitados por empresa
--    Constructora Andina: SST + PESV (tiene flota propia)
--    Transportes del Valle: SST + PESV (empresa de transporte)
--    Textiles Bogota: solo SST (no opera vehiculos)
--    Logistica Rapida: SST + PESV, pero inactiva
-- ---------------------------------------------------------------------
INSERT INTO tenantsystems (id_tenant, id_type_system_sst, is_active, enabled_at)
SELECT t.id_tenant, ts.id_type_system_sst, TRUE, now() - (interval '1 day' * v.days_ago)
FROM (VALUES
        ('900111222-3', 'SST',  400),
        ('900111222-3', 'PESV', 380),
        ('900333444-5', 'SST',  300),
        ('900333444-5', 'PESV', 300),
        ('900555666-7', 'SST',  200),
        ('900777888-9', 'SST',  150),
        ('900777888-9', 'PESV', 150)
     ) AS v(nit, sys_code, days_ago)
JOIN tenants t          ON t.tenant_nit = v.nit
JOIN type_system_sst ts ON ts.system_code = v.sys_code;

-- ---------------------------------------------------------------------
-- 10. Modulos habilitados (solo de los sistemas que cada empresa habilito)
-- ---------------------------------------------------------------------
INSERT INTO tenant_modules (id_tenant, id_module, is_enabled, enabled_at)
SELECT ts.id_tenant, m.id_module, TRUE, ts.enabled_at
FROM tenantsystems ts
JOIN modules m ON m.id_type_system_sst = ts.id_type_system_sst
-- Textiles Bogota no habilita "Plan de Emergencias" (aun en evaluacion)
WHERE NOT (
    ts.id_tenant = (SELECT id_tenant FROM tenants WHERE tenant_nit = '900555666-7')
    AND m.module_title = 'Plan de Emergencias'
);

-- ---------------------------------------------------------------------
-- 11. Cargos por empresa
-- ---------------------------------------------------------------------
INSERT INTO positions (id_tenant, position_name)
SELECT t.id_tenant, v.pos
FROM tenants t
JOIN (VALUES
        ('900111222-3', 'Gerente General'),
        ('900111222-3', 'Coordinador SST'),
        ('900111222-3', 'Supervisor de Obra'),
        ('900333444-5', 'Gerente General'),
        ('900333444-5', 'Coordinador SST'),
        ('900333444-5', 'Conductor'),
        ('900333444-5', 'Supervisor de Flota'),
        ('900555666-7', 'Gerente General'),
        ('900555666-7', 'Coordinador SST'),
        ('900555666-7', 'Auxiliar Administrativo'),
        ('900777888-9', 'Gerente General'),
        ('900777888-9', 'Coordinador SST')
     ) AS v(nit, pos) ON v.nit = t.tenant_nit;

-- ---------------------------------------------------------------------
-- 12. Personas
-- ---------------------------------------------------------------------
INSERT INTO persons (id_tenant, id_position, person_identification, first_name, last_name, person_email, person_phone, is_active)
SELECT t.id_tenant, p.id_position, v.doc, v.first_name, v.last_name, v.email, v.phone, v.active
FROM (VALUES
        ('900111222-3', 'Gerente General',    '71234567', 'Carlos',   'Ramirez',  'carlos.ramirez@constructoraandina.com.co', '3101234567', TRUE),
        ('900111222-3', 'Coordinador SST',    '43567891', 'Diana',    'Gomez',    'diana.gomez@constructoraandina.com.co',    '3112345678', TRUE),
        ('900111222-3', 'Supervisor de Obra', '80123456', 'Jorge',    'Martinez', 'jorge.martinez@constructoraandina.com.co', '3123456789', TRUE),
        ('900333444-5', 'Gerente General',    '16789234', 'Patricia', 'Lopez',    'patricia.lopez@transportesdelvalle.com',   '3134567890', TRUE),
        ('900333444-5', 'Coordinador SST',    '31456789', 'Andres',   'Vargas',   'andres.vargas@transportesdelvalle.com',    '3145678901', TRUE),
        ('900333444-5', 'Conductor',          '94512345', 'Luis',     'Torres',   'luis.torres@transportesdelvalle.com',      '3156789012', TRUE),
        ('900333444-5', 'Conductor',          '98765432', 'Camilo',   'Herrera',  'camilo.herrera@transportesdelvalle.com',   '3157654321', TRUE),
        ('900555666-7', 'Gerente General',    '52345678', 'Monica',   'Castro',   'monica.castro@textilesbogota.co',          '3167890123', TRUE),
        ('900555666-7', 'Coordinador SST',    '11987654', 'Felipe',   'Rojas',    'felipe.rojas@textilesbogota.co',           '3178901234', TRUE),
        ('900555666-7', 'Auxiliar Administrativo', '1010234567', 'Laura', 'Suarez','laura.suarez@textilesbogota.co',          '3189012345', FALSE),
        ('900777888-9', 'Gerente General',    '79456123', 'Ricardo',  'Pena',     'ricardo.pena@logisticarapida.co',          '3190123456', TRUE)
     ) AS v(nit, pos, doc, first_name, last_name, email, phone, active)
JOIN tenants t     ON t.tenant_nit = v.nit
JOIN positions p   ON p.id_tenant = t.id_tenant AND p.position_name = v.pos;

-- ---------------------------------------------------------------------
-- 13. Plantillas asignadas a cada empresa (tenanttemplates)
--     Se asignan las plantillas de los sistemas habilitados por cada una.
-- ---------------------------------------------------------------------
INSERT INTO tenanttemplates (id_tenant, id_template, id_person_updated_by, assigned_at, updated_at, is_active)
SELECT tm.id_tenant, tpl.id_template, coord.id_person,
       tm.enabled_at + interval '2 days', tm.enabled_at + interval '2 days', TRUE
FROM tenant_modules tm
JOIN formats_sst f  ON f.id_module = tm.id_module
JOIN templates tpl  ON tpl.id_format_sst = f.id_format_sst AND tpl.is_active
JOIN LATERAL (
    SELECT p.id_person FROM persons p
    JOIN positions po ON po.id_position = p.id_position
    WHERE p.id_tenant = tm.id_tenant AND po.position_name = 'Coordinador SST'
    LIMIT 1
) coord ON TRUE;

-- ---------------------------------------------------------------------
-- 14. Documentos: se generan solo para ALGUNAS asignaciones
--     (el resto queda "no iniciado" = sin fila en documents, a proposito)
-- ---------------------------------------------------------------------

-- 14a. Documentos FINALIZADOS: la politica SST de Constructora Andina y
--      Transportes del Valle, y la politica PESV de Transportes del Valle.
INSERT INTO documents (id_tenant_template, id_person_created_by, document_title, document_content, document_status, created_at, updated_at, finalized_at)
SELECT tt.id_tenant_template, tt.id_person_updated_by,
       tpl.template_name, 'Documento finalizado y firmado.', 'finalizado',
       tt.assigned_at + interval '5 days', tt.assigned_at + interval '10 days', tt.assigned_at + interval '10 days'
FROM tenanttemplates tt
JOIN templates tpl ON tpl.id_template = tt.id_template
JOIN formats_sst f ON f.id_format_sst = tpl.id_format_sst
JOIN tenants t      ON t.id_tenant = tt.id_tenant
WHERE (t.tenant_nit, f.format_code) IN (
    ('900111222-3', 'F-SST-001'),
    ('900333444-5', 'F-SST-001'),
    ('900333444-5', 'F-PESV-002')
);

-- 14b. Documentos en BORRADOR: la matriz de peligros de Constructora Andina
--      y el diagnostico vial de Transportes del Valle.
INSERT INTO documents (id_tenant_template, id_person_created_by, document_title, document_content, document_status, created_at, updated_at)
SELECT tt.id_tenant_template, tt.id_person_updated_by,
       tpl.template_name, 'Version preliminar en elaboracion.', 'borrador',
       tt.assigned_at + interval '3 days', tt.assigned_at + interval '4 days'
FROM tenanttemplates tt
JOIN templates tpl ON tpl.id_template = tt.id_template
JOIN formats_sst f ON f.id_format_sst = tpl.id_format_sst
JOIN tenants t      ON t.id_tenant = tt.id_tenant
WHERE (t.tenant_nit, f.format_code) IN (
    ('900111222-3', 'F-SST-002'),
    ('900333444-5', 'F-PESV-001')
);

-- 14c. Documentos PENDIENTES (en revision): plan de emergencias de
--      Constructora Andina.
INSERT INTO documents (id_tenant_template, id_person_created_by, document_title, document_content, document_status, created_at, updated_at)
SELECT tt.id_tenant_template, tt.id_person_updated_by,
       tpl.template_name, 'Enviado a revision del coordinador SST.', 'pendiente',
       tt.assigned_at + interval '6 days', tt.assigned_at + interval '7 days'
FROM tenanttemplates tt
JOIN templates tpl ON tpl.id_template = tt.id_template
JOIN formats_sst f ON f.id_format_sst = tpl.id_format_sst
JOIN tenants t      ON t.id_tenant = tt.id_tenant
WHERE (t.tenant_nit, f.format_code) IN (
    ('900111222-3', 'F-SST-003')
);
-- El resto de tenanttemplates queda sin documento => "no iniciado".

-- ---------------------------------------------------------------------
-- 15. Bloqueo de edicion activo (Diana esta editando el borrador
--     de la matriz de peligros de Constructora Andina)
-- ---------------------------------------------------------------------
INSERT INTO editing_locks (id_document, id_person_locked_by, locked_at, lock_expires_at, is_active)
SELECT d.id_document, p.id_person, now() - interval '10 minutes', now() + interval '20 minutes', TRUE
FROM documents d
JOIN tenanttemplates tt ON tt.id_tenant_template = d.id_tenant_template
JOIN templates tpl      ON tpl.id_template = tt.id_template
JOIN formats_sst f      ON f.id_format_sst = tpl.id_format_sst
JOIN tenants t           ON t.id_tenant = tt.id_tenant
JOIN persons p           ON p.id_tenant = t.id_tenant
JOIN positions po        ON po.id_position = p.id_position
WHERE t.tenant_nit = '900111222-3' AND f.format_code = 'F-SST-002' AND po.position_name = 'Coordinador SST';

-- ---------------------------------------------------------------------
-- 16. Auditoria: cambios historicos ilustrativos sobre tenants
--     (en produccion los inserta el trigger 12/13; aqui se cargan a mano
--     porque los triggers aun no se implementan en este paso)
-- ---------------------------------------------------------------------
INSERT INTO tenant_audit (id_tenant, audit_operation, audited_field, old_value, new_value, changed_by, changed_at)
SELECT t.id_tenant, 'UPDATE', 'contact_phone', '6042550000', '6042551234', 'diana.gomez', now() - interval '30 days'
FROM tenants t WHERE t.tenant_nit = '900111222-3';

INSERT INTO tenant_audit (id_tenant, audit_operation, audited_field, old_value, new_value, changed_by, changed_at)
SELECT t.id_tenant, 'UPDATE', 'is_active', 'true', 'false', 'admin', now() - interval '5 days'
FROM tenants t WHERE t.tenant_nit = '900777888-9';

-- ---------------------------------------------------------------------
-- 17. Indicadores de cumplimiento (instantanea historica por empresa/sistema)
--     Calculados a partir de lo realmente cargado en documents/tenanttemplates.
-- ---------------------------------------------------------------------
INSERT INTO compliance_indicators (
    id_tenant, id_type_system_sst, total_docs, finalized_docs, draft_docs,
    pending_docs, not_started_docs, compliance_percentage, calculated_at
)
SELECT
    tt.id_tenant,
    f.id_module_system,
    COUNT(*)                                                    AS total_docs,
    COUNT(*) FILTER (WHERE d.document_status = 'finalizado')    AS finalized_docs,
    COUNT(*) FILTER (WHERE d.document_status = 'borrador')      AS draft_docs,
    COUNT(*) FILTER (WHERE d.document_status = 'pendiente')     AS pending_docs,
    COUNT(*) FILTER (WHERE d.id_document IS NULL)               AS not_started_docs,
    ROUND(100.0 * COUNT(*) FILTER (WHERE d.document_status = 'finalizado') / COUNT(*), 2) AS compliance_percentage,
    now()
FROM tenanttemplates tt
JOIN templates tpl ON tpl.id_template = tt.id_template
JOIN (
    SELECT fs.id_format_sst, m.id_type_system_sst AS id_module_system
    FROM formats_sst fs JOIN modules m ON m.id_module = fs.id_module
) f ON f.id_format_sst = tpl.id_format_sst
LEFT JOIN documents d ON d.id_tenant_template = tt.id_tenant_template
GROUP BY tt.id_tenant, f.id_module_system;

COMMIT;

-- =====================================================================
-- Verificacion rapida
-- =====================================================================
SELECT 'tenants' AS tabla, COUNT(*) FROM tenants
UNION ALL SELECT 'persons', COUNT(*) FROM persons
UNION ALL SELECT 'positions', COUNT(*) FROM positions
UNION ALL SELECT 'tenantsystems', COUNT(*) FROM tenantsystems
UNION ALL SELECT 'tenant_modules', COUNT(*) FROM tenant_modules
UNION ALL SELECT 'tenanttemplates', COUNT(*) FROM tenanttemplates
UNION ALL SELECT 'documents', COUNT(*) FROM documents
UNION ALL SELECT 'editing_locks', COUNT(*) FROM editing_locks
UNION ALL SELECT 'tenant_audit', COUNT(*) FROM tenant_audit
UNION ALL SELECT 'compliance_indicators', COUNT(*) FROM compliance_indicators
ORDER BY 1;
