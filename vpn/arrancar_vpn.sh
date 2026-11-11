#!/bin/sh
set -e

# Crea el dispositivo PPP si la máquina virtual de Docker no lo expone
if [ ! -c /dev/ppp ]; then
  mknod /dev/ppp c 108 0
fi

# Arranca el túnel con la configuración montada en solo lectura
exec openfortivpn -c /etc/openfortivpn/config
