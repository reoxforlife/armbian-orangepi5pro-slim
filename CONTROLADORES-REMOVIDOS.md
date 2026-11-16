# Imagen Armbian «slim» — Orange Pi 5 Pro (Skynet)

Build en HAL (i5-12500H, GCC 15.2 de la distro Ubuntu 26.04, `PREFER_DOCKER=no`),
framework oficial armbian/build, `BOARD=orangepi5pro BRANCH=vendor RELEASE=resolute
BUILD_MINIMAL=yes BUILD_DESKTOP=no`.

Base de la config: la config REAL que corre Skynet (`/boot/config-6.1.115-vendor-rk35xx`,
kernel vendor 6.1), guardada como `userpatches/linux-rk35xx-vendor.config`.
Sufijo propio: `CONFIG_LOCALVERSION="-slim1"` → el kernel resultante coexiste con el
actual en /boot (ruta de migración A).

## Lista de conservación fijada por Francisco (2026-11-15)

Se conserva SOLO lo que Skynet usa + dos respaldos:
- Ethernet Motorcomm yt6801 (única red) ✔ intocable
- NVMe PCIe (raíz) y dock USB 3 JMicron con discos 2 TB + 512 GB ✔ intocable
- WiFi onboard **solo brcmfmac** (presente, apagada/sin uso, como hoy) — respaldo
- Bluetooth (**conservado** «por si se requiere», decisión expresa de Francisco)
- Todo lo demás sale, incluidos los buses de usuario del header de expansión.

Intocables preservados y verificados en la config final: `STMMAC_ETH`, `MOTORCOMM_PHY`,
`NVME_CORE/BLK_DEV_NVME`, `USB_XHCI_HCD`, `USB_STORAGE`, `USB_UAS`, `MMC`, `BTRFS_FS`,
`OVERLAY_FS`, `FUSE_FS`, `ZRAM`, `NF_TABLES`, `BRIDGE`, `VETH`, `WIREGUARD`, `CGROUPS`,
`NAMESPACES`, `PWM_FAN`/`SENSORS_PWM_FAN`, `THERMAL`, `CPU_FREQ`, `SERIAL_8250` (consola),
`I2C_RK3X` e `SPI_ROCKCHIP` (buses INTERNOS: PMIC, térmica, fan), `GPIOLIB` interno.

## Removidos en el kernel (223 símbolos desactivados)

- **WiFi ajeno:** los 18 `WLAN_VENDOR_*` excepto `WLAN_VENDOR_BROADCOM` (quedan fuera
  Atheros/ath10k/11k/12k, Intel, MediaTek, Realtek/rtw88/rtw89, Ralink, Marvell, TI,
  Zydas, RSI, Silabs, ST, Cisco, Atmel, Intersil, ADMtek, Microchip, PureLiFi, Quantenna)
  + BSP fuera de árbol: `AIC8800_WLAN_SUPPORT`, `AIC_WLAN_SUPPORT`,
  `RK_WIFI_DEVICE_UWE5622`, `AP6XXX` (bcmdhd; el driver en uso verificado es brcmfmac).
  drivers/net/wireless era 49 MB de los 55 MB de drivers de red.
- **Media/cámaras/VPU/IR:** `MEDIA_SUPPORT` (apaga VIDEO_ROCKCHIP_CIF/ISP/RKISP1, DVB,
  códecs) y `RC_CORE` (infrarrojo).
- **Audio:** `SOUND` completo (HDMI/DP/ES8388 sin uso; servidor headless).
- **Bluetooth: NO removido** (ver lista de conservación).
- **Buses de usuario del header de expansión:** `SPI_SPIDEV`, `SPI_SLAVE`,
  `I2C_CHARDEV` (/dev/i2c-*), `GPIO_CDEV`, `GPIO_CDEV_V1`, `GPIO_SYSFS`, `W1` (1-Wire).
  Los buses internos (I2C/SPI/GPIO del SoC para PMIC y térmica) quedan intactos.
- **Entrada:** `INPUT_TOUCHSCREEN`, `INPUT_JOYSTICK`, `INPUT_TABLET`.
- **Sensores ajenos:** 146 `SENSORS_*` (I2C/PMBus/x86…) — quedan solo
  `SENSORS_PWM_FAN` (ventilador) y `SENSORS_DRIVETEMP` (temp. de discos).
- **IIO:** `IIO` completo.
- **Redes/protocolos fuera de uso:** `CAN`, `PPP`, `IEEE802154`, `TIPC`, `ATM`, `X25`,
  `LAPB`, `PHONET`, `CAIF`, `BATMAN_ADV`, `OPENVSWITCH`.
- **Almacenamiento:** `MD` (RAID/LVM por md; Btrfs no lo necesita), `STAGING`.
- **Filesystems exóticos (módulos):** REISERFS, JFS, GFS2, OCFS2, NILFS2, HFS/HFS+,
  JFFS2, UBIFS, ECRYPT, CEPH, NTFS (legado; queda NTFS3), UDF, VIRTIO_FS,
  y clientes de red `NFS_FS` y `CIFS` (sin uso registrado; reversible recompilando).

## Removidos en el rootfs — firmware (`userpatches/customize-image.sh`)

`/usr/lib/firmware`: **437 MB → ~6 MB**. Se conserva únicamente:
- `brcm/` recortado a la familia 4345/43455/43456 (firmware WiFi brcmfmac43456-sdio
  + BT BCM4345 `.hcd`) y archivos raíz `BCM4345C0.hcd`/`BCM4345C5.hcd`,
- `rockchip/` (dptx.bin), `arm/` (Mali), `edid/`, `regulatory.db*`.

Sale todo lo demás: `qcom/` (296 MB, otra plataforma), ath10k/11k/12k, mediatek,
rtw88/rtw89, aic8800, uwe5622, `rkwifi/` (19 MB de chips ajenos), intel/iwlwifi,
firmwares DVB sueltos, etc. Reversible reinstalando el paquete `armbian-firmware`.

## Conservados por duda (anotado según la regla «ante la duda, se queda»)

- `WL_ROCKCHIP` (glue de potencia WiFi SDIO de Rockchip; podría intervenir en el
  brcmfmac conservado).
- `DM` (device-mapper; solo se quitó `MD`).
- `6LOWPAN` (lo puede usar el Bluetooth conservado).
- `XFS_FS`, `F2FS_FS`, `EXFAT/VFAT`, `ISO9660`, `EROFS` (módulos pequeños, uso plausible).
- GPU/display DRM completo: fuera de la lista autorizada de recorte y es la zona de
  riesgo para la consola local; no se tocó.
- `USB_SERIAL` (posible cable de consola), `HID` (teclado local de emergencia).

## 2026-11-15 (segunda ronda de build)
- `# CONFIG_PHY_ROCKCHIP_SAMSUNG_DCPHY is not set` — Motivo: la primera build (17:55) falló al compilar el kernel: `phy-rockchip-samsung-dcphy.c: error: struct v4l2_subdev has no member named entity`. El driver depende de la infraestructura media/V4L2, apagada en esta config slim (CONFIG_MEDIA_SUPPORT off), y quedó colgando. Es un PHY de cámara/display (MIPI DCPHY) sin uso en Skynet (servidor headless, sin cámaras ni pantalla). Se apaga y se relanza la build. Respaldo de la config previa: linux-rk35xx-vendor.config.bak-20261115-pre-dcphy.
- Verificado intacto en la misma ronda: CONFIG_ROCKCHIP_RKNPU=y (NPU, petición expresa de Francisco) y CONFIG_DRM_PANFROST=m (GPU Mali).
- `# CONFIG_RK_HEADSET is not set` — Tercera ronda (2026-11-15, 22:20): la segunda build pasó la compilación de drivers pero falló al enlazar vmlinux: `drivers/headset_observe/rockchip_headset_core.c: undefined reference to iio_channel_get / iio_read_channel_raw`. El driver de detección de auriculares (audio jack) consume la API IIO, apagada en esta config slim (CONFIG_IIO off). Audio sin uso en Skynet. Se apaga y se relanza (iteración 3 de 3 máx.). Respaldo: linux-rk35xx-vendor.config.bak-20261115-pre-headset.
