# libra-mcp

Entorno en Docker para que Claude Code trabaje con bases de datos Oracle a través de la VPN FortiGate (SSL), usando el servidor MCP de SQLcl.

## Estructura

Hay dos contenedores, cada uno con una sola responsabilidad:

- **vpn** (`vpn_libra`): ejecuta `openfortivpn`. Se levanta una vez y queda en segundo plano con el túnel abierto.
- **sqlcl** (`libra-sqlcl-mcp`): servidor MCP de SQLcl. No se arranca con Compose; lo lanza Claude Code en cada sesión, compartiendo la red del contenedor VPN (`--network container:vpn_libra`), de modo que solo puede salir por el túnel.

El Mac no queda conectado a la VPN: solo el contenedor `vpn`.

```
libra-mcp/
├── libra_mcp.sh            # Menú de instalación, uso diario y conexiones
├── docker-compose.yml
├── vpn.conf.example        # Plantilla de configuración de la VPN
├── secretos/               # Credenciales (excluida de git)
├── vpn/
│   ├── Dockerfile
│   └── arrancar_vpn.sh
└── sqlcl/
    └── Dockerfile
```

## Requisitos

- Docker Desktop para macOS.
- Datos de la VPN: host y puerto del FortiGate, usuario y contraseña.
- Datos de cada base de datos: IP, puerto (normalmente 1521) y service name.

## Uso con el menú (recomendado)

```
./libra_mcp.sh
```

El script guía todos los pasos y muestra en la cabecera si la VPN está activa.

**Instalación** (una sola vez, en este orden):

1. Comprobar requisitos.
2. Configurar credenciales de la VPN: pide host, puerto, usuario y contraseña (sin mostrarla) y genera `secretos/vpn.conf` con permisos 600.
3. Construir imágenes.
4. Obtener certificado del FortiGate: conecta unos segundos con un contenedor temporal, muestra los datos y la huella del certificado, y solo la guarda si lo confirmas. Este paso también comprueba que Docker Desktop permite PPP.
5. Registrar el servidor MCP en Claude Code.

Después, arranca la VPN (opción 7) y añade tus conexiones Oracle (opción 11).

**Uso diario:** ver estado, arrancar, parar o reiniciar la VPN y ver su log.

**Conexiones Oracle:** listar, añadir, probar y eliminar.

- Al añadir, la contraseña se pide sin mostrarla y llega a SQLcl solo por una tubería: no queda en argumentos, ficheros ni historial.
- Probar ejecuta una consulta contra `dual` a través del túnel.
- Eliminar busca la conexión en el almacén de SQLcl, muestra qué se va a borrar y pide confirmación. Si el nombre coincide con más de una entrada, no borra nada.

**Mantenimiento:** actualizar SQLcl a la última versión y **desinstalar** el entorno (elimina el contenedor y las imágenes y, con confirmación propia en cada caso, el volumen de conexiones, el registro del MCP y los secretos de la VPN).

**Log del MCP:** activar/desactivar (opción 14) y ver (opción 15) el registro de las **peticiones** que el MCP hace a la base de datos (la SQL que ejecuta, las búsquedas de procedimientos…). Se guarda en `logs/mcp-peticiones.log` (fuera de git) y solo registra las peticiones, no los resultados. El cambio surte efecto al reiniciar Claude Code.

## Instalación manual (referencia)

Son los mismos pasos que hace el menú, por si prefieres ejecutarlos a mano.

### 1. Credenciales de la VPN

```
cp vpn.conf.example secretos/vpn.conf
chmod 600 secretos/vpn.conf
```

Edita `secretos/vpn.conf` con el host, el puerto, tu usuario y tu contraseña.

La carpeta `secretos/` está en el `.gitignore`. La contraseña queda en texto plano dentro de ese fichero: la protegen los permisos 600 y el cifrado del disco (FileVault).

### 2. Construir las imágenes

```
docker compose --profile mcp build
```

### 3. Primer arranque: obtener el certificado y comprobar PPP

```
docker compose run --rm vpn
```

Este primer arranque falla a propósito: `openfortivpn` rechaza el certificado del FortiGate y muestra en el error una línea con `--trusted-cert` seguida de una huella. Copia esa huella en la línea `trusted-cert` de `secretos/vpn.conf` y quítale el `#`.

Este paso también comprueba que Docker Desktop permite PPP. Si en lugar del error de certificado aparece algo sobre `/dev/ppp` o `pppd`, el problema es de PPP y hay que revisarlo antes de seguir.

### 4. Levantar la VPN en segundo plano

```
docker compose up -d vpn
docker logs -f vpn_libra
```

Cuando aparezca *Tunnel is up and running*, el túnel está listo. Con `restart: unless-stopped`, se levanta solo cada vez que arranca Docker Desktop.

### 5. Guardar las conexiones de Oracle

```
docker run -it --rm --network container:vpn_libra -v sqlcl_conexiones:/root/.dbtools libra-sqlcl-mcp /nolog
SQL> conn -save desa_libra_fin -savepwd usuario@IP_SERVIDOR:1521/servicio
SQL> cm list
SQL> exit
```

- SQLcl pide la contraseña por teclado sin mostrarla y la guarda cifrada en el volumen `sqlcl_conexiones`, nunca en la imagen.
- Para que la conexión entre con rol **SYSDBA**, añade `as sysdba` al final: `conn -save <nombre> -savepwd usuario@IP_SERVIDOR:1521/servicio as sysdba`. Desde el menú (opción 11), responde *sí* a *¿Conectar como SYSDBA?*.
- Usa la IP del servidor en lugar del nombre, al menos al principio: el DNS que envía la VPN puede no llegar al contenedor de SQLcl.
- Usa nombres de conexión que indiquen entorno y esquema (`desa_libra_fin`, `desa_libra_cli`…).
- Guarda solo conexiones de desarrollo o pruebas, nunca de producción.

### 6. Registrar el servidor MCP en Claude Code

```
claude mcp add -s user sqlcl -- "$PWD/lanzar_mcp.sh" docker run -i --rm --network container:vpn_libra -v sqlcl_conexiones:/root/.dbtools libra-sqlcl-mcp -mcp
claude mcp list
```

Usa `-i` sin `-t`: el servidor MCP se comunica por la entrada y salida estándar, y una terminal (TTY) corrompería los mensajes.

El MCP se registra a través del wrapper `lanzar_mcp.sh` (usa su ruta absoluta). Ese wrapper permite activar un **log de peticiones** del MCP desde el menú (opción 14); si no quieres esa función, puedes registrar el `docker run ...` directamente sin el wrapper.

Para probarlo, abre Claude Code y pide: "lista las conexiones disponibles".

## Uso diario

1. Arranca Docker Desktop (la VPN se levanta sola).
2. Comprueba el túnel si hace falta: `./libra_mcp.sh`, opción 6.
3. Abre Claude Code.

Si el contenedor de la VPN se reinicia (por ejemplo, porque el túnel se cae y se reconecta), el contenedor de SQLcl de la sesión en curso pierde la red. Reinicia Claude Code para que lo vuelva a lanzar.

## Comandos útiles

| Acción | Comando |
|---|---|
| Ver estado de la VPN | `docker ps --filter name=vpn_libra` |
| Ver log de la VPN | `docker logs -f vpn_libra` |
| Parar la VPN | `docker compose stop vpn` |
| Reiniciar la VPN | `docker compose restart vpn` |
| Añadir una conexión Oracle | Repetir el paso 5 |
| Actualizar SQLcl | `docker compose --profile mcp build --no-cache sqlcl` |

## Problemas frecuentes

- **Conecta con IP pero no con nombre**: es un problema de DNS. Usa la IP en la conexión guardada.
- **Error sobre `/dev/ppp` o `pppd` al arrancar la VPN**: Docker Desktop no está permitiendo PPP; revisar antes de seguir.
- **Error de certificado tras un cambio en el FortiGate**: repetir el paso 3 para obtener la nueva huella.
- **Claude Code no ve las herramientas de SQLcl**: comprobar que Docker Desktop y la VPN estaban arrancados antes de abrir Claude Code.
