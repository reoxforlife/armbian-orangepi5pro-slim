# Armbian «slim» para Orange Pi 5 Pro — kernel recortado para servidor headless

Una configuración de kernel Armbian (vendor rk35xx, 6.1.172) recortada a lo que un
**Orange Pi 5 Pro (RK3588S) usado como servidor headless** realmente necesita:
Ethernet, NVMe, USB, WiFi brcmfmac, Bluetooth, GPU Mali, NPU Rockchip y todo el
stack de red para Docker/NetBird — sin cámaras, sin media, sin audio, sin GPIO de
usuario, sin drivers WiFi de otros fabricantes y sin los ~431 MB de firmware de
otras plataformas que trae la imagen stock.

## Abstract (English)

A slimmed-down Armbian kernel configuration for the Orange Pi 5 Pro (RK3588S)
used as a headless home server. Starting from the real config of a production
board, 223 kernel symbols were disabled and the rootfs firmware was trimmed
from ~437 MB to ~6 MB, producing a 1.2 GB image (vs ~1.7 GB stock) and a module
tree of 18 MB / 1,018 modules (vs 140 MB / 2,300). Everything the server
actually uses is kept and verified working on real hardware: Ethernet, NVMe,
USB storage dock, brcmfmac WiFi, Bluetooth, Mali GPU, the Rockchip NPU (6 TOPS),
Docker and NetBird networking. Measured honestly: boot time did **not** improve
(19.41 s → 19.68 s, a technical tie) — the win is size and attack surface, not
speed. This repository contains the kernel config, the firmware-trim script,
and the full report (in Spanish) so anyone can reproduce the build with the
official armbian/build framework.

---

## Qué es y para quién

- **Hardware:** Orange Pi 5 Pro (SoC Rockchip RK3588S, 16 GB RAM, NVMe 500 GB
  + dock USB 3 con discos de 2 TB y 512 GB).
- **Uso:** servidor casero headless en producción (26 contenedores Docker:
  Nextcloud, Vaultwarden, Paperless-ngx, Gitea, WordPress, Uptime Kuma,
  NetBird, Traefik, cloudflared, etc.), sin pantalla, sin cámaras, sin audio.
- **Base:** framework oficial [armbian/build](https://github.com/armbian/build),
  `BOARD=orangepi5pro BRANCH=vendor RELEASE=resolute BUILD_MINIMAL=yes`.
- **Punto de partida:** la config real del kernel que corría el servidor
  (`/boot/config-6.1.115-vendor-rk35xx`), no una config genérica.

Si tu Orange Pi 5 Pro es un servidor sin periféricos de escritorio, esta config
te sirve tal cual o como punto de partida. Si usas la placa con pantalla,
cámaras, audio o el header GPIO, **no** es para ti sin ajustar la lista de
conservación (ver «Limitaciones»).

## La imagen resultante

| Artefacto | Valor |
|---|---|
| Imagen | `Armbian-unofficial_26.11.0-trunk_Orangepi5pro_resolute_vendor_6.1.172_minimal.img` |
| Tamaño | **1,182,793,728 bytes (~1.2 GB)** — la imagen stock equivalente: ~1.7 GB |
| SHA256 | `13dabb3d879a71a6f4ecb3194048222b4bcdf5fd9620936a3af68d68f8c374fc` |
| Kernel | 6.1.172 vendor rk35xx (`uname -r`: `6.1.172-vendor-rk35xx`) |
| Compilador | GCC 15.2 del host (Ubuntu 26.04), optimización **-O2** |
| Paquetes .deb | `linux-image` (187 MB), `linux-dtb` (122 MB), `linux-headers` (95 MB) en `output/debs/` |

## Resultados medidos (en el servidor real, no en teoría)

Mediciones tomadas en la propia Orange Pi 5 Pro antes y después de instalar el
kernel slim sobre el sistema existente:

| Métrica | Kernel stock 6.1.115 | Kernel slim 6.1.172 | Diferencia |
|---|---|---|---|
| Imagen completa | ~1.7 GB | **1.2 GB** | −0.5 GB aprox. |
| `/usr/lib/firmware` (en la imagen) | ~437 MB | **~6 MB** | −431 MB |
| Archivos de módulos `.ko` | 2,300 | **1,018** | −1,282 (−56 %) |
| `/lib/modules` en disco | 140 MB | **18 MB** | −122 MB (−87 %) |
| `vmlinuz` | 46.6 MB | **42.2 MB** | −4.4 MB |
| Arranque `systemd-analyze` (kernel) | 2.742 s | **2.574 s** | −0.17 s |
| Arranque `systemd-analyze` (userspace) | 16.669 s | 17.102 s | +0.43 s |
| **Arranque total** | **19.412 s** | **19.676 s** | **+0.26 s (empate técnico)** |
| Contenedores Docker tras el cambio | 26/26 | **26/26 Up** | sin cambios |

**Lectura honesta:** la ganancia es **tamaño y superficie de ataque**, no
velocidad de arranque. El kernel por sí solo arranca 0.17 s más rápido, pero el
userspace (dominado por los servicios) varía más que eso entre arranques.

Verificación post-instalación en el servidor (todo OK): NPU detectada
(`/sys/class/drm/card1`, `DRIVER=RKNPU`), GPU Mali ligada a su driver
(`/dev/mali0`, `panfrost.ko` presente y cargable), raíz NVMe y discos del dock
(`/mnt/hdd0`, `/mnt/hdd1`) montados, LAN 192.168.1.113 e internet funcionando,
Homepage HTTP 200 y Uptime Kuma HTTP 302.

## Qué se conserva y qué se quita

Detalle símbolo a símbolo en [`CONTROLADORES-REMOVIDOS.md`](CONTROLADORES-REMOVIDOS.md)
y decisiones de optimización en [`OPTIMIZACIONES.md`](OPTIMIZACIONES.md).

### Se conserva (verificado funcionando)

- **Red cableada:** Ethernet Motorcomm yt6801 (única red del servidor)
- **Almacenamiento:** NVMe PCIe (raíz Btrfs) y dock USB 3 con discos de 2 TB + 512 GB
- **WiFi onboard brcmfmac** (solo la familia Broadcom 4345/43455/43456; queda
  presente y apagada, como respaldo, igual que en el sistema stock)
- **Bluetooth** (conservado «por si se requiere», decisión expresa)
- **GPU Mali** (DRM completo sin tocar: es la zona de riesgo de la consola local)
- **NPU Rockchip** (`CONFIG_ROCKCHIP_RKNPU=y`, 6 TOPS)
- **Todo lo de red para contenedores:** NF_TABLES, BRIDGE, VETH, WireGuard,
  OverlayFS, FUSE, cgroups, namespaces, ZRAM
- **Internos del SoC intocables:** I2C/SPI/GPIO internos (PMIC, térmica,
  ventilador PWM), thermal, CPU freq (gobernador schedutil), consola serial

### Se quita (223 símbolos del kernel + recorte de firmware)

- **WiFi de otros fabricantes:** los 18 `WLAN_VENDOR_*` salvo Broadcom
  (Atheros/ath10k/11k/12k, Intel, MediaTek, Realtek rtw88/rtw89, Ralink,
  Marvell, TI, etc.) y los BSP fuera de árbol (AIC8800, UWE5622, bcmdhd).
  Solo `drivers/net/wireless` eran 49 MB de los 55 MB de drivers de red.
- **Media/cámaras/VPU/IR:** `MEDIA_SUPPORT` completo (ISP/CIF/DVB/códecs) y `RC_CORE`
- **Audio:** `SOUND` completo (HDMI/DP/codec sin uso en headless)
- **Header de expansión y buses de usuario:** `SPI_SPIDEV`, `I2C_CHARDEV`
  (/dev/i2c-*), `GPIO_CDEV`/`GPIO_SYSFS`, 1-Wire — ojo: los buses **internos**
  del SoC quedan intactos
- **Entrada de escritorio:** touchscreen, joystick, tablet
- **Sensores ajenos:** 146 `SENSORS_*` (quedan solo el del ventilador PWM y el
  de temperatura de discos)
- **IIO** completo
- **Protocolos sin uso:** CAN, PPP, IEEE802154, TIPC, ATM, X25, LAPB, PHONET,
  CAIF, BATMAN_ADV, Open vSwitch
- **Almacenamiento:** `MD` (RAID/LVM por md; Btrfs no lo necesita), `STAGING`
- **Filesystems exóticos:** ReiserFS, JFS, GFS2, OCFS2, NILFS2, HFS/HFS+,
  JFFS2, UBIFS, eCryptfs, Ceph, NTFS legado, UDF, VirtioFS, y los clientes
  NFS/CIFS (sin uso; reversible recompilando)
- **Firmware del rootfs** (`customize-image.sh`): de **437 MB a ~6 MB**; sale
  `qcom/` (296 MB, otra plataforma), ath*, mediatek, rtw*, aic8800, iwlwifi,
  firmwares DVB, etc. Se conserva solo `brcm/` recortado a la familia del chip
  onboard, `rockchip/`, `arm/` (Mali), `edid/` y `regulatory.db*`
- **Dos correctivos extra** (ver bitácora): `CONFIG_PHY_ROCKCHIP_SAMSUNG_DCPHY`
  y `CONFIG_RK_HEADSET`, drivers sin uso que colgaban de subsistemas apagados

### Optimizaciones aplicadas además del recorte

- **-O2** (`CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE`) en lugar del -Os stock:
  decisión deliberada «velocidad aunque se gane poquito»; hay espacio de sobra
- Módulos comprimidos con XZ (`CONFIG_MODULE_COMPRESS_XZ`)
- Gobernador CPU por defecto **schedutil** (EAS en big.LITTLE A76/A55)
- Fuera `DEBUG_INFO`/BTF, ftrace de funciones y `SLUB_DEBUG` (producción)
- GCC 16 fue evaluado y **descartado** para este kernel vendor 6.1 + U-Boot
  2017: es la combinación frágil y no aporta nada al tamaño; se compiló con el
  GCC 15.2 del host

## Cómo reproducir la compilación

Requisitos: una máquina x86-64 con Linux (la build original se hizo en un
i5-12500H con Ubuntu 26.04, GCC 15.2, **sin Docker**: `PREFER_DOCKER=no`),
~50 GB libres y el framework oficial.

```bash
git clone https://github.com/armbian/build armbian-build
cd armbian-build

# La config slim y el recorte de firmware van en userpatches/
cp linux-rk35xx-vendor.config userpatches/
cp customize-image.sh        userpatches/

./compile.sh build \
  BOARD=orangepi5pro BRANCH=vendor RELEASE=resolute \
  BUILD_MINIMAL=yes BUILD_DESKTOP=no \
  EXPERT=yes KERNEL_CONFIGURE=no PREFER_DOCKER=no
```

Resultados en `output/images/` (la .img y su .sha) y `output/debs/`
(linux-image, linux-dtb, linux-headers, linux-u-boot, armbian-firmware).

Notas:

- La config de este repo es la config **completa y final** (ya incluye los 223
  símbolos desactivados y los 2 correctivos), derivada de la config real del
  kernel 6.1.115 que corría el servidor de referencia.
- Espera **iteraciones**: al adelgazar un kernel vendor, algunos drivers
  «colgados» de subsistemas apagados solo aparecen al compilar/enlazar. Aquí
  hicieron falta 3 rondas (ver bitácora). Si tu hardware difiere, pueden salir
  otros.

## Cómo instalar SOLO el kernel (sin reinstalar el sistema)

La ruta usada en el servidor de referencia: la imagen completa ni se toca; se
instalan únicamente los paquetes `.deb` del kernel sobre el sistema Armbian
existente. El rootfs, los servicios y los archivos quedan intactos.

**Antes de instalar (respaldo, no opcional):**

```bash
# 1. Respaldo de /boot y de los módulos del kernel actual
tar czf boot-6.1.115.tar.gz /boot
tar czf modules-6.1.115.tar.gz /lib/modules/6.1.115-vendor-rk35xx
dpkg -l | grep -E 'linux-(image|dtb|headers)' > dpkg-kernel-actual.txt

# 2. Snapshot Btrfs del raíz (el layout de Armbian es Btrfs plano, ID 5;
#    el snapshot del árbol completo funcionó tal cual)
btrfs subvolume snapshot / /pre-kernel-slim-20261115
```

**Instalación:**

```bash
cd kernel-slim-6.1.172/
sha256sum *.deb   # contrasta con los .deb generados en tu build
dpkg -i linux-dtb-vendor-rk35xx_*.deb linux-image-vendor-rk35xx_*.deb
dpkg -i linux-headers-vendor-rk35xx_*.deb   # opcional, ver advertencia
```

Advertencias aprendidas en la instalación real:

- **Hold de paquetes:** en Armbian los paquetes de kernel suelen estar en
  *hold* (`apt-mark showhold`). `dpkg -i` funciona pese al hold; no necesitas
  quitarlo, y el hold se mantiene sobre el nombre del paquete tras instalar.
- **Los headers son opcionales** y en un servidor casi nunca se necesitan
  (solo sirven para compilar módulos externos). Su configuración exige
  herramientas de compilación que un servidor mínimo no tiene:
  `bison flex libssl-dev libelf-dev` (apt puede pedir además `m4` y
  `libzstd-dev`). Si `dpkg` deja los headers «sin configurar», el kernel y el
  DTB **no** se ven afectados: o instalas esas dependencias y dejas dpkg
  limpio, o retiras el paquete de headers (`dpkg --remove
  linux-headers-vendor-rk35xx`). No reinicies con un error de dpkg sin
  entender cuál paquete falló.
- Verifica **antes** de reiniciar que `/boot` apunta al kernel nuevo
  (`Image`, `dtb`, `initrd.img` y `uInitrd` → 6.1.172) y que el initrd se
  generó. Ten en cuenta que desde ese momento, **cualquier** reinicio
  (incluido uno por corte de luz) arrancará ya con el kernel nuevo: haz la
  prueba controlada cuanto antes.
- Reinicia y verifica: `uname -r`, `systemd-analyze`, contenedores/servicios,
  NPU (`/sys/class/drm/card1` → RKNPU), discos y red.

## Cómo regresar (rollback)

Dos vías independientes, ambas probadas al preparar la instalación:

1. **Snapshot Btrfs:** arranca desde un medio de rescate (la microSD con el
   sistema anterior sirve), monta el Btrfs y restaura el subvolumen
   `/pre-kernel-slim-20261115` como raíz.
2. **Respaldo de archivos:** restaura los tar de `/boot` y
   `/lib/modules/6.1.115-vendor-rk35xx` en su sitio y reapunta los symlinks de
   `/boot` al kernel anterior; o reinstala los `.deb` oficiales 6.1.115 si los
   conservas.

En el firmware no hay nada que regresar en esta ruta: instalar solo el kernel
**no** toca el paquete `armbian-firmware` del sistema (ver limitaciones).

## Bitácora de compilación: 3 rondas

Detalle completo en [`CONTROLADORES-REMOVIDOS.md`](CONTROLADORES-REMOVIDOS.md)
y cronología de la sesión en [`REPORTE-SESION.md`](REPORTE-SESION.md).

| Ronda | Resultado |
|---|---|
| 1 (17:55) | ❌ Falla al compilar el kernel (~19:15): `phy-rockchip-samsung-dcphy.c: error: 'struct v4l2_subdev' has no member named 'entity'` |
| 2 (22:12) | ❌ Pasa los drivers, falla al **enlazar vmlinux** (22:20): `rockchip_headset_core.c: undefined reference to 'iio_channel_get' / 'iio_read_channel_raw'` |
| 3 (22:21) | ✅ **Imagen lista 22:30** — rápida porque aprovechó la caché de la ronda 2 |

Los dos correctivos, ambos drivers sin uso en un servidor headless que
dependían de subsistemas apagados por el recorte:

1. **`CONFIG_PHY_ROCKCHIP_SAMSUNG_DCPHY`** — PHY MIPI de cámara/display que
   depende de la infraestructura media/V4L2 (`MEDIA_SUPPORT` apagado).
2. **`CONFIG_RK_HEADSET`** — detección de auriculares por jack que consume la
   API IIO (`IIO` apagado; el audio completo está fuera).

Antes de cada relanzamiento se verificó que `CONFIG_ROCKCHIP_RKNPU=y` (NPU) y
`CONFIG_DRM_PANFROST=m` (GPU) seguían intactos, y se guardó respaldo de la
config previa (`.bak-20261115-pre-dcphy`, `.bak-20261115-pre-headset`).

## Limitaciones honestas

- **Sin ganancia de arranque:** 19.41 s → 19.68 s es un empate técnico. Si
  buscas velocidad de boot, esto no es la palanca; la ganancia es tamaño
  (imagen −0.5 GB, módulos −87 %) y menor superficie de ataque.
- **Instalar solo el kernel no recorta el firmware del sistema instalado:**
  el recorte 437 MB → 6 MB vive en la **imagen** (y en el paquete
  `armbian-firmware` generado); si instalas únicamente los `.deb` de kernel
  sobre un sistema existente, su `/usr/lib/firmware` queda como estaba.
- **Pensado para ESTE hardware y ESTE uso:** Orange Pi 5 Pro como servidor
  headless con Ethernet, NVMe y dock USB. Sin HDMI/DP, sin cámaras, sin audio,
  sin GPIO de usuario, sin touchscreen. En otro escenario hay que revisar la
  lista de conservación símbolo a símbolo.
- **Kernel vendor 6.1:** es el kernel de Xunlong/Rockchip vía Armbian, no un
  mainline. La config depende de esa familia (`rk35xx`).
- **Headers sin configurar ≠ kernel roto:** ver la advertencia en la sección
  de instalación; es el tropiezo esperable de esta ruta y tiene salida limpia.

## Archivos de este repositorio

| Archivo | Qué es |
|---|---|
| `README.md` | Este reporte completo |
| `linux-rk35xx-vendor.config` | La config slim final, lista para `userpatches/` |
| `customize-image.sh` | El recorte de firmware del rootfs (437 MB → ~6 MB) |
| `CONTROLADORES-REMOVIDOS.md` | Lista símbolo a símbolo: qué se quitó, qué se conserva y por qué |
| `OPTIMIZACIONES.md` | Auditoría de precompilación: optimizaciones aplicadas y rechazadas con su razón |
| `REPORTE-SESION.md` | Bitácora breve de la sesión del 2026-11-15 (compilación, instalación, mediciones) |

## Licencia y notas

- Armbian y el kernel de Linux son **GPL** (el kernel, GPL-2.0). Este
  repositorio no redistribuye código de ninguno: contiene una **configuración**
  (`.config`), un script de personalización de imagen y documentación,
  compartidos para que cualquiera reproduzca la build con el framework
  oficial de Armbian.
- La imagen `.img` no se incluye en el repo por tamaño; se distribuye por
  torrent desde el servidor del proyecto, con su SHA256 publicado arriba.
- Proyecto de [Reox Lab](https://reoxlab.com) — bitácora y notas del homelab
  en Obsidian/Nextcloud del autor. Sin garantías: úsalo bajo tu propio riesgo,
  con respaldo, como se documenta aquí.
