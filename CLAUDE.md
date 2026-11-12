# CLAUDE.md — libra-mcp

## Contexto

Trabajo para EDISA, que desarrolla **LIBRA**, un ERP para empresas medianas y grandes (finanzas, tesorería, compras, ventas, SGA, producción, fiscalidad multipaís). El núcleo está en Oracle PL/SQL, Oracle Forms, Oracle Reports y BI Publisher.

Este proyecto (`libra-mcp`) es el entorno Docker que te permite trabajar directamente sobre bases de datos Oracle de LIBRA desde Claude Code, a través de la VPN corporativa.

Responde siempre en español.

## Arquitectura del entorno

- **Contenedor `vpn_libra`** (imagen `libra-vpn`): ejecuta `openfortivpn` contra el FortiGate (SSL VPN, usuario y contraseña). Se levanta con `docker compose up -d vpn` y queda en segundo plano. El Mac no está en la VPN, solo este contenedor.
- **Contenedor SQLcl** (imagen `libra-sqlcl-mcp`): servidor MCP de SQLcl (25.2 o superior). En `docker-compose.yml` lleva `profiles: ["mcp"]`, así que `docker compose up` **no** lo arranca: solo se construye. Claude Code lo lanza en cada sesión con `docker run -i --rm --network container:vpn_libra -v sqlcl_conexiones:/root/.dbtools libra-sqlcl-mcp -mcp`. Solo sale a la red por el túnel.
- **Credenciales de la VPN**: `secretos/vpn.conf` (permisos 600, excluido de git). Nunca leas, muestres ni copies su contenido.
- **Conexiones Oracle**: guardadas con nombre en el volumen `sqlcl_conexiones`. Las contraseñas están cifradas en el almacén de SQLcl y nunca las ves.
- **`libra_mcp.sh`**: menú en bash 3.2 (el de macOS) para instalación, uso diario y gestión de conexiones (listar, añadir, probar, eliminar).

Ficheros: `docker-compose.yml`, `vpn/Dockerfile`, `vpn/arrancar_vpn.sh`, `sqlcl/Dockerfile`, `vpn.conf.example`, `libra_mcp.sh`, `README.md`.

Detalles que conviene respetar al tocar el entorno:

- El **primer arranque de la VPN falla a propósito**: `openfortivpn` rechaza el certificado del FortiGate y, de ese error (y del log), se extrae la huella `trusted-cert` que luego se guarda en `secretos/vpn.conf`. Es el *bootstrap* del certificado, no un fallo real.
- Las **contraseñas (VPN y Oracle) viajan solo por tubería** hacia SQLcl (`printf ... | sql -S /nolog`): nunca en argumentos, disco ni historial. Mantén ese patrón al tocar el script.
- `libra_mcp.sh` es un **único script en bash 3.2**, organizado por secciones (utilidades de pantalla, comprobaciones, VPN, imágenes, conexiones) con dos menús (principal y conexiones).
- El dispositivo **PPP** (major 108) se habilita con `device_cgroup_rules` en Compose y `mknod /dev/ppp` en `arrancar_vpn.sh`, sin modo privilegiado.

## Comandos

No hay sistema de build ni suite de tests: el proyecto es shell + Docker. Casi todo pasa por el menú `./libra_mcp.sh`; estos son los comandos directos equivalentes:

```bash
./libra_mcp.sh                                        # menú: instalación, VPN y conexiones Oracle
docker compose --profile mcp build                    # construir las dos imágenes (vpn y sqlcl)
docker compose --profile mcp build --no-cache sqlcl   # actualizar SQLcl a la última versión
docker compose up -d vpn                               # levantar solo el túnel VPN en segundo plano
docker compose stop vpn                                # parar el túnel
docker logs -f vpn_libra                               # ver el log de la VPN
docker ps --filter name=vpn_libra                     # comprobar si el túnel está arriba
claude mcp add -s user sqlcl -- docker run -i --rm \   # registrar el servidor MCP en Claude Code
  --network container:vpn_libra -v sqlcl_conexiones:/root/.dbtools libra-sqlcl-mcp -mcp
```

## Puntos pendientes de verificar

Si toca revisar el entorno, estos puntos no se han probado aún en real:

1. Que Docker Desktop permite PPP dentro de su máquina virtual (`device_cgroup_rules: c 108:* rwm` y `mknod /dev/ppp` en `arrancar_vpn.sh`).
2. Que la huella del certificado se extrae bien del log de `openfortivpn` (busca `trusted-cert <64 hex>`).
3. Que `conn -save ... -savepwd` funciona cuando se envía a SQLcl por tubería (`sql -S /nolog`).
4. Que el borrado de conexiones encuentra la carpeta correcta en `/root/.dbtools/connections` buscando el nombre en `dbtools.properties`.
5. Si el DNS de la VPN llega al contenedor de SQLcl. Mientras tanto, las conexiones usan IP en lugar de nombre.

## Trabajo con la base de datos (MCP de SQLcl)

- Usa solo conexiones de **desarrollo o pruebas**. Si una conexión parece de producción por su nombre o sus datos, detente y pregunta.
- Antes de trabajar, lista las conexiones y confirma conmigo cuál usar si no lo he indicado. No cambies de conexión sin decirlo.
- Las consultas de lectura (SELECT, diccionario de datos) puedes ejecutarlas directamente.
- Antes de cualquier `INSERT`, `UPDATE`, `DELETE`, DDL o compilación de un package, muéstrame la sentencia completa y espera mi confirmación.
- Todo `UPDATE` o `DELETE` lleva `WHERE` explícito; propón antes el `SELECT COUNT(*)` equivalente.
- Al modificar un package, recuerda que el fuente oficial está en el Control de Fuentes de EDISA. Si compilas en la base de datos, avísame de que hay que subir el `.sql` para que no se desfase.
- El contenedor del MCP está aislado y no ve el disco del Mac salvo la carpeta `intercambio/` del proyecto, montada en `/intercambio`. Para compilar un package, deja el `.sql` ahí (en UTF-8, es una copia efímera) y compílalo con `@/intercambio/fichero.sql`; el fuente oficial conserva su codificación en el Control de Fuentes. Si `@` no funciona a través del MCP, envía el fuente como texto. Nunca dejes datos reales de clientes en `intercambio/` más de lo imprescindible (está fuera de git).
- Nunca inventes nombres de tablas, columnas, packages o programas de LIBRA. Compruébalos en el diccionario de datos (`ALL_TABLES`, `ALL_TAB_COLUMNS`, `ALL_SOURCE`…) o pregúntame.
- Usa los packages estándar de LIBRA (pkentorno, pkerr, pk_email, PKALRT…) antes que reinventar funcionalidad.
- Ejemplos y datos de prueba siempre ficticios; nunca copies datos reales de clientes fuera de la base de datos.

## Convenciones SQL (Oracle tradicional, compatible con 19c)

- Joins implícitos: `FROM a, b WHERE a.id = b.id`. Nunca `JOIN ... ON`.
- Outer join con `(+)` en el lado que puede faltar: `a.id = b.id(+)`.
- Se permiten `CASE`, `COALESCE`, `WITH` y funciones analíticas.
- Fechas siempre con máscara: `TO_DATE('01-01-2024','DD-MM-YYYY')`.
- Concatenación con `||`. Evita `SELECT *`.
- Top-N: ordena en subconsulta y filtra `ROWNUM` fuera.
- SQL dinámico (`EXECUTE IMMEDIATE`, `DBMS_SQL`): binds con `USING`, nunca concatenar valores. En Forms, `:bloque.item`.
- Comentarios de código en español.

## Ficheros

- Nunca cambies la codificación de un fichero existente (ANSI, Latin-1, Windows-1252…) ni lo conviertas a UTF-8. Detéctala antes (`file -i`, BOM).
- Conserva los finales de línea (CRLF en los fuentes de LIBRA) y no añadas BOM.
- `.fmb`, `.pll` y `.rdf` son binarios: no se editan como texto.
- Fichero `.sql` nuevo: Windows-1252, CRLF, sin BOM.
- Los scripts de shell de este proyecto (`.sh`) van en UTF-8 con LF.

## Forma de trabajar

- Componentes pequeños, con una sola responsabilidad.
- Nombres de funciones y variables en español, en minúsculas, en snake_case, sin eñes ni tildes.
- JavaScript, si lo hay, en ECMAScript 5.
- Si una petición no está clara, hazme preguntas concretas antes de ejecutar.
- Para cambios complejos (refactors, funcionalidades nuevas, decisiones de arquitectura), explícame qué vas a hacer y espera mi confirmación.
- No asumas requisitos implícitos: si falta información, pídela.
- Si una petición obliga a romper alguna de estas reglas, avísame antes en lugar de hacerlo en silencio.
