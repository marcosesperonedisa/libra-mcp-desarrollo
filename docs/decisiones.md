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

## 2026-11-11 — Ofrecer conexiones predeterminadas sin que el usuario tenga la contraseña

### 1. La petición tal como se ha entendido

**Pendiente de confirmación del usuario (en análisis).**

Poder distribuir a los desarrolladores un conjunto de conexiones Oracle de
desarrollo ya preparadas ("predeterminadas"), de modo que puedan usarlas desde el
MCP de SQLcl sin teclear ni conocer la contraseña de cada una.

### 2. Preguntas y respuestas

**P1 — ¿Qué nivel de protección necesita la contraseña de esas conexiones?**
- (A) Comodidad: que el usuario no tenga que conocerla ni teclearla, aunque viaje
  cifrada en su equipo (técnicamente recuperable por quien tenga el entorno).
- (B) Secreto real: que el usuario no pueda llegar a obtenerla de ningún modo
  (exige autenticar contra un servicio/proxy en servidor; bastante más complejo y
  choca con el modelo local actual).

_R1: (A) **Comodidad**. El usuario no tiene que conocer ni teclear la contraseña;
se acepta que viaje cifrada/recuperable en su equipo. Se mantiene el modelo local._

**P2 — ¿Cómo prefieres que lleguen las conexiones predeterminadas a cada equipo?**
- (A) Fichero de secretos out-of-band (como `vpn.conf`): un admin de EDISA rellena
  una vez un fichero con las conexiones de desarrollo (host, usuario, contraseña),
  se distribuye por canal seguro y el menú las da de alta en la máquina. Encaja con
  el patrón actual (`secretos/`, permisos 600, FileVault).
- (B) Almacén ya cifrado por SQLcl (o un Oracle Wallet): el admin las guarda una
  vez con `conn -save` y se distribuye el almacén cifrado; el desarrollador solo lo
  importa. La contraseña nunca viaja en claro, pero depende de que el almacén sea
  portable entre máquinas (a verificar).

_R2: Ni A ni B tal cual. Se opta por una **nueva opción en "gestionar conexiones"**
que obtiene los datos de las conexiones desde un **websocket** (origen centralizado).
Queda **aparcado** para desarrollar más adelante; no se implementa ahora._

### 3. Fuentes analizadas

- No se analizaron fuentes nuevas: la decisión se tomó a nivel de enfoque. Como
  referencia, el patrón de guardado actual es `conn -save ... -savepwd` por tubería
  en `anadir_conexion` (`libra_mcp.sh`), que habrá que reutilizar al provisionar.

### 4. Decisiones

- **Dirección elegida:** una nueva opción de menú dentro de "gestionar conexiones"
  que, en lugar de teclear los datos, los **obtiene desde un websocket**. Por qué:
  evita que el usuario conozca/introduzca los datos y centraliza el reparto.
- **Nivel de protección:** comodidad (R1); el desarrollador no teclea ni conoce los
  datos, pero la conexión acaba cifrada en su almacén de SQLcl como hasta ahora.
- **Alcance temporal:** **diferido**. Se deja anotado y se retomará más adelante.

### 5. Alternativas descartadas (por ahora)

- **(A) Fichero de secretos estilo `vpn.conf`** y **(B) almacén cifrado / Oracle
  Wallet**: se compararon con pros y contras, pero no se eligen de momento al
  preferirse el enfoque por websocket. Quedan como alternativas si el websocket no
  cuaja.

### 6. Pendiente de comprobar / definir (cuando se retome)

- Protocolo y origen del websocket: URL, **autenticación del desarrollador**, canal
  seguro (wss/TLS) y formato del mensaje (qué devuelve: host, puerto, servicio,
  usuario, ¿contraseña?, ¿rol SYSDBA?).
- Cómo se integra con el guardado actual (`conn -save` por tubería) sin dejar la
  contraseña en disco, argumentos ni historial.
- Encaje con la decisión "comodidad" (R1) ya tomada.

## 2026-11-11 — Opción "Desinstalar" en Mantenimiento

### 1. La petición tal como se ha entendido

**Pendiente de confirmación del usuario.**

Añadir en "Mantenimiento" una opción **"Desinstalar"** que elimine el entorno de forma
**guiada**. Al entrar, avisa de lo que va a hacer y pide una confirmación general;
luego ejecuta estos pasos en orden, cada uno **idempotente** (si la pieza no existe, lo
indica y sigue):

1. Parar y borrar el contenedor VPN `vpn_libra`.
2. Borrar las imágenes `libra-vpn` y `libra-sqlcl-mcp` (`docker rmi`).
3. **[confirmación extra — destructivo]** Borrar el volumen `sqlcl_conexiones`,
   avisando de que se **pierden las conexiones Oracle guardadas**.
4. **[confirmación extra]** Desregistrar el MCP en Claude Code
   (`claude mcp remove sqlcl -s user`).
5. **[confirmación extra — destructivo]** Borrar `secretos/vpn.conf`.

Al final, un resumen de qué se eliminó y qué se conservó. Los pasos 1-2 van bajo la
confirmación general (son reconstruibles); los pasos 3-5 piden confirmación propia por
ser pérdida de datos o configuración del usuario, con `confirmar` (por defecto, no).

### 2. Preguntas y respuestas

**P1 — ¿Qué alcance tiene "desinstalar"?** El entorno crea: imágenes, contenedor VPN
(`vpn_libra`), volumen de conexiones cifradas (`sqlcl_conexiones`), registro del MCP
en Claude Code y el fichero de secretos (`secretos/vpn.conf`).
- (A) Solo imágenes: parar/borrar el contenedor VPN (necesario para poder borrar la
  imagen) y `docker rmi` de las dos imágenes. Conserva volumen, secretos y MCP.
- (B) Completa guiada: lo anterior + borrar el volumen (se pierden las conexiones),
  desregistrar el MCP y borrar los secretos, pidiendo confirmación en cada paso
  destructivo.
- (C) A la carta: submenú para elegir pieza por pieza qué eliminar, con confirmación
  en lo destructivo.

_R1: (B) **Completa guiada**: parar/borrar contenedor VPN, borrar imágenes, borrar
volumen, desregistrar MCP y borrar secretos, con confirmación en cada paso destructivo._

### 3. Fuentes analizadas

- `libra_mcp.sh` (sobre el commit f56c5fe): menú (`mostrar_menu_principal`,
  `menu_principal`), `actualizar_sqlcl`, `registrar_mcp`, helpers (`confirmar`,
  `mostrar_aviso/ok/error`), predicados (`imagen_existe`, `mcp_registrado`) y
  constantes (`CONTENEDOR_VPN`, `CONTENEDOR_CERTIFICADO`, `IMAGEN_*`,
  `VOLUMEN_CONEXIONES`, `NOMBRE_MCP`, `FICHERO_VPN*`).

### 4. Decisiones

- Nueva opción **13) Desinstalar** en "Mantenimiento", con la función `desinstalar()`
  junto a `actualizar_sqlcl`.
- Nuevo predicado `volumen_existe()` para no borrar el volumen a ciegas.
- **Paso 1:** `docker compose down` + `docker rm -f` de refuerzo sobre `CONTENEDOR_VPN`
  y `CONTENEDOR_CERTIFICADO`. Por qué: deja el contenedor fuera (necesario para poder
  borrar la imagen) de forma idempotente aunque compose no esté o quedara algo colgado.
- **Paso 2:** borra solo las imágenes que existan; informa de las que no.
- **Confirmaciones:** una general para los pasos 1-2 (reconstruibles) y confirmación
  propia (`confirmar`, por defecto *no*) en volumen, MCP y secretos. Por qué: proteger
  lo que es pérdida de datos o configuración del usuario.
- **Resumen final** de qué se eliminó y qué se conservó.

### 5. Alternativas descartadas

- **(A) Solo imágenes** y **(C) a la carta**: descartadas a favor de la completa guiada
  (deja el sistema limpio, sin un MCP apuntando a imágenes borradas).
- **Borrar todo sin confirmaciones individuales:** descartado por el riesgo de perder
  conexiones o secretos sin avisar.
- **Añadir una fila en la tabla de "Comandos útiles" del README:** no; es un flujo
  interactivo con confirmaciones, no un comando suelto que copiar.

### 6. Pendiente de comprobar

- En uso real: que `docker compose down` + `docker rm -f` dejan el contenedor fuera y
  permiten el `docker rmi` sin el error "image is being used".
- Que `claude mcp remove "$NOMBRE_MCP" -s user` funciona en la instalación del usuario.
- Que `docker volume rm` no falla por "volume is in use": si el MCP sigue vivo en una
  sesión de Claude Code, habrá que cerrarla antes.

## 2026-11-11 — Modo de log de actividad del MCP de SQLcl

### 1. La petición tal como se ha entendido

**Pendiente de confirmación del usuario.**

Un "modo log" del MCP de SQLcl, con **fichero local** y **solo peticiones**:

- Un **wrapper** (script del repo) se interpone al arrancar el contenedor de SQLcl: si
  el modo está activo, copia con `tee` la **entrada** del MCP (las peticiones: la SQL
  que ejecuta, las búsquedas de procedimientos y los parámetros) a un fichero local; la
  **salida** (respuestas) pasa intacta y **no se guarda** (ni se toca el protocolo, ni
  se vuelcan datos de la BD). Si el modo está desactivado, el wrapper arranca el
  contenedor sin interponer nada.
- El **registro del MCP** (opción 5) pasa a apuntar al wrapper (una vez). **Activar o
  desactivar** el modo es un interruptor que se cambia desde el menú y surte efecto en
  la **siguiente sesión** de Claude Code (hay que reiniciarlo).
- En el menú: una opción para **activar/desactivar** el log del MCP (muestra el estado
  actual) y otra para **ver el log** (tail), al estilo del log de la VPN.
- El fichero vive en `logs/` (fuera de git).

Nota: adoptar el wrapper obliga a **re-registrar el MCP una vez** (opción 5); quien ya
lo tenga registrado con el comando antiguo debe volver a registrarlo.

### 2. Preguntas y respuestas

**Contexto técnico (hallazgos):**
- El contenedor de SQLcl lo lanza Claude Code por sesión (`docker run -i --rm … -mcp`),
  es efímero, sin nombre fijo y habla por stdio (JSON-RPC). `docker logs` no aplica
  como con la VPN.
- SQLcl MCP **ya registra** por defecto lo que ejecuta en una tabla de BD,
  `DBTOOLS$MCP_LOG` (en el esquema del usuario conectado), con las sentencias marcadas
  (`/* LLM in use */`) y `V$SESSION.MODULE/ACTION` poblados. No es un fichero local.
- No hay opción documentada para que SQLcl escriba lo ejecutado a un fichero aparte.

**P1 — ¿Qué fuente/enfoque prefieres para el log?**
- (A) **Log nativo en BD** (`DBTOOLS$MCP_LOG`): una opción de menú que lo consulte por
  una conexión y lo muestre. Es la fuente oficial del SQL ejecutado, pero es
  server-side (usa/crea una tabla en la BD), va por esquema y puede no recoger las
  búsquedas de procedimientos (solo el SQL).
- (B) **Fichero local capturando el stdio del MCP**: registrar el MCP envuelto en un
  wrapper que haga `tee` de entrada/salida a un fichero del host. Captura todo (tool
  calls, consultas, búsquedas de procedimientos y respuestas), es local y "modo"
  activable, pero el fichero es JSON-RPC crudo (verboso) y activar/desactivar implica
  re-registrar el MCP y reiniciar Claude Code.

_R1: (B) **Fichero local capturando el stdio del MCP** mediante un wrapper con `tee`._

**P2 — ¿Qué se registra en el fichero?**
- (A) Solo las **peticiones** al MCP (lo que se le pide: la SQL que ejecuta, las
  búsquedas de procedimientos, los parámetros de cada tool call). Cubre lo pedido y
  **no vuelca datos de la BD** al disco; fichero más ligero.
- (B) Peticiones **+ respuestas completas** (incluye los resultados que devuelve la
  BD). Más completo para depurar, pero el fichero crece mucho y puede contener **datos
  reales de clientes** en local.

_R2: (A) **Solo peticiones** (stdin). Se hace `tee` de la entrada; la salida no se
guarda, para no volcar datos de clientes ni tocar el protocolo._

### 3. Fuentes analizadas

- Documentación oficial de SQLcl (25.x): "Monitoring the SQLcl MCP Server" y "Using the
  Oracle SQLcl MCP Server". Hallazgo: el MCP registra por defecto en la tabla
  `DBTOOLS$MCP_LOG` (esquema del usuario), marca las sentencias (`/* LLM in use */`) y
  puebla `V$SESSION.MODULE/ACTION`. No hay opción documentada para volcar lo ejecutado a
  un fichero local.
- `libra_mcp.sh` (sobre el commit 7d1dfb6): `registrar_mcp`, `ver_log_vpn`, `ver_estado`,
  helpers (`confirmar`, `mostrar_*`) y menú.
- `sqlcl/Dockerfile`: imagen SQLcl con `ENTRYPOINT ["sql"]`.

### 4. Decisiones

- Enfoque **fichero local vía wrapper** (R1=B) y **solo peticiones** (R2=A): el wrapper
  `lanzar_mcp.sh` hace `tee` de la **entrada** (stdin) del contenedor; la salida pasa
  intacta. Por qué: ni se corrompe el protocolo MCP ni se vuelcan datos de la BD.
- **Wrapper genérico:** recibe el comando docker como argumentos (`"$@"`), para no
  duplicar ni desfasar el comando de arranque del MCP.
- **Interruptor por fichero** `logs/mcp.on`: activar/desactivar no obliga a re-registrar
  el MCP; `registrar_mcp` pasa a apuntar al wrapper una sola vez.
- **Menú:** nuevo bloque "Log del MCP" con `14) Activar/desactivar` y `15) Ver log`, sin
  renumerar el resto; línea de estado del log en `6) Ver estado`.
- `logs/` se añade al `.gitignore`.

### 5. Alternativas descartadas

- **Log nativo en BD (`DBTOOLS$MCP_LOG`):** descartado como fuente principal por ser
  server-side, ir por esquema y poder no recoger las búsquedas de procedimientos. Queda
  como consulta posible si en algún momento interesa el histórico en la BD.
- **Activar el modo re-registrando/desregistrando el wrapper:** descartado a favor del
  interruptor por fichero, que no obliga a tocar el registro del MCP cada vez.
- **Guardar también las respuestas:** descartado (R2) por tamaño y por contener datos
  reales de clientes.
- **Renumerar el menú** para meter las opciones en "Uso diario": descartado para no
  romper las referencias ya existentes (opción 5, 7, 11…).

### 6. Pendiente de comprobar

- En uso real: que `tee` no rompe el handshake del MCP ni introduce latencia perceptible.
- Que el contenido capturado (JSON-RPC línea a línea) resulta legible y útil; si no,
  valorar darle formato.
- Tamaño/rotación del fichero: de momento sin rotación; vigilar que no crezca sin control.
- Que, tras re-registrar el MCP (opción 5) y reiniciar Claude Code, el wrapper se usa de
  verdad y el log se rellena.

## 2026-11-11 — Registrar en el log solo las llamadas a herramientas (tools/call)

### 1. La petición tal como se ha entendido

**Confirmada.** En el log del MCP interesa guardar solo las peticiones `tools/call` (lo
que el asistente ejecuta: `connect`, `sql_run`, búsquedas de procedimientos y sus
parámetros), no el handshake de arranque (`initialize`, `tools/list`, etc.).

### 2. Preguntas y respuestas

Petición clara; solo se confirmó el plan. Decisión de diseño incluida y aprobada:
mantener una cabecera de sesión, pero **perezosa** (solo se escribe si la sesión llega a
hacer alguna llamada), para no dejar ruido en sesiones que solo se presentan.

### 3. Fuentes analizadas

- Log real `logs/mcp-peticiones.log` de la prueba previa: capturaba `initialize`,
  `notifications/initialized`, `server/discover`, `tools/list` (handshake) y, al
  ejecutar, `tools/call`.
- `lanzar_mcp.sh` (versión del modo log, aún sin commitear).

### 4. Decisiones

- El wrapper pasa de `#!/bin/sh` a `#!/bin/bash` para usar *process substitution* `>(...)`.
- En vez de `tee -a fichero`, se usa `tee >(awk …)`: el `tee` manda el stream íntegro a
  docker (intacto) y una copia al `awk`, que escribe en el log solo las líneas que
  contienen `"method":"tools/call"`. Por qué: el stream hacia SQLcl debe quedar byte a
  byte; se filtra solo la copia, no lo que ve el MCP.
- Cabecera de sesión **perezosa** (solo si hay al menos un `tools/call`).

### 5. Alternativas descartadas

- **Filtrar con `grep`:** válido, pero el `awk` permite además la cabecera perezosa en un
  solo paso.
- **Reprocesar el stream hacia docker** (p. ej. `awk … {print}` en la tubería principal):
  descartado; reconstruir el stream del protocolo es arriesgado. Mejor dejar el camino a
  docker con `tee` (byte a byte) y filtrar solo la copia.
- **Quitar del todo la cabecera de sesión:** se mantiene una, pero perezosa, por
  legibilidad sin añadir ruido.

### 6. Pendiente de comprobar

- En real: que el `awk` de la copia no afecta al rendimiento del MCP con uso intenso.
- Que las líneas `tools/call` reales caben en una sola línea (JSON compacto); si alguna
  viniera multilínea, habría que revisar el filtrado por línea.

## 2026-11-12 — Importar conexiones desde un JSON en Base64

### 1. La petición tal como se ha entendido

Mientras no exista el websocket que importará las conexiones, añadir una opción **puente**
en el submenú **Gestionar conexiones** (11) que permita **importar una o varias conexiones
Oracle a partir de una cadena Base64**. La cadena, al decodificarse, contiene un JSON con
este formato (objeto cuyas claves son los nombres de conexión):

```json
{ "nombre": { "host": "10.10.10.1", "port": 1521, "service": "DESA", "usuario": "LIBRA_RO", "password": "xxYYzz112233" } }
```

Por cada entrada del JSON se guarda una conexión en el almacén de SQLcl, igual que hace hoy
"Añadir" (`conn -save <nombre> -savepwd <usuario>/<clave>@<host>:<puerto>/<servicio>`), pero
tomando los datos del JSON en lugar de pedirlos por teclado.

*(Confirmada por el usuario.)*

### 2. Preguntas y respuestas

1. **¿Cómo se introduce la cadena Base64?** → *Pegar oculto*: se pega en el prompt sin que
   se vea en pantalla (como una contraseña), para no dejar las credenciales en el scrollback
   del terminal.
2. **¿Cómo confirmar antes de guardar (una o varias conexiones)?** → *Resumen y confirmar*:
   se muestra la lista de conexiones encontradas (nombre, usuario, host, puerto, servicio;
   nunca la contraseña), se pide una única confirmación y se importan todas. Los nombres que
   ya existan se sobreescriben, igual que al añadir con el mismo nombre.
3. **¿Qué analizador de JSON usar?** → *jq* (ya está en el Mac, `/usr/bin/jq`). La opción
   comprueba que esté presente y, si faltara, avisa de instalarlo (`brew install jq`).

### 3. Fuentes analizadas

- `libra_mcp.sh` (versión actual en `main`): funciones `anadir_conexion`,
  `pedir_clave_oracle`, `ejecutar_sqlcl_por_tunel`, `listar_conexiones`, patrones
  `PATRON_*` y submenú `menu_conexiones`.
- `docs/documentacion.md` y `README.md` (secciones de conexiones).
- Entorno local: `jq` 1.7.1-apple, `python3` (pyenv) y `base64` disponibles; el Base64 de
  ejemplo decodifica a JSON válido.

### 4. Decisiones

- **Ubicación:** nueva entrada en `menu_conexiones` (submenú 11), p. ej. "5) Importar desde
  JSON (Base64)". No toca el menú principal.
  *Por qué:* es gestión de conexiones y así queda junto a Añadir/Probar/Eliminar; además es
  el sitio donde vivirá luego la importación por websocket.
- **Entrada oculta:** la cadena se lee con `read -s` (como una contraseña).
  *Por qué:* el Base64 lleva contraseñas en claro; así no quedan a la vista ni en el
  scrollback.
- **Parseo con jq, por tubería:** `base64 -d` → `jq`, sin escribir la cadena ni el JSON en
  disco ni en argumentos. La contraseña vive solo en variables de shell que se limpian tras
  guardar, mismo patrón que `anadir_conexion`.
  *Por qué:* consistente con la norma del proyecto (contraseñas solo por tubería) y con el
  código existente.
- **Resumen + confirmación única** antes de guardar; nunca se muestra la contraseña.
- **Sobreescritura:** los nombres ya existentes se sobreescriben (comportamiento natural de
  `conn -save`). En el resumen se marca cuáles ya existían.
- **Validación:** cada campo se valida con los `PATRON_*` existentes. Si una conexión trae
  un campo inválido, se omite con aviso y se continúa con las demás (import parcial).
- **Sin rol SYSDBA:** el JSON no trae rol; las conexiones se guardan como normales.
- **Requisitos:** exige túnel activo e imagen de SQLcl (como `anadir_conexion`), porque
  `conn -save -savepwd` valida la conexión contra la base de datos al guardarla.

### 5. Alternativas descartadas

- **Pegar visible / leer de fichero:** descartado por seguridad (el Base64 lleva
  credenciales): visible queda en el scrollback, el fichero queda en disco.
- **Confirmar una a una / sin confirmar:** descartado; se prefiere un único resumen.
- **Parsear sin jq (python3 o dentro del contenedor):** descartado por complejidad; jq ya
  está y encaja con el estilo del menú.

### 6. Pendiente de comprobar

- Que `read -s` acepta pegar una cadena Base64 larga (de una sola línea) sin recortarla.
- Comportamiento con un JSON que traiga campos extra o un rol: se ignoran.
