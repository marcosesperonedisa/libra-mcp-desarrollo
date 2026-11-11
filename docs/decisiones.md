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
