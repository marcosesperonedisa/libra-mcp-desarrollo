#!/bin/bash
# Wrapper del servidor MCP de SQLcl.
# Lo lanza Claude Code en cada sesión (lo registra 'libra_mcp.sh', opción 5).
# Recibe como argumentos el comando docker que arranca el MCP y lo ejecuta.
#
# Si el "modo log" está activo (existe logs/mcp.on), registra en logs/mcp-peticiones.log
# SOLO las llamadas a herramientas del MCP (las peticiones con "method":"tools/call": la
# SQL que ejecuta, las búsquedas de procedimientos y sus parámetros), no el handshake.
# El stream completo sigue llegando a SQLcl intacto: solo se filtra la COPIA que va al
# log, así no se toca el protocolo MCP ni se guardan las respuestas de la base de datos.
#
# Usa bash (no sh) porque necesita "process substitution" >(...).

DIRECTORIO=$(cd "$(dirname "$0")" && pwd)
INTERRUPTOR="$DIRECTORIO/logs/mcp.on"
FICHERO_LOG="$DIRECTORIO/logs/mcp-peticiones.log"

if [ -f "$INTERRUPTOR" ]; then
  mkdir -p "$DIRECTORIO/logs"
  # tee manda el stream íntegro al comando (docker) y una copia al awk. El awk escribe
  # en el log solo las líneas tools/call, con una cabecera de sesión que solo aparece si
  # esa sesión llega a hacer alguna llamada (las que solo se presentan no dejan nada).
  tee >(awk -v f="$FICHERO_LOG" -v ts="$(date '+%Y-%m-%d %H:%M:%S')" '
    index($0, "\"method\":\"tools/call\"") > 0 {
      if (!cabecera) { printf "\n===== %s  sesion MCP =====\n", ts >> f; cabecera = 1 }
      print >> f
      fflush(f)
    }
  ') | "$@"
else
  exec "$@"
fi
