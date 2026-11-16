# Optimizaciones de precompilación — build slim Orange Pi 5 Pro

Auditoría de la config completa (kernel vendor rk35xx 6.1 + opciones del framework)
para un servidor headless de producción en RK3588S. Prioridad: «arranca seguro»
por encima de «un poco más rápido». Todo cambio es opción soportada de Kconfig o
del framework; nada de parches externos.

## Aplicadas

| Cambio | Efecto esperado |
|---|---|
| `CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y`, fuera `CONFIG_CC_OPTIMIZE_FOR_SIZE` (**-O2**, decisión de Francisco: «vamos por velocidad aunque se gane poquito») | Kernel algo mayor pero más rápido en rutas calientes; el espacio sobra tras el recorte de firmware. |
| `CONFIG_LOCALVERSION="-slim1"` | Kernel nuevo coexiste con el actual en /boot; rollback = reapuntar symlinks. |
| `CONFIG_MODULE_COMPRESS_XZ=y` (era NONE) | /lib/modules mucho menor en disco; kmod estándar descomprime al cargar. |
| `CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y` (era ONDEMAND) | Gobernador integrado al scheduler (EAS): mejor respuesta en big.LITTLE A76/A55 con igual o menor consumo. `SCHED_MC` y `ENERGY_MODEL` ya venían activos. |
| Fuera `CONFIG_DEBUG_INFO` (+ BTF) | Módulos sin secciones .debug: menos tamaño en disco y compilación más rápida. Se pierde introspección eBPF CO-RE (bpftool), que su stack (Docker/NetBird/WireGuard) no usa. `KPROBES`, `KALLSYMS`, `DEBUG_FS` y `MAGIC_SYSRQ` se quedan. |
| Fuera `CONFIG_FUNCTION_TRACER`/`FUNCTION_GRAPH_TRACER`/`STACK_TRACER` | Sin sobrecoste de ftrace de funciones en producción. |
| Fuera `CONFIG_SLUB_DEBUG` | Sin depuración del asignador SLUB en caliente. |
| Framework: `BUILD_MINIMAL=yes`, `BUILD_DESKTOP=no`, `RELEASE=resolute` | Rootfs mínimo de servidor, sin escritorio ni paquetes de escritorio. |
| Framework: build en el HOST (`PREFER_DOCKER=no`) con cross-gcc 15.2 de Ubuntu 26.04 | El compilador decidido (no el del contenedor Debian del framework). |
| Recorte de firmware en `customize-image.sh` | −431 MB aprox. en la imagen (ver CONTROLADORES-REMOVIDOS.md). |

## Evaluadas y RECHAZADAS (con razón)

| Candidato | Razón del rechazo |
|---|---|
| **-O3** | El kernel no lo ofrece en Kconfig (solo -O2/-Os); forzarlo es no soportado y riesgoso en el kernel vendor. |
| **LTO** | Es ruta de Clang (LTO_CLANG); esta build es GCC. No aplica. |
| **GCC 16** | Posible (el framework toma el cross-gcc del host sin fijar versión), pero es la parte frágil: kernel vendor 6.1 + U-Boot Xunlong v2017.09 contra un compilador de 2026. Queda como segundo build experimental; además no aporta nada al tamaño. |
| Ajuste fino de CPU Cortex-A76/A55 (`-mcpu`) | arm64 en 6.1 no ofrece elección oficial por CPU en Kconfig; el kernel se compila genérico a propósito. Tocar CFLAGS sería no soportado. |
| Páginas de 16K/64K (`ARM64_16K_PAGES`) | Riesgo de compatibilidad con binarios/módulos y sin beneficio claro aquí; se queda 4K como el sistema actual. |
| `PREEMPT` completo (era VOLUNTARY) | Menor throughput en servidor por menor latencia que no necesita; se queda voluntary. |
| THP (Transparent Huge Pages) | Venía desactivado y el sistema rinde bien; activarlo puede introducir latencias impredecibles en cargas Docker. Se deja como está. |
| Compresión del kernel (XZ/LZ4) | En arm64 el Image no usa el mecanismo de autodescompresión de x86; no aplica. |
| Modo `shallow` para el git del kernel (`KERNEL_GIT=shallow`) | El propio framework lo desaconseja en kernels vendor: las rutas de parcheo fuerzan unshallow y se acaba descargando el historial completo igualmente. |
| Quitar DRM/GPU/display del kernel | Fuera de la lista autorizada y es la zona de riesgo para la consola local. |
| Quitar `DEBUG_FS` | Lo consultan drivers y diagnósticos; coste ~nulo. Se queda. |

## Resultado medido
(Se completa al terminar la compilación: tamaños de imagen .img/.img.xz, /usr/lib/firmware
y módulos dentro de la imagen, contra los ~1,7 GB / 437 MB / 140 MB del sistema actual.)
