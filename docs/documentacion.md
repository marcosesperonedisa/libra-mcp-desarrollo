# Documentación de libra-mcp

## 1. Introducción

`libra-mcp` es el entorno en Docker que permite a Claude Code trabajar contra bases de
datos Oracle de LIBRA a través de la VPN FortiGate, usando el servidor MCP de SQLcl.
Todo el manejo del día a día se hace desde el menú `./libra_mcp.sh` (instalación, arranque
y parada de la VPN, y gestión de las conexiones Oracle). La explicación completa del
entorno está en el `README.md` y en el `CLAUDE.md`.

Este documento recoge la parametrización disponible y ejemplos de uso, y se irá ampliando
con cada mejora.

### Recomendador de pasos pendientes

Cada vez que arranca el menú, el script mira el estado del entorno y muestra en la
cabecera **la lista de pasos que todavía faltan**, en el orden en que conviene hacerlos y
con la opción de menú que resuelve cada uno. Así no hace falta recordar la secuencia de
instalación: el propio menú te guía.

Qué comprueba, en orden:

1. **Docker Desktop arrancado.** Si no lo está, es lo único que recomienda (sin Docker no
   se puede comprobar el resto).
2. **Credenciales de la VPN** configuradas → opción 2.
3. **Imágenes** construidas → opción 3.
4. **Certificado** del FortiGate guardado → opción 4.
5. **Servidor MCP** registrado en Claude Code → opción 5 (si falta Claude Code, lo avisa ahí).
6. **VPN en marcha:** cuando todo lo anterior está pero el túnel está parado → opción 7.

Cuando no queda nada pendiente (y por tanto el túnel está activo), en vez de un mensaje
genérico muestra que la **VPN está en marcha** y la **IP del túnel**, por ejemplo
`✔ VPN en marcha · IP del túnel: 10.20.30.40/32. Abre Claude Code.` Si por lo que sea no
se detecta la IP, se omite esa parte.

A propósito **no** comprueba si hay conexiones Oracle guardadas: esa comprobación obliga a
lanzar un contenedor Docker, y hacerlo cada vez que se repinta el menú lo ralentizaría.

### Conexión como SYSDBA

Al añadir una conexión Oracle (opción 11 → Añadir), el menú pregunta
**"¿Conectar como SYSDBA?"**. Si respondes que sí, la conexión se guarda con el rol
SYSDBA (se añade `as sysdba` a la cadena de conexión), de modo que el MCP la use siempre
con ese rol. Para cambiar el rol de una conexión ya existente —o quitárselo— basta con
volver a añadirla con el mismo nombre, que la sobrescribe.

### Desinstalar el entorno

En "Mantenimiento" → **13) Desinstalar** se elimina el entorno de forma guiada. Primero
avisa de todo lo que va a tocar y pide una confirmación general; después va paso a paso:

1. Para y borra el **contenedor de la VPN** (`vpn_libra`) y la red del proyecto.
2. Borra las **imágenes** `libra-vpn` y `libra-sqlcl-mcp` (solo las que existan).
3. **(confirmación aparte)** Borra el **volumen de conexiones** `sqlcl_conexiones`,
   avisando de que se pierden las conexiones Oracle guardadas.
4. **(confirmación aparte)** Desregistra el **servidor MCP** de Claude Code.
5. **(confirmación aparte)** Borra los **secretos de la VPN** (`secretos/vpn.conf`).

Los pasos 1 y 2 van bajo la confirmación general, porque son reconstruibles (basta volver
a instalar). Los pasos 3, 4 y 5 piden confirmación propia (por defecto, *no*), porque
suponen pérdida de datos o de configuración del usuario. Cada paso es independiente: si la
pieza no existe, lo indica y continúa. Al final muestra un resumen de lo hecho.

Si el volumen no se deja borrar por estar "en uso", cierra Claude Code (que mantiene viva
la sesión del MCP) y repite la desinstalación.

### Log del MCP

El servidor MCP de SQLcl lo lanza Claude Code en cada sesión a través del wrapper
`lanzar_mcp.sh`. Ese wrapper permite un **modo log** que registra **solo las llamadas a
herramientas** del MCP (las peticiones `tools/call`: la SQL que ejecuta, las búsquedas de
procedimientos y sus parámetros), no el handshake de arranque ni las respuestas, así que
no se vuelcan datos de la base de datos.

Desde el menú:

- **14) Activar/desactivar log del MCP:** crea o borra el interruptor `logs/mcp.on`. Con
  el modo activo, las peticiones se van guardando en `logs/mcp-peticiones.log`.
- **15) Ver log del MCP:** muestra el fichero y lo sigue (como el log de la VPN); Ctrl+C
  para volver al menú.

Detalles importantes:

- El cambio **surte efecto en la siguiente sesión** de Claude Code: tras activar o
  desactivar, reinicia Claude Code.
- Para que el log funcione, el MCP debe estar registrado **a través del wrapper**; si
  venías de una instalación anterior, vuelve a registrarlo (opción 5).
- La carpeta `logs/` está fuera de git. Solo se registran peticiones, pero esas
  peticiones incluyen la SQL que se ejecuta: trátalo como información sensible.
- Técnicamente, el wrapper hace `tee` de la entrada (stdin): el stream **íntegro** va al
  contenedor y una **copia** se filtra con `awk` para quedarse solo con las líneas
  `tools/call`. La salida (respuestas) pasa intacta, así no se altera el protocolo MCP.
  Cada sesión escribe una cabecera con fecha solo si llega a hacer alguna llamada.

## 2. Parametrización

Las constantes del principio de `libra_mcp.sh` permiten ajustar el entorno sin tocar la
lógica:

| Constante | Valor por defecto | Para qué sirve |
|---|---|---|
| `CONTENEDOR_VPN` | `vpn_libra` | Nombre del contenedor del túnel VPN. |
| `IMAGEN_VPN` | `libra-vpn` | Nombre de la imagen de la VPN. |
| `IMAGEN_SQLCL` | `libra-sqlcl-mcp` | Nombre de la imagen del servidor MCP de SQLcl. |
| `VOLUMEN_CONEXIONES` | `sqlcl_conexiones` | Volumen donde SQLcl guarda las conexiones cifradas. |
| `NOMBRE_MCP` | `sqlcl` | Nombre con el que se registra el servidor MCP en Claude Code. |
| `SEGUNDOS_ESPERA_TUNEL` | `30` | Tiempo máximo esperando a que suba el túnel al arrancar la VPN. |
| `SEGUNDOS_ESPERA_CERTIFICADO` | `20` | Tiempo máximo esperando a leer la huella del certificado del FortiGate. |
| `DIRECTORIO_LOGS` | `logs/` | Carpeta de logs locales del MCP (fuera de git). |
| `FICHERO_LOG_MCP` | `logs/mcp-peticiones.log` | Fichero donde se guardan las peticiones del MCP. |
| `FICHERO_INTERRUPTOR_LOG` | `logs/mcp.on` | Interruptor: si el fichero existe, el modo log está activo. |
| `RUTA_WRAPPER_MCP` | `lanzar_mcp.sh` | Wrapper que lanza el MCP y, si el modo log está activo, registra las peticiones. |

El recomendador de pasos no tiene parámetros propios: reutiliza las comprobaciones que ya
usa el resto del menú.

## 3. Ejemplos de uso

Arrancar el menú:

```bash
./libra_mcp.sh
```

Ejemplo de cabecera recién instalado el entorno (nada hecho todavía):

```
libra-mcp · VPN: inactiva

 Pasos pendientes:
   • Configurar credenciales de la VPN  → opción 2
   • Construir imágenes  → opción 3
   • Obtener certificado del FortiGate  → opción 4
   • Registrar servidor MCP en Claude Code  → opción 5
```

Ejemplo cuando todo está instalado pero la VPN está parada:

```
libra-mcp · VPN: inactiva

 Pasos pendientes:
   • Arrancar la VPN  → opción 7
```

Ejemplo cuando el entorno está listo para usar (la VPN en marcha, con su IP):

```
libra-mcp · VPN: activa

 ✔ VPN en marcha · IP del túnel: 10.20.30.40/32. Abre Claude Code.
```
