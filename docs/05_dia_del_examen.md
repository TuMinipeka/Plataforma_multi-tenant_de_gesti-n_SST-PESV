# Examen SST/PESV — Guía para el día del examen

Contexto: el examen se hace en un equipo del profesor (Mac), donde te dan **Docker, terminal y
pgAdmin** ya instalados. No sabes de antemano el nombre del contenedor, usuario, contraseña ni
puerto exactos — eso te lo da el profesor ese día. Este documento es el plan de acción.

## 0. Repaso: conectar pgAdmin y la terminal al Docker del profesor

Idea clave: **pgAdmin no sabe nada de Docker.** Se conecta por red (host + puerto) exactamente
igual que si PostgreSQL corriera sin contenedores. Docker solo importa para *encontrar* ese
host/puerto, o como atajo si prefieres la terminal.

### 0.1 Verificar que el contenedor está corriendo

En la terminal del Mac:

```bash
docker ps
```

Busca la fila de PostgreSQL. Te interesan dos columnas:

```
NAMES          PORTS
postgres_db    0.0.0.0:5433->5432/tcp
```

- `NAMES` → nombre del contenedor (lo usas con `docker exec`).
- `PORTS` → `<puerto_del_mac>->5432/tcp`. Aquí el contenedor escucha en su puerto interno 5432,
  pero desde fuera (pgAdmin, psql) te conectas al puerto de la izquierda (`5433` en el ejemplo).

Si no aparece nada corriendo, pídele al profesor el comando para levantarlo
(`docker start <nombre>` o `docker compose up -d` si hay un `docker-compose.yml`).

### 0.2 Conectar pgAdmin (GUI)

1. Abre pgAdmin → clic derecho en **Servers** → **Register → Server…**
2. Pestaña **General**: en *Name* pon cualquier alias, por ejemplo `Examen`.
3. Pestaña **Connection**:
   - **Host name/address**: `localhost` (o `127.0.0.1`) — casi nunca el nombre del contenedor.
   - **Port**: el puerto de la izquierda que viste en `docker ps` (ej. `5433`).
   - **Maintenance database**: `postgres` (o el nombre de la base que te indiquen).
   - **Username** / **Password**: los que te dé el profesor. Marca *Save password* para no
     reescribirla cada vez.
4. **Save**. En el panel izquierdo: `Servers → Examen → Databases → <tu base>`.
5. Clic derecho sobre la base → **Query Tool** para ejecutar SQL (ahí pegas `00_examen_completo.sql`).

### 0.3 Conectar por terminal (para las consultas del examen)

Dos formas, elige la que funcione en ese equipo:

**A) Directo por red (igual que pgAdmin, requiere `psql` instalado en el Mac):**

```bash
psql -h localhost -p 5433 -U <usuario> -d <base>
```

Te pedirá la contraseña. Si no quieres que la pida cada vez en la misma sesión de terminal:

```bash
export PGPASSWORD='<contraseña>'
psql -h localhost -p 5433 -U <usuario> -d <base>
```

**B) Entrando al contenedor (no necesitas saber el puerto expuesto, solo el nombre del contenedor):**

```bash
docker exec -it postgres_db psql -U <usuario> -d <base>
```

La opción B es la más simple de recordar bajo presión: solo necesitas `docker ps` para ver el
nombre y ya. Úsala como plan por defecto.

### 0.4 Ya dentro de `psql`, comandos útiles para el examen

```
\dt                listar tablas
\d nombre_tabla    ver columnas, tipos y restricciones de una tabla
\x                 alternar salida "expandida" (mejor para filas anchas con muchas columnas)
\timing            mostrar cuanto tarda cada consulta
\q                 salir
```

Las consultas normales se escriben tal cual, terminando en `;`:

```sql
SELECT tenant_name, contact_email FROM tenants WHERE is_active;
```

### 0.5 Orden recomendado el día del examen

1. `docker ps` → confirmar contenedor y puerto.
2. Conectar pgAdmin (paso 0.2) → correr `00_examen_completo.sql` en el Query Tool.
3. Abrir una terminal aparte → `docker exec -it <contenedor> psql -U <usuario> -d <base>` → quedas
   listo para escribir las consultas del examen sin salir de la terminal.

## 1. Un solo archivo para montar todo: `sql/00_examen_completo.sql`

Es la fusión de `00_reset.sql` + `01_schema.sql` + `02_seed.sql` + `03_vistas.sql` en un único
script. Propiedades importantes:

- **No usa `CREATE DATABASE`.** Corre dentro de la base que ya te asignen, sea cual sea su nombre.
  No necesitas permisos de superusuario.
- **Es idempotente.** Empieza con `DROP ... IF EXISTS ... CASCADE` de todo (vistas materializadas,
  vistas, tablas, tipo `document_status`). Si algo sale mal a mitad del examen, vuelves a pegar el
  mismo archivo completo y no falla por "ya existe".
- **Tarda menos de 1 segundo.**

### Cómo usarlo desde pgAdmin (ruta más probable)

1. Conéctate al servidor con las credenciales que te den.
2. Clic derecho sobre la base asignada → **Query Tool**.
3. Abre `sql/00_examen_completo.sql` (icono de carpeta en la barra del Query Tool) o pega su
   contenido completo.
4. **Execute (F5)**. Revisa que el bloque final de verificación muestre las 10 tablas con datos y
   las 4 vistas materializadas con números.

### Cómo usarlo desde terminal (si prefieres o si pgAdmin falla)

```bash
psql -h <host> -p <puerto> -U <usuario> -d <base> -f sql/00_examen_completo.sql
```

Si el profesor te da acceso por `docker exec` en vez de un puerto expuesto:

```bash
docker exec -i <contenedor> psql -U <usuario> -d <base> < sql/00_examen_completo.sql
```

(`00_build_all.sh` automatiza esta segunda forma si además tienes permiso de crear/borrar la base
completa; en el equipo del profesor probablemente no lo tengas, así que la ruta principal es el
archivo único de arriba.)

## 2. Qué preguntarle al profesor apenas te sientes

- Host y puerto (o nombre del contenedor si es por `docker exec`).
- Usuario y contraseña.
- Nombre de la base que debes usar (si ya existe una o si te toca crearla tú).
- Si tienes o no permiso de `CREATE DATABASE` / `DROP DATABASE`.

Con eso, o usas `00_examen_completo.sql` directo (no depende de ninguna de estas respuestas salvo
la conexión), o si tienes permisos completos usas `00_build_all.sh MODE=tcp DB_HOST=... DB_PORT=...
DB_USER=... DB_NAME=...`.

## 3. Verificación rápida post-montaje

El propio script termina imprimiendo:
- Conteo de filas de las 10 tablas con datos (`tenants`, `persons`, `documents`, …).
- Una muestra de `vw_tenant_persons`.
- `vw_tenant_summary` completa (4 empresas).
- Las dos vistas materializadas de cumplimiento.

Si esos cuatro bloques aparecen sin errores, la base quedó lista para las consultas del examen.

## 4. De aquí en adelante: procedimientos, funciones, triggers, consultas

Se escriben con SQL de libro de texto (JOIN explícitos, subconsultas directas, sin trucos de
optimización) para que sean fáciles de reproducir de memoria. Cada archivo nuevo (`04_procedimientos.sql`,
`05_funciones.sql`, `06_triggers.sql`) se **añade también** a `00_examen_completo.sql` para que el
archivo único siga siendo la fuente completa de montaje.
