#!/bin/bash
# Menú de instalación, uso diario y gestión de conexiones del entorno libra-mcp.
# Compatible con el bash 3.2 que incluye macOS.

set -u

cd "$(dirname "$0")" || exit 1
DIRECTORIO_PROYECTO=$(pwd)

readonly FICHERO_VPN="$DIRECTORIO_PROYECTO/secretos/vpn.conf"
readonly FICHERO_VPN_TEMPORAL="$DIRECTORIO_PROYECTO/secretos/vpn_sin_certificado.conf"
readonly CONTENEDOR_VPN="vpn_libra"
readonly CONTENEDOR_CERTIFICADO="vpn_libra_certificado"
readonly IMAGEN_VPN="libra-vpn"
readonly IMAGEN_SQLCL="libra-sqlcl-mcp"
readonly VOLUMEN_CONEXIONES="sqlcl_conexiones"
readonly RUTA_CONEXIONES="/root/.dbtools"
readonly NOMBRE_MCP="sqlcl"
readonly SEGUNDOS_ESPERA_TUNEL=30
readonly SEGUNDOS_ESPERA_CERTIFICADO=20

readonly PATRON_NOMBRE='^[A-Za-z0-9_.-]+$'
readonly PATRON_HOST='^[A-Za-z0-9.-]+$'
readonly PATRON_PUERTO='^[0-9]+$'
readonly PATRON_USUARIO_ORACLE='^[A-Za-z0-9_$#]+$'

# ===================== Utilidades de pantalla =====================

mostrar_ok()     { printf '\033[32m✔ %s\033[0m\n' "$1" >&2; }
mostrar_error()  { printf '\033[31m✘ %s\033[0m\n' "$1" >&2; }
mostrar_aviso()  { printf '\033[33m! %s\033[0m\n' "$1" >&2; }
mostrar_titulo() { printf '\n\033[1m== %s ==\033[0m\n\n' "$1" >&2; }

pausar() {
  printf '\n' >&2
  read -r -p "Pulsa Intro para continuar..." _
}

confirmar() {
  local respuesta
  read -r -p "$1 [s/N]: " respuesta
  case "$respuesta" in
    s|S|si|SI|Si) return 0 ;;
    *) return 1 ;;
  esac
}

# Pide un valor por teclado; devuelve el valor por defecto si se deja vacío
pedir_valor() {
  local texto="$1" valor_defecto="${2:-}" valor
  if [ -n "$valor_defecto" ]; then
    read -r -p "$texto [$valor_defecto]: " valor
  else
    read -r -p "$texto: " valor
  fi
  printf '%s' "${valor:-$valor_defecto}"
}

# Pide un valor y lo valida contra un patrón; vuelve a preguntar si no cumple
pedir_valor_validado() {
  local texto="$1" patron="$2" valor_defecto="${3:-}" valor
  while true; do
    valor=$(pedir_valor "$texto" "$valor_defecto")
    if [[ "$valor" =~ $patron ]]; then
      printf '%s' "$valor"
      return 0
    fi
    mostrar_error "Valor no válido."
  done
}

# Pide una contraseña sin mostrarla, dos veces para confirmarla
pedir_clave_confirmada() {
  local clave_1 clave_2
  while true; do
    read -r -s -p "Contraseña: " clave_1; printf '\n' >&2
    read -r -s -p "Repite la contraseña: " clave_2; printf '\n' >&2
    if [ -z "$clave_1" ]; then
      mostrar_error "La contraseña no puede estar vacía."
    elif [ "$clave_1" != "$clave_2" ]; then
      mostrar_error "Las contraseñas no coinciden."
    else
      printf '%s' "$clave_1"
      return 0
    fi
  done
}

# ===================== Comprobaciones =====================

docker_instalado()     { command -v docker >/dev/null 2>&1; }
docker_disponible()    { docker_instalado && docker info >/dev/null 2>&1; }
compose_disponible()   { docker compose version >/dev/null 2>&1; }
claude_disponible()    { command -v claude >/dev/null 2>&1; }
imagen_existe()        { docker image inspect "$1" >/dev/null 2>&1; }
vpn_configurada()      { [ -f "$FICHERO_VPN" ]; }
certificado_guardado() { grep -qE '^[[:space:]]*trusted-cert[[:space:]]*=' "$FICHERO_VPN" 2>/dev/null; }
tunel_activo()         { docker exec "$CONTENEDOR_VPN" ip link show ppp0 >/dev/null 2>&1; }
mcp_registrado()       { claude_disponible && claude mcp get "$NOMBRE_MCP" >/dev/null 2>&1; }

vpn_en_marcha() {
  [ "$(docker inspect -f '{{.State.Running}}' "$CONTENEDOR_VPN" 2>/dev/null)" = "true" ]
}

exigir_docker() {
  if ! docker_disponible; then
    mostrar_error "Docker no está disponible. Arranca Docker Desktop."
    return 1
  fi
}

exigir_imagen() {
  if ! imagen_existe "$1"; then
    mostrar_error "No existe la imagen $1. Constrúyela desde el menú de instalación."
    return 1
  fi
}

exigir_vpn_configurada() {
  if ! vpn_configurada; then
    mostrar_error "No existe secretos/vpn.conf. Configura antes las credenciales de la VPN."
    return 1
  fi
}

exigir_tunel() {
  exigir_docker || return 1
  if ! tunel_activo; then
    mostrar_error "El túnel VPN no está activo. Arráncalo desde el menú."
    return 1
  fi
}

# ===================== Requisitos y estado =====================

mostrar_comprobacion() {
  local texto="$1"; shift
  if "$@"; then mostrar_ok "$texto"; else mostrar_error "$texto"; fi
}

comprobar_requisitos() {
  mostrar_titulo "Requisitos"
  mostrar_comprobacion "Docker instalado" docker_instalado
  mostrar_comprobacion "Docker Desktop arrancado" docker_disponible
  mostrar_comprobacion "Docker Compose disponible" compose_disponible
  if claude_disponible; then
    mostrar_ok "Claude Code instalado"
  else
    mostrar_aviso "Claude Code no encontrado (necesario para registrar el servidor MCP)"
  fi
}

# Devuelve la IP del túnel VPN, o cadena vacía si el túnel no está activo
obtener_ip_tunel() {
  docker exec "$CONTENEDOR_VPN" ip -4 addr show ppp0 2>/dev/null | awk '/inet /{print $2}'
}

mostrar_ip_tunel() {
  local ip_tunel
  ip_tunel=$(obtener_ip_tunel)
  [ -n "$ip_tunel" ] && printf '  IP del túnel: %s\n' "$ip_tunel" >&2
}

ver_estado() {
  mostrar_titulo "Estado"
  exigir_docker || return
  mostrar_comprobacion "Imagen $IMAGEN_VPN" imagen_existe "$IMAGEN_VPN"
  mostrar_comprobacion "Imagen $IMAGEN_SQLCL" imagen_existe "$IMAGEN_SQLCL"
  mostrar_comprobacion "Credenciales VPN (secretos/vpn.conf)" vpn_configurada
  mostrar_comprobacion "Certificado del FortiGate guardado" certificado_guardado
  mostrar_comprobacion "Contenedor VPN en marcha" vpn_en_marcha
  if tunel_activo; then
    mostrar_ok "Túnel VPN activo"
    mostrar_ip_tunel
  else
    mostrar_error "Túnel VPN activo"
  fi
  mostrar_comprobacion "Servidor MCP registrado en Claude Code" mcp_registrado
}

# ===================== VPN: credenciales =====================

leer_certificado_actual() {
  grep -E '^[[:space:]]*trusted-cert[[:space:]]*=' "$FICHERO_VPN" 2>/dev/null \
    | head -n 1 | sed -E 's/^[^=]*=[[:space:]]*//'
}

escribir_config_vpn() {
  local host="$1" puerto="$2" usuario="$3" clave="$4" certificado="$5"
  mkdir -p "$(dirname "$FICHERO_VPN")"
  (
    umask 077
    {
      printf '# Configuración de openfortivpn (generada por libra_mcp.sh)\n'
      printf 'host = %s\n' "$host"
      printf 'port = %s\n' "$puerto"
      printf 'username = %s\n' "$usuario"
      printf 'password = %s\n' "$clave"
      [ -n "$certificado" ] && printf 'trusted-cert = %s\n' "$certificado"
      printf '# Reintenta la conexión cada 10 segundos si el túnel se cae\n'
      printf 'persistent = 10\n'
    } > "$FICHERO_VPN"
  )
  chmod 600 "$FICHERO_VPN"
}

configurar_vpn() {
  local host puerto usuario clave certificado
  mostrar_titulo "Configurar credenciales de la VPN"
  if vpn_configurada && ! confirmar "Ya existe una configuración. ¿Sobrescribirla?"; then
    return
  fi
  host=$(pedir_valor_validado "Host del FortiGate" "$PATRON_HOST")
  puerto=$(pedir_valor_validado "Puerto" "$PATRON_PUERTO" "443")
  usuario=$(pedir_valor_validado "Usuario de la VPN" '.+')
  clave=$(pedir_clave_confirmada)
  certificado=$(leer_certificado_actual)
  escribir_config_vpn "$host" "$puerto" "$usuario" "$clave" "$certificado"
  mostrar_ok "Configuración guardada en secretos/vpn.conf (permisos 600)."
  if [ -n "$certificado" ]; then
    mostrar_aviso "Se ha mantenido la huella del certificado anterior. Si has cambiado de FortiGate, vuelve a obtenerla."
  else
    mostrar_aviso "Siguiente paso: obtener el certificado del FortiGate."
  fi
}

# ===================== VPN: certificado =====================

crear_config_sin_certificado() {
  (
    umask 077
    grep -vE '^[[:space:]]*#?[[:space:]]*(trusted-cert|persistent)' "$FICHERO_VPN" > "$FICHERO_VPN_TEMPORAL"
  )
}

lanzar_contenedor_certificado() {
  docker rm -f "$CONTENEDOR_CERTIFICADO" >/dev/null 2>&1
  docker run -d --name "$CONTENEDOR_CERTIFICADO" \
    --cap-add NET_ADMIN --device-cgroup-rule 'c 108:* rwm' \
    -v "$FICHERO_VPN_TEMPORAL:/etc/openfortivpn/config:ro" \
    "$IMAGEN_VPN" >/dev/null
}

buscar_huella_en_log() {
  docker logs "$CONTENEDOR_CERTIFICADO" 2>&1 \
    | grep -oE 'trusted-cert [0-9a-fA-F]{64}' | head -n 1 | awk '{print $2}'
}

esperar_huella_certificado() {
  local segundos=0 huella=""
  while [ "$segundos" -lt "$SEGUNDOS_ESPERA_CERTIFICADO" ]; do
    sleep 1
    huella=$(buscar_huella_en_log)
    [ -n "$huella" ] && break
    segundos=$((segundos + 1))
  done
  printf '%s' "$huella"
}

mostrar_datos_certificado() {
  docker logs "$CONTENEDOR_CERTIFICADO" 2>&1 | grep -iE 'subject|issuer' >&2
}

limpiar_certificado_temporal() {
  docker rm -f "$CONTENEDOR_CERTIFICADO" >/dev/null 2>&1
  rm -f "$FICHERO_VPN_TEMPORAL"
}

guardar_certificado() {
  local huella="$1" fichero_temporal
  fichero_temporal=$(mktemp)
  grep -vE '^[[:space:]]*#?[[:space:]]*trusted-cert' "$FICHERO_VPN" > "$fichero_temporal"
  printf 'trusted-cert = %s\n' "$huella" >> "$fichero_temporal"
  cat "$fichero_temporal" > "$FICHERO_VPN"
  rm -f "$fichero_temporal"
}

obtener_certificado() {
  local huella
  mostrar_titulo "Obtener certificado del FortiGate"
  exigir_docker && exigir_vpn_configurada && exigir_imagen "$IMAGEN_VPN" || return
  mostrar_aviso "Se conecta al FortiGate solo para leer su certificado (hasta $SEGUNDOS_ESPERA_CERTIFICADO segundos)..."
  crear_config_sin_certificado
  if ! lanzar_contenedor_certificado; then
    mostrar_error "No se pudo arrancar el contenedor temporal."
    limpiar_certificado_temporal
    return
  fi
  huella=$(esperar_huella_certificado)
  if [ -z "$huella" ]; then
    mostrar_error "No se encontró la huella. Últimas líneas del log:"
    docker logs --tail 20 "$CONTENEDOR_CERTIFICADO" 2>&1 >&2
    limpiar_certificado_temporal
    return
  fi
  mostrar_datos_certificado
  limpiar_certificado_temporal
  printf '\nHuella SHA256: %s\n\n' "$huella" >&2
  if confirmar "¿Confías en este certificado y quieres guardarlo?"; then
    guardar_certificado "$huella"
    mostrar_ok "Huella guardada en secretos/vpn.conf."
    vpn_en_marcha && mostrar_aviso "Reinicia la VPN para aplicar el cambio."
  else
    mostrar_aviso "No se ha guardado nada."
  fi
}

# ===================== VPN: ciclo de vida =====================

esperar_tunel() {
  local segundos=0
  printf 'Esperando al túnel' >&2
  while [ "$segundos" -lt "$SEGUNDOS_ESPERA_TUNEL" ]; do
    if tunel_activo; then
      printf '\n' >&2
      mostrar_ok "Túnel VPN activo."
      mostrar_ip_tunel
      return 0
    fi
    printf '.' >&2
    sleep 1
    segundos=$((segundos + 1))
  done
  printf '\n' >&2
  mostrar_error "El túnel no se ha levantado en $SEGUNDOS_ESPERA_TUNEL segundos. Revisa el log de la VPN."
  return 1
}

arrancar_vpn() {
  mostrar_titulo "Arrancar VPN"
  exigir_docker && exigir_vpn_configurada && exigir_imagen "$IMAGEN_VPN" || return
  if ! certificado_guardado; then
    mostrar_error "Falta la huella del certificado. Obtenla desde el menú de instalación."
    return
  fi
  if vpn_en_marcha; then
    mostrar_aviso "El contenedor VPN ya está en marcha."
  else
    docker compose up -d vpn || return
  fi
  esperar_tunel
}

parar_vpn() {
  mostrar_titulo "Parar VPN"
  exigir_docker || return
  docker compose stop vpn && mostrar_ok "VPN parada."
}

reiniciar_vpn() {
  mostrar_titulo "Reiniciar VPN"
  exigir_docker || return
  docker compose restart vpn && esperar_tunel
  mostrar_aviso "Si Claude Code estaba abierto, reinícialo para que recupere la conexión."
}

ver_log_vpn() {
  mostrar_titulo "Log de la VPN (Ctrl+C para volver al menú)"
  exigir_docker || return
  trap ':' INT
  docker logs -f --tail 50 "$CONTENEDOR_VPN"
  trap - INT
}

# ===================== Imágenes =====================

construir_imagenes() {
  mostrar_titulo "Construir imágenes"
  exigir_docker || return
  docker compose --profile mcp build && mostrar_ok "Imágenes construidas."
}

actualizar_sqlcl() {
  mostrar_titulo "Actualizar SQLcl"
  exigir_docker || return
  docker compose --profile mcp build --no-cache sqlcl && mostrar_ok "SQLcl actualizado. Reinicia Claude Code para usar la nueva versión."
}

# ===================== Claude Code =====================

registrar_mcp() {
  mostrar_titulo "Registrar servidor MCP en Claude Code"
  if ! claude_disponible; then
    mostrar_error "No se encuentra el comando claude. Instala Claude Code primero."
    return
  fi
  if mcp_registrado; then
    confirmar "Ya existe un servidor MCP llamado '$NOMBRE_MCP'. ¿Reemplazarlo?" || return
    claude mcp remove "$NOMBRE_MCP" -s user
  fi
  claude mcp add -s user "$NOMBRE_MCP" -- docker run -i --rm \
    --network "container:$CONTENEDOR_VPN" \
    -v "$VOLUMEN_CONEXIONES:$RUTA_CONEXIONES" \
    "$IMAGEN_SQLCL" -mcp \
    && mostrar_ok "Servidor MCP registrado. Abre Claude Code y pide: lista las conexiones disponibles."
}

# ===================== Conexiones Oracle =====================

# Ejecuta comandos SQLcl leídos de la entrada estándar, sin red (no necesita VPN)
ejecutar_sqlcl_sin_red() {
  docker run -i --rm -v "$VOLUMEN_CONEXIONES:$RUTA_CONEXIONES" "$IMAGEN_SQLCL" -S /nolog
}

# Ejecuta comandos SQLcl leídos de la entrada estándar, a través del túnel VPN
ejecutar_sqlcl_por_tunel() {
  docker run -i --rm --network "container:$CONTENEDOR_VPN" \
    -v "$VOLUMEN_CONEXIONES:$RUTA_CONEXIONES" "$IMAGEN_SQLCL" -S /nolog
}

listar_conexiones() {
  mostrar_titulo "Conexiones guardadas"
  exigir_docker && exigir_imagen "$IMAGEN_SQLCL" || return
  printf 'connmgr list\nexit\n' | ejecutar_sqlcl_sin_red
}

pedir_clave_oracle() {
  local clave
  while true; do
    read -r -s -p "Contraseña de Oracle: " clave; printf '\n' >&2
    case "$clave" in
      '') mostrar_error "La contraseña no puede estar vacía." ;;
      *\"*) mostrar_error "La contraseña no puede contener comillas dobles." ;;
      *) printf '%s' "$clave"; return 0 ;;
    esac
  done
}

anadir_conexion() {
  local nombre usuario host puerto servicio clave
  mostrar_titulo "Añadir conexión"
  exigir_tunel && exigir_imagen "$IMAGEN_SQLCL" || return
  nombre=$(pedir_valor_validado "Nombre de la conexión (ej. desa_libra_fin)" "$PATRON_NOMBRE")
  usuario=$(pedir_valor_validado "Usuario de Oracle" "$PATRON_USUARIO_ORACLE")
  host=$(pedir_valor_validado "Host o IP del servidor" "$PATRON_HOST")
  puerto=$(pedir_valor_validado "Puerto" "$PATRON_PUERTO" "1521")
  servicio=$(pedir_valor_validado "Service name" "$PATRON_NOMBRE")
  printf '\nSe guardará: %s → %s@%s:%s/%s\n' "$nombre" "$usuario" "$host" "$puerto" "$servicio" >&2
  confirmar "¿Continuar?" || return
  clave=$(pedir_clave_oracle)
  # La contraseña viaja solo por la tubería: no queda en argumentos, disco ni historial
  printf 'conn -save %s -savepwd %s/"%s"@%s:%s/%s\nexit\n' \
    "$nombre" "$usuario" "$clave" "$host" "$puerto" "$servicio" | ejecutar_sqlcl_por_tunel
  clave=""
}

probar_conexion() {
  local nombre salida
  mostrar_titulo "Probar conexión"
  exigir_tunel && exigir_imagen "$IMAGEN_SQLCL" || return
  nombre=$(pedir_valor_validado "Nombre de la conexión" "$PATRON_NOMBRE")
  # El literal se construye concatenando para no confundir la orden con su resultado
  salida=$(printf "conn -name %s\nselect 'CONEXION_' || 'OK' as resultado from dual;\nexit\n" "$nombre" \
    | ejecutar_sqlcl_por_tunel 2>&1)
  if printf '%s' "$salida" | grep -q 'CONEXION_OK'; then
    mostrar_ok "La conexión $nombre funciona."
  else
    mostrar_error "La conexión $nombre ha fallado:"
    printf '%s\n' "$salida" >&2
  fi
}

# Devuelve los directorios del almacén cuyo dbtools.properties hace referencia al nombre
buscar_directorios_conexion() {
  docker run --rm -v "$VOLUMEN_CONEXIONES:$RUTA_CONEXIONES" -e NOMBRE_CONEXION="$1" \
    --entrypoint sh "$IMAGEN_SQLCL" -c '
      nombre_regex=$(printf "%s" "$NOMBRE_CONEXION" | sed "s/[.]/\\\\./g")
      grep -rlE "=${nombre_regex}\$" --include=dbtools.properties /root/.dbtools/connections 2>/dev/null \
        | while read -r fichero; do dirname "$fichero"; done'
}

borrar_directorio_conexion() {
  docker run --rm -v "$VOLUMEN_CONEXIONES:$RUTA_CONEXIONES" -e DIRECTORIO_CONEXION="$1" \
    --entrypoint sh "$IMAGEN_SQLCL" -c '
      case "$DIRECTORIO_CONEXION" in
        *..*) exit 1 ;;
        /root/.dbtools/connections/?*) rm -rf "$DIRECTORIO_CONEXION" ;;
        *) exit 1 ;;
      esac'
}

eliminar_conexion() {
  local nombre directorios total
  mostrar_titulo "Eliminar conexión"
  exigir_docker && exigir_imagen "$IMAGEN_SQLCL" || return
  printf 'connmgr list\nexit\n' | ejecutar_sqlcl_sin_red
  printf '\n' >&2
  nombre=$(pedir_valor_validado "Nombre de la conexión a eliminar" "$PATRON_NOMBRE")
  directorios=$(buscar_directorios_conexion "$nombre")
  total=$(printf '%s' "$directorios" | grep -c .)
  if [ "$total" -eq 0 ]; then
    mostrar_error "No se ha encontrado la conexión $nombre en el almacén."
    return
  fi
  if [ "$total" -gt 1 ]; then
    mostrar_error "El nombre coincide con varias entradas; no se borra nada por seguridad:"
    printf '%s\n' "$directorios" >&2
    return
  fi
  printf 'Se eliminará: %s\n' "$directorios" >&2
  confirmar "Esta acción no se puede deshacer. ¿Eliminar la conexión $nombre?" || return
  if borrar_directorio_conexion "$directorios"; then
    mostrar_ok "Conexión $nombre eliminada."
  else
    mostrar_error "No se pudo eliminar la conexión."
  fi
}

# ===================== Menús =====================

mostrar_resumen_vpn() {
  if ! docker_disponible; then
    printf 'Docker: \033[31mno disponible\033[0m\n'
  elif tunel_activo; then
    printf 'VPN: \033[32mactiva\033[0m\n'
  else
    printf 'VPN: \033[31minactiva\033[0m\n'
  fi
}

# Mira el estado del entorno y recomienda, en orden, lo que todavía falta por hacer.
# Reutiliza las comprobaciones rápidas; no consulta las conexiones Oracle para no
# lanzar un contenedor Docker cada vez que se repinta el menú.
mostrar_pasos_pendientes() {
  # Sin Docker no se puede comprobar casi nada: es siempre el primer paso.
  if ! docker_disponible; then
    printf '\n Pasos pendientes:\n'
    printf '   \033[33m•\033[0m Arranca Docker Desktop (y vuelve a abrir el menú)\n'
    return
  fi

  # Vamos acumulando lo pendiente en el mismo orden que se instala
  local pendientes=()
  if ! vpn_configurada; then
    pendientes+=("Configurar credenciales de la VPN  → opción 2")
  fi
  if ! imagen_existe "$IMAGEN_VPN" || ! imagen_existe "$IMAGEN_SQLCL"; then
    pendientes+=("Construir imágenes  → opción 3")
  fi
  if ! certificado_guardado; then
    pendientes+=("Obtener certificado del FortiGate  → opción 4")
  fi
  if ! claude_disponible; then
    pendientes+=("Instalar Claude Code y registrar el MCP  → opción 5")
  elif ! mcp_registrado; then
    pendientes+=("Registrar servidor MCP en Claude Code  → opción 5")
  fi
  # Arrancar la VPN solo tiene sentido cuando la instalación base ya está lista
  if vpn_configurada && certificado_guardado \
     && imagen_existe "$IMAGEN_VPN" && imagen_existe "$IMAGEN_SQLCL" \
     && ! tunel_activo; then
    pendientes+=("Arrancar la VPN  → opción 7")
  fi

  # Instalación completa y túnel activo: mostramos que la VPN está en marcha y su IP
  if [ "${#pendientes[@]}" -eq 0 ]; then
    local ip_tunel
    ip_tunel=$(obtener_ip_tunel)
    printf '\n \033[32m✔ VPN en marcha\033[0m'
    [ -n "$ip_tunel" ] && printf ' · IP del túnel: %s' "$ip_tunel"
    printf '. Abre Claude Code.\n'
    return
  fi

  printf '\n Pasos pendientes:\n'
  local paso
  for paso in "${pendientes[@]}"; do
    printf '   \033[33m•\033[0m %s\n' "$paso"
  done
}

mostrar_menu_principal() {
  clear
  printf '\033[1mlibra-mcp\033[0m · '
  mostrar_resumen_vpn
  mostrar_pasos_pendientes
  cat << 'MENU'

 Instalación
   1) Comprobar requisitos
   2) Configurar credenciales de la VPN
   3) Construir imágenes
   4) Obtener certificado del FortiGate
   5) Registrar servidor MCP en Claude Code

 Uso diario
   6) Ver estado
   7) Arrancar VPN
   8) Parar VPN
   9) Reiniciar VPN
  10) Ver log de la VPN

 Conexiones Oracle
  11) Gestionar conexiones

 Mantenimiento
  12) Actualizar SQLcl

   0) Salir

MENU
}

mostrar_menu_conexiones() {
  clear
  cat << 'MENU'
Conexiones Oracle

   1) Listar
   2) Añadir
   3) Probar
   4) Eliminar

   0) Volver

MENU
}

menu_conexiones() {
  local opcion
  while true; do
    mostrar_menu_conexiones
    read -r -p "Opción: " opcion
    case "$opcion" in
      1) listar_conexiones; pausar ;;
      2) anadir_conexion; pausar ;;
      3) probar_conexion; pausar ;;
      4) eliminar_conexion; pausar ;;
      0) return ;;
      *) mostrar_error "Opción no válida."; sleep 1 ;;
    esac
  done
}

menu_principal() {
  local opcion
  while true; do
    mostrar_menu_principal
    read -r -p "Opción: " opcion
    case "$opcion" in
      1)  comprobar_requisitos; pausar ;;
      2)  configurar_vpn; pausar ;;
      3)  construir_imagenes; pausar ;;
      4)  obtener_certificado; pausar ;;
      5)  registrar_mcp; pausar ;;
      6)  ver_estado; pausar ;;
      7)  arrancar_vpn; pausar ;;
      8)  parar_vpn; pausar ;;
      9)  reiniciar_vpn; pausar ;;
      10) ver_log_vpn; pausar ;;
      11) menu_conexiones ;;
      12) actualizar_sqlcl; pausar ;;
      0)  exit 0 ;;
      *)  mostrar_error "Opción no válida."; sleep 1 ;;
    esac
  done
}

menu_principal
