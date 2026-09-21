# Guía para principiantes: levantar el proyecto con Docker

Esta guía asume que **nunca has usado Docker** ni la terminal. Sigue los pasos en orden, para tu
sistema operativo, y al final vas a tener la base de datos completa funcionando en tu computador.
No necesitas instalar PostgreSQL, ni pgAdmin, ni configurar nada manualmente — Docker se encarga
de todo eso por ti dentro de contenedores aislados que no ensucian tu sistema.

## 0. ¿Qué es Docker, en una frase?

Docker empaqueta un programa (en este caso, PostgreSQL y pgAdmin) junto con todo lo que necesita
para funcionar, de modo que corre igual en cualquier computador sin que tengas que instalar y
configurar cada pieza a mano.

---

## 1. Instalar Docker

Elige tu sistema operativo:

### 🪟 Windows 10 / 11

1. Entra a **[docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/)**
   y descarga **Docker Desktop for Windows**.
2. Ejecuta el instalador. Cuando te pregunte, deja marcada la opción **"Use WSL 2 instead of
   Hyper-V"** (es la recomendada y la más ligera).
   - Si Windows te pide instalar o actualizar **WSL2**, acepta y sigue las instrucciones en
     pantalla; a veces pide reiniciar el computador a mitad del proceso, es normal.
3. Cuando termine, **reinicia el computador**.
4. Abre **Docker Desktop** desde el menú inicio y espera a que la ballena del ícono deje de
   animarse y aparezca "Docker Desktop is running" (o el ícono en la barra de tareas se quede
   quieto). Esto puede tardar uno o dos minutos la primera vez.

### 🍎 macOS

1. Entra a **[docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/)**
   y descarga **Docker Desktop for Mac**.
   - Si no sabes si tu Mac es **Apple Silicon** (M1/M2/M3/M4) o **Intel**: clic en el logo 🍎
     (arriba a la izquierda) → *Acerca de este Mac*. Ahí dice el procesador. La página de
     descarga de Docker detecta esto automáticamente si entras desde ese Mac.
2. Abre el archivo `.dmg` descargado y arrastra el ícono de Docker a la carpeta **Applications**.
3. Abre **Docker** desde Applications (Launchpad). La primera vez pedirá permisos del sistema;
   acéptalos.
4. Espera a que en la barra superior (junto al reloj) aparezca el ícono de la ballena fijo, sin
   animación — eso significa que ya está listo.

### 🐧 Linux (Ubuntu / Debian)

Abre una terminal y ejecuta, uno por uno:

```bash
# Instalar Docker Engine y el plugin de Docker Compose
curl -fsSL https://get.docker.com | sudo sh

# Permitir ejecutar docker sin escribir sudo cada vez (recomendado)
sudo usermod -aG docker $USER
```

Después de ese segundo comando, **cierra sesión y vuelve a entrar** (o reinicia), para que el
cambio de permisos tenga efecto.

> Para otras distribuciones (Fedora, Arch, openSUSE...), sigue la guía oficial:
> [docs.docker.com/engine/install](https://docs.docker.com/engine/install/).

---

## 2. Comprobar que Docker quedó instalado

Abre una terminal:

- **Windows:** busca "PowerShell" o "Terminal" en el menú inicio y ábrelo.
- **Mac:** busca "Terminal" con Spotlight (`Cmd + Espacio`, escribe "Terminal").
- **Linux:** tu terminal habitual.

Y escribe (es el mismo comando en los tres sistemas):

```bash
docker --version
docker compose version
```

Si ambos comandos responden con un número de versión (por ejemplo `Docker version 27.x.x`), todo
quedó bien instalado. Si dice "command not found" o similar, vuelve al paso 1: probablemente
Docker Desktop no terminó de abrir (Windows/Mac) o falta cerrar sesión (Linux).

---

## 3. Descargar el proyecto

### Opción A — con git (recomendada si ya lo tienes instalado)

```bash
git clone https://github.com/TuMinipeka/Plataforma_multi-tenant_de_gesti-n_SST-PESV.git
cd Plataforma_multi-tenant_de_gesti-n_SST-PESV
```

### Opción B — sin git, descargando el ZIP

1. Entra a la [página del repositorio](https://github.com/TuMinipeka/Plataforma_multi-tenant_de_gesti-n_SST-PESV).
2. Botón verde **`Code`** → **`Download ZIP`**.
3. Descomprime el archivo descargado en una carpeta fácil de encontrar (por ejemplo, tu
   Escritorio).
4. Abre una terminal **dentro de esa carpeta**:
   - **Windows:** abre la carpeta en el Explorador de archivos, haz clic en la barra de
     direcciones, escribe `powershell` y presiona Enter — se abre una terminal ya ubicada ahí.
   - **Mac:** clic derecho sobre la carpeta → *Servicios* → *Nueva Terminal en la carpeta* (si no
     aparece esa opción, abre Terminal y escribe `cd ` seguido de arrastrar la carpeta a la
     ventana, luego Enter).
   - **Linux:** clic derecho dentro de la carpeta en tu gestor de archivos → *Abrir terminal aquí*
     (el nombre exacto varía según tu distribución).

A partir de aquí, **todos los comandos de esta guía se escriben en esa terminal**, ubicada dentro
de la carpeta del proyecto.

---

## 4. Levantar la base de datos

Un solo comando (igual en Windows, Mac y Linux):

```bash
docker compose up -d
```

La primera vez descarga las imágenes de PostgreSQL y pgAdmin (puede tardar 1-3 minutos según tu
internet); las siguientes veces arranca en segundos. Cuando termine, comprueba que los dos
contenedores están corriendo:

```bash
docker ps
```

Deberías ver dos filas: una con el nombre `sst_pesv_db` y otra `sst_pesv_pgadmin`, ambas con
estado `Up`.

---

## 5. Cargar el esquema y los datos de ejemplo

Este paso copia el archivo con todas las tablas y los datos de prueba **dentro** del contenedor, y
luego le pide a PostgreSQL que lo ejecute. Son dos comandos, iguales en los tres sistemas
operativos:

```bash
docker cp sql/00_examen_completo.sql sst_pesv_db:/tmp/00_examen_completo.sql
docker exec -i sst_pesv_db psql -U sst_admin -d examen -f /tmp/00_examen_completo.sql
```

Al final vas a ver varias tablas de resultados en pantalla (conteo de filas, una vista de
ejemplo...). Si aparecen esas tablas y no aparece la palabra `ERROR`, todo cargó correctamente.

> Este segundo comando se puede volver a ejecutar las veces que quieras: el script se limpia y se
> reconstruye solo cada vez, así que no hay riesgo de "romper" nada si lo corres dos veces.

---

## 6. Ver la base de datos con pgAdmin (opcional, con interfaz gráfica)

Si prefieres ver las tablas con clics en vez de comandos:

1. Abre tu navegador en **[http://localhost:8090](http://localhost:8090)**.
2. Inicia sesión con usuario `admin@example.com` y contraseña `admin`.
3. Clic derecho en **Servers** (panel izquierdo) → **Register → Server…**
4. Pestaña **General** → en *Name* escribe, por ejemplo, `Examen SST-PESV`.
5. Pestaña **Connection**:
   - **Host name/address:** `sst_pesv_db` *(así se llama el contenedor; pgAdmin lo encuentra por
     ese nombre porque ambos corren dentro de la misma red de Docker)*
   - **Port:** `5432`
   - **Maintenance database:** `examen`
   - **Username:** `sst_admin`
   - **Password:** `sst_admin` (marca "Save password" para no repetirla)
6. **Save**. En el panel izquierdo: `Servers → Examen SST-PESV → Databases → examen → Schemas →
   public → Tables` — ahí están las 20 tablas.

*(Esto es lo mismo que se explica con más detalle, para conectarte a un PostgreSQL que no sea el
tuyo propio, en [`05_dia_del_examen.md`](05_dia_del_examen.md).)*

---

## 7. Apagar todo cuando termines

```bash
docker compose down
```

Esto detiene los contenedores pero **conserva** los datos cargados (la próxima vez que hagas
`docker compose up -d` van a seguir ahí). Si en cambio quieres borrar también los datos y empezar
desde cero la próxima vez:

```bash
docker compose down -v
```

---

## 8. Problemas comunes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `docker: command not found` / no reconocido | Docker Desktop no está abierto, o la instalación no terminó | Abre Docker Desktop y espera a que el ícono deje de animarse (Windows/Mac); en Linux, cierra sesión y vuelve a entrar tras instalar |
| `Cannot connect to the Docker daemon` | Docker Desktop está cerrado | Ábrelo desde el menú inicio / Applications y espera un minuto |
| `port is already allocated` al hacer `docker compose up -d` | Ya tienes algo usando el puerto 5434 u 8090 | Cierra ese otro programa, o edita `docker-compose.yml` y cambia el número a la izquierda de los dos puntos (por ejemplo `"5555:5432"`) |
| pgAdmin no encuentra el host `sst_pesv_db` | Escribiste `localhost` en vez del nombre del contenedor | Usa exactamente `sst_pesv_db` como *Host name*, no `localhost` (ver paso 6) |
| En Windows, PowerShell no reconoce `docker compose` (con espacio) | Tienes una versión muy vieja de Docker Desktop | Actualiza Docker Desktop; las versiones recientes ya no usan `docker-compose` (con guion) |
| `permission denied` en Linux al correr `docker ...` | Tu usuario no está en el grupo `docker` todavía | Repite `sudo usermod -aG docker $USER` y cierra sesión por completo |
| En Windows, usando **Git Bash** (la terminal que instala "Git for Windows"): al copiar el archivo, el error dice `C:/Users/.../Temp/00_examen_completo.sql` en vez de `/tmp/...` | Git Bash reescribe automáticamente las rutas que empiezan con `/` | Antes del comando `docker exec`, escribe `export MSYS_NO_PATHCONV=1` una sola vez (dura mientras esa ventana de terminal siga abierta), o usa PowerShell en su lugar, que no tiene este problema |

Si nada de esto resuelve el problema, revisa que Docker Desktop (Windows/Mac) esté realmente
abierto y en estado "Running" antes de cualquier otro paso — es la causa de la mayoría de errores
al principio.
