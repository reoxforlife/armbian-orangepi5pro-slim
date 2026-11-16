#!/bin/bash
# customize-image.sh — Recorte SLIM Orange Pi 5 Pro (se ejecuta en el rootfs antes de cerrar la imagen)
# Objetivo: /usr/lib/firmware de 437 MB a ~6 MB. Solo queda lo que el hardware real usa:
# WiFi/BT onboard BCM4345/43456 (brcmfmac + .hcd), firmware Rockchip (dptx), Mali (arm) y EDID.
FW=/usr/lib/firmware
if [[ -d "$FW" ]]; then
	echo "SLIM: firmware antes del recorte: $(du -sh "$FW" | cut -f1)"
	find "$FW" -mindepth 1 -maxdepth 1 \
		! -name brcm ! -name rockchip ! -name arm ! -name edid \
		! -name 'BCM4345C0.hcd' ! -name 'BCM4345C5.hcd' \
		! -name 'regulatory.db' ! -name 'regulatory.db.p7s' ! -name 'README.md' \
		-exec rm -rf {} +
	# Dentro de brcm: solo familia 4345/43455/43456 (WiFi de la placa + BT BCM4345)
	find "$FW/brcm" -mindepth 1 -maxdepth 1 \
		! -name '*4345*' ! -name '*43455*' ! -name '*43456*' \
		-exec rm -rf {} +
	echo "SLIM: firmware despues del recorte: $(du -sh "$FW" | cut -f1)"
fi
