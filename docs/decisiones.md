# Decisiones del proyecto libra-mcp

Bitácora de decisiones. Cada petición añade su propio bloque al final; lo anterior no se toca.

## 2026-11-11 — El script debe recomendar los pasos a realizar según el estado

### 1. La petición tal como se ha entendido

**Pendiente de confirmación del usuario.**

Al arrancar el menú, `libra_mcp.sh` comprueba el estado del entorno (con las
comprobaciones rápidas que ya existen) y muestra en la cabecera la **lista completa de
pasos pendientes, en orden lógico**, con la opción de menú que resuelve cada uno. El
alcance es instalación + VPN:

1. Docker Desktop arrancado (requisito previo; si falta, es lo primero que se recomienda).
2. Credenciales de la VPN configuradas (opción 2).
3. Imágenes construidas (opción 3).
4. Certificado del FortiGate guardado (opción 4).
5. Servidor MCP registrado en Claude Code (opción 5).
6. VPN en marcha: si todo lo anterior está pero el túnel está parado, recomendar
   arrancarla (opción 7).

No comprueba las conexiones Oracle, para no lanzar un contenedor Docker en cada arranque.
Cuando no queda nada pendiente, la cabecera muestra un mensaje de "todo listo".

### 2. Preguntas y respuestas

**P1 — ¿Dónde quieres que aparezca la recomendación de pasos?**
Opciones planteadas:
- (A) Ampliar la opción 6 "Ver estado": además del estado, que liste los pasos pendientes.
- (B) Mostrarla automáticamente al arrancar el menú (en la cabecera).
- (C) Una opción nueva dedicada tipo "¿Qué hago ahora?".

_R1: (A) **Al arrancar el menú**, en la cabecera._

**P2 — ¿Qué granularidad quieres en la recomendación?**
- (A) Solo el **siguiente paso** pendiente (el primero que falta en el orden lógico).
- (B) La **lista completa** de pasos pendientes, en orden.

_R2: (B) **Lista completa** de pasos pendientes, en orden._

**P3 — ¿Hasta dónde debe llegar la recomendación?**
- (A) Solo instalación (requisitos, imágenes, VPN configurada, certificado, MCP registrado).
- (B) Instalación + uso diario (además, si la VPN está parada, recomendar arrancarla).
  Todo con comprobaciones rápidas.
- (C) Lo anterior + comprobar si hay conexiones Oracle guardadas. Ojo: esto lanza un
  contenedor Docker en cada arranque del menú y lo ralentiza.

_R3: (B) **Instalación + VPN**, con comprobaciones rápidas. No comprueba conexiones Oracle._

### 3. Fuentes analizadas

- `libra_mcp.sh` (versión del commit 400302b): funciones `comprobar_requisitos`,
  `ver_estado`, `mostrar_resumen_vpn` y las comprobaciones `*_disponible` / `*_activo`.

### 4. Decisiones

- **Dónde:** la recomendación se muestra automáticamente al arrancar el menú, en la
  cabecera. Por qué: es lo más proactivo; el usuario ve qué le falta sin tener que entrar
  a ninguna opción.
- **Qué:** lista completa de pasos pendientes, en orden lógico, cada uno con su número de
  opción. Por qué: lo pidió así el usuario; de un vistazo ve todo lo que queda.
- **Alcance:** instalación + VPN, usando solo las comprobaciones rápidas que ya existen.
  Por qué: cubre lo que de verdad bloquea el uso sin penalizar el arranque del menú.
- **Implementación:** función `mostrar_pasos_pendientes()`, llamada desde
  `mostrar_menu_principal()` justo debajo del resumen de VPN. Reutiliza
  `docker_disponible`, `imagen_existe`, `vpn_configurada`, `certificado_guardado`,
  `claude_disponible`, `mcp_registrado` y `tunel_activo`. Usa un array indexado (válido en
  bash 3.2) y evita el fallo de array vacío bajo `set -u` saliendo antes de recorrerlo.
- **Caso sin Docker:** si Docker Desktop no está disponible, se recomienda solo arrancarlo,
  porque sin él no se puede comprobar el resto.

### 5. Alternativas descartadas

- **Integrarlo en "Ver estado" (opción 6) o en una opción nueva "¿Qué hago ahora?"**:
  descartado a favor de mostrarlo al arrancar; así el usuario no tiene que buscarlo.
- **Mostrar solo el siguiente paso pendiente**: descartado; el usuario prefiere la lista
  completa.
- **Comprobar también las conexiones Oracle**: descartado porque obliga a lanzar un
  contenedor Docker en cada repintado del menú y lo ralentiza.
- **Cachear el estado y recalcular solo tras cada acción**: se ofreció, pero de momento no
  se hace, porque las comprobaciones son rápidas y el menú ya consultaba el túnel en cada
  repintado. Queda anotado como posible mejora si el menú se notara lento.

### 6. Pendiente de comprobar

- En uso real, que las comprobaciones (sobre todo `claude mcp get`, la más lenta) no hagan
  el menú molestamente lento. Si lo fueran, aplicar el cacheo descartado en el punto 5.
- Que los estados detectados coincidan con la realidad en cada fase de la instalación.
  Enlaza con los cinco "Puntos pendientes de verificar" del `CLAUDE.md`.

## 2026-11-11 — Mostrar el estado de la VPN en vez de "Todo listo"

### 1. La petición tal como se ha entendido

Cuando no queda ningún paso pendiente, en lugar de "✔ Todo listo" mostrar datos de que la
VPN está en marcha. Alcance confirmado con el usuario: **estado + IP del túnel**.

### 2. Preguntas y respuestas

**P1 — ¿Qué datos de la VPN mostrar?**
- (A) Estado + IP del túnel.
- (B) Estado + IP + interfaz (ppp0).
- (C) Solo el estado.

_R1: (A) **Estado + IP del túnel**._

### 3. Fuentes analizadas

- `libra_mcp.sh` (sobre el commit 79cd006): `mostrar_pasos_pendientes`, `mostrar_ip_tunel`.

### 4. Decisiones

- La rama "sin pendientes" solo se alcanza con el túnel activo, así que ahí la VPN siempre
  está en marcha: se muestra `✔ VPN en marcha` y, si se detecta, `· IP del túnel: X`.
- Se extrae el helper `obtener_ip_tunel()` para no duplicar el comando `docker/awk` entre
  `mostrar_ip_tunel` y la nueva línea.
- Si no se detecta IP, se omite esa parte y la VPN se sigue marcando en marcha.

### 5. Alternativas descartadas

- **Añadir la interfaz (ppp0)**: no aporta frente a la IP.
- **Mostrar solo el estado**: la cabecera ya muestra `VPN: activa`, sería redundante.

### 6. Pendiente de comprobar

- Confirmar en uso real el formato que devuelve `ip -4 addr show ppp0` (la IP sale con su
  máscara, p. ej. `10.20.30.40/32`); si se prefiere sin máscara, ajustar el `awk`.

## 2026-11-11 — Poder guardar una conexión que conecte como SYSDBA

### 1. La petición tal como se ha entendido

**Pendiente de confirmación del usuario.**

En "Añadir conexión", tras pedir los datos y antes de guardar, se pregunta
**"¿Conectar como SYSDBA? [s/N]"**. Si se responde que sí, la conexión se guarda añadiendo
`as sysdba` al `conn -save`, de modo que quede almacenada con ese rol y el MCP la use como
SYSDBA. El resumen previo a guardar refleja el rol. Para cambiar una conexión existente (o
quitarle el rol), se vuelve a añadir con el mismo nombre (sobrescribe). Solo SYSDBA; no se
añade un selector de roles general.

### 2. Preguntas y respuestas

**P1 — ¿Cómo quieres indicar el rol?**
- (A) Un sí/no "¿Conectar como SYSDBA?" al añadir la conexión (cubre el caso típico).
- (B) Un campo de rol más general (normal / SYSDBA / SYSOPER).

_R1: (A) **Sí/no SYSDBA** al añadir la conexión._

### 3. Fuentes analizadas

- `libra_mcp.sh` (commit d6e183b): `anadir_conexion`, `probar_conexion`,
  `ejecutar_sqlcl_por_tunel`, patrón de guardado `conn -save ... -savepwd`.
- SQLcl (imagen `libra-sqlcl-mcp`, `help connect`): `CONN <logon> AS {SYSASM | SYSBACKUP |
  SYSDBA | SYSDG | SYSOPER | SYSRAC | SYSKM}`. El rol se indica con `AS SYSDBA` al final.
- Comprobado que `conn -save` **solo persiste la conexión si conecta con éxito**: sin BD no
  crea nada en el almacén. Por tanto, que SQLcl guarde el rol y que el MCP reconecte por
  `-name` como SYSDBA **no se ha podido verificar aquí**; queda como punto a comprobar
  contra una BD de desarrollo real.

### 4. Decisiones

- Se añade la pregunta **"¿Conectar como SYSDBA?"** en `anadir_conexion`, con el helper
  `confirmar` (por defecto, no), justo antes del resumen.
- Si se acepta, se añade `" as sysdba"` a la cadena del `conn -save` y el resumen lo
  refleja con `" (AS SYSDBA)"`.
- `probar_conexion` **no** se toca: usa `conn -name`, así que reconecta con el rol si SQLcl
  lo ha persistido.
- Para cambiar el rol de una conexión existente se vuelve a añadir con el mismo nombre
  (sobrescribe); no se añade un flujo de edición aparte.
- Se mantiene el patrón de contraseña por tubería (no queda en argumentos, disco ni
  historial).

### 5. Alternativas descartadas

- **Selector de roles general** (SYSOPER, SYSASM…): descartado; se queda en sí/no SYSDBA,
  que es el caso real.
- **Flujo de edición de conexiones existentes**: innecesario, re-añadir con el mismo nombre
  ya sobrescribe.
- **Que `probar_conexion` informe de si la sesión es SYSDBA**: se ofreció, pero de momento
  no se añade para no cambiar la prueba de todas las conexiones. Queda como posible mejora.

### 6. Pendiente de comprobar

- Contra una BD de desarrollo real: que `conn -save ... as sysdba` **persista el rol**, que
  `conn -name` reconecte como SYSDBA y, sobre todo, que **el MCP** lo haga. Verificar, ya
  conectado por nombre, con `SELECT sys_context('USERENV','ISDBA') FROM dual;` (debe dar
  `TRUE`).
- Que el usuario indicado tenga de verdad privilegio SYSDBA en esa base de datos.
