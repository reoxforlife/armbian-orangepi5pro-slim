# Reporte de sesión — 2026-11-15 (tarde/noche, hora de Morelia)

Bitácora breve del proyecto kernel slim para la Orange Pi 5 Pro de Skynet:
compilación en HAL, instalación kernel-only en Skynet y mediciones.
El reporte completo está en `README.md`; el detalle técnico, en
`CONTROLADORES-REMOVIDOS.md` y `OPTIMIZACIONES.md`.

## Cronología

| Hora (CST) | Evento |
|---|---|
| ~17:43–17:53 | Framework oficial `armbian/build` listo en HAL (`/home/reox/builds/armbian-build`). Config slim aplicada en `userpatches/` a partir de la config real del kernel 6.1.115 de Skynet: **223 símbolos desactivados**, firmware 437 MB → ~6 MB vía `customize-image.sh`, -O2, módulos XZ, gobernador schedutil. Documentación escrita en `~/builds/slim-opi5pro/`. |
| 17:55 | **Ronda 1** de compilación (host, GCC 15.2, `PREFER_DOCKER=no`). U-Boot OK (18:03). |
| 19:15 | Ronda 1 **falla** compilando el kernel: `phy-rockchip-samsung-dcphy.c: 'struct v4l2_subdev' has no member named 'entity'` (driver colgando de MEDIA, apagado). |
| ~22:08–22:11 | Diagnóstico verificado en logs de HAL. Francisco aprueba la corrección y confirma requisito expreso: **la NPU debe funcionar** (es NPU Rockchip de 6 TOPS, no «TPU»). Verificado en config: `RKNPU=y`, Panfrost `=m`. |
| 22:12 | **Ronda 2** con `CONFIG_PHY_ROCKCHIP_SAMSUNG_DCPHY` apagado (respaldo `.bak-20261115-pre-dcphy`). |
| 22:20 | Ronda 2 **falla al enlazar vmlinux**: `rockchip_headset_core.c: undefined reference to iio_channel_get / iio_read_channel_raw` (headset consume IIO, apagado). |
| 22:21 | **Ronda 3** con `CONFIG_RK_HEADSET` apagado (respaldo `.bak-20261115-pre-headset`). |
| **22:30** | ✅ **Imagen lista**: `Armbian-unofficial_26.11.0-trunk_Orangepi5pro_resolute_vendor_6.1.172_minimal.img`, **1,182,793,728 bytes**, SHA256 `13dabb3d879a71a6f4ecb3194048222b4bcdf5fd9620936a3af68d68f8c374fc`. .deb de kernel 6.1.172 en `output/debs/`. |
| 22:32 | Francisco corrige el plan: **instalación SOLO del kernel** (.deb) sobre el sistema existente; se descarta la idea de probar la imagen completa por microSD como paso previo. |
| 22:34–22:41 | Imagen copiada también a Magi (para que Francisco la grabe en su microSD con balenaEtcher): primer intento vía túneles ~1.2 MB/s, abortado al 64 %; repetida **directa por LAN** HAL→Magi en ~12 s, SHA256 verificado idéntico. Lección: copias entre máquinas de casa, siempre LAN directa. |
| 22:35 | Preparación en Skynet: .deb (image/dtb/headers) copiados a `/home/rixuko/kernel-slim-6.1.172/` con SHA verificados; respaldo en `/home/rixuko/respaldo-pre-kernel-slim-20261115/` (tar de /boot 69 MB, tar de módulos 38 MB, registros dpkg/uname) y **snapshot Btrfs `/pre-kernel-slim-20261115` (ID 257)** creado sin problema pese al layout plano. |
| 22:39 | Reinicio controlado con el kernel **viejo** para línea base limpia: **2.742 + 16.669 = 19.412 s** (la lectura de 38.4 s de la mañana era el arranque tras un corte de luz). 26 contenedores antes y después. |
| 22:43 | Francisco: «Instala». |
| 22:45 | Instalación **parcial**: `linux-image` y `linux-dtb` 6.1.172 instalados y configurados, initrd generado, `/boot` ya apunta a 6.1.172. `linux-headers` queda **sin configurar** (faltan `bison`, `flex`, `libssl-dev`, `libelf-dev`); dpkg sale con error 1 y, por regla de seguridad, **no se reinicia**. Skynet sigue en 6.1.115, 26 contenedores arriba. Ojo: desde este momento cualquier reinicio (incluso por corte de luz) arrancaría ya con el kernel nuevo. |
| 22:46 | Francisco aprueba la opción 1: instalar las dependencias y reiniciar. apt instala `bison flex libssl-dev libelf-dev` (+ `m4`, `libzstd-dev` tras un tropiezo del resolver); los tres paquetes de kernel quedan en `ii`, auditoría dpkg limpia. |
| **22:48** | **Kernel slim en vivo**: Skynet arranca con **6.1.172-vendor-rk35xx**. Verificación completa OK: **26/26 contenedores Up**, NPU presente (card1, DRIVER=RKNPU), GPU con el driver Mali integrado igual que con el kernel viejo (panfrost disponible, no se liga), NVMe + discos del dock montados, LAN + NetBird + internet OK, Homepage 200 / Kuma 302. |
| 22:50 | Medición del arranque nuevo: **2.574 + 17.102 = 19.676 s** vs línea base 19.412 s → **empate técnico (+0.26 s)**; la ganancia del slim es tamaño, no arranque. Medición guardada en la carpeta de respaldo (`boot-time-kernel-nuevo.txt`). |
| — | Beneficios medidos en el servidor: módulos **2,300 → 1,018 .ko**, `/lib/modules` **140 MB → 18 MB**, `vmlinuz` **46.6 → 42.2 MB**, imagen **~1.7 GB → 1.2 GB**. |
| 22:52 | Francisco pide el reporte y preparar el repositorio público de GitHub con todo en el README (esta carpeta). La creación del repo en GitHub queda para después, con su sesión. |

## Estado al cierre

- Skynet corre el kernel slim 6.1.172 de forma definitiva; rollback disponible
  (snapshot Btrfs ID 257 + tars de respaldo) por si algún día se quiere volver.
- La imagen slim también está en Magi (`~/Downloads/`) para grabar en microSD
  y en HAL como artefacto de build; pendiente la publicación en GitHub y el
  torrent de distribución.
