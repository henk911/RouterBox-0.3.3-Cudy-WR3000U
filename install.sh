#!/bin/sh
# Run this from the extracted bundle on the target router.
set -eu
cd "$(dirname "$0")"
MODE=${1:---flash}
case "$MODE" in --flash|--app-only|--check|--disabled) ;; *) echo 'Использование: ./install.sh [--flash|--app-only|--check|--disabled]' >&2; exit 1;; esac
[ "$(id -u)" = 0 ] || { echo 'Запустите от root' >&2; exit 1; }
[ -f /etc/openwrt_release ] || { echo 'Это не OpenWrt' >&2; exit 1; }
. /etc/openwrt_release
command -v apk >/dev/null || { echo 'Нужен OpenWrt с APK' >&2; exit 1; }
command -v jsonfilter >/dev/null || { echo 'Нужен jsonfilter' >&2; exit 1; }
sha256sum -c SHA256SUMS
# The bundle's manifest names the OpenWrt target and APK architecture it was built for.
WANT_TARGET=$(jsonfilter -i manifest.json -e '@.target' 2>/dev/null || true)
WANT_ARCH=$(jsonfilter -i manifest.json -e '@.arch')
[ -n "$WANT_TARGET" ] || WANT_TARGET=ramips/mt7621
[ "${DISTRIB_TARGET:-}" = "$WANT_TARGET" ] || { echo "Пакет предназначен для $WANT_TARGET, а прошивка роутера — ${DISTRIB_TARGET:-неизвестный target}" >&2; exit 1; }
# OpenWrt lists the package architectures apk accepts in /etc/apk/arch;
# apk --print-arch reports only apk-tools' generic build arch (aarch64, mipsel).
if [ -f /etc/apk/arch ]; then
 ARCHES=$(tr -s ' \t' '\n\n' < /etc/apk/arch)
 printf '%s\n' "$ARCHES" | grep -qx "$WANT_ARCH" || { echo "Пакет собран для архитектуры $WANT_ARCH, а роутер принимает: $(echo $ARCHES)" >&2; exit 1; }
else
 case "$WANT_ARCH" in aarch64_*) BASE=aarch64;; mipsel_*) BASE=mips;; *) BASE=;; esac
 MACHINE=$(uname -m)
 [ -n "$BASE" ] && [ "$MACHINE" = "$BASE" ] || { echo "Пакет собран для архитектуры $WANT_ARCH, а процессор роутера $MACHINE" >&2; exit 1; }
fi
printf 'Платформа: %s, %s\n' "$WANT_TARGET" "$WANT_ARCH"
FREE=$(df -Pk /overlay | awk 'NR==2 {printf "%.0f", $4*1024}')
TMP_FREE=$(df -Pk /tmp | awk 'NR==2 {printf "%.0f", $4*1024}')
MEM_FREE=$(awk '/^MemAvailable:/ {printf "%.0f", $2*1024}' /proc/meminfo)
APP=$(jsonfilter -i manifest.json -e '@.controller_size')
CORE=$(jsonfilter -i manifest.json -e '@.compressed_size')
CONTROLLER_RAW=$(jsonfilter -i manifest.json -e '@.controller_binary_size')
RAW=$(jsonfilter -i manifest.json -e '@.size')
REQUIRED=$((APP + CORE + 8*1024*1024))
[ "$MODE" != --app-only ] || REQUIRED=$((APP + 8*1024*1024))
printf 'Свободно flash: %s байт; требуется с резервом: %s байт\n' "$FREE" "$REQUIRED"
printf 'Свободно /tmp: %s байт; MemAvailable: %s байт\n' "$TMP_FREE" "$MEM_FREE"
[ "$FREE" -ge "$REQUIRED" ] || { echo 'Недостаточно flash. Используйте --app-only и RAM-загрузку либо внешнее хранилище.' >&2; exit 1; }
if [ "$MODE" != --disabled ]; then
 [ "$TMP_FREE" -ge $((RAW + CONTROLLER_RAW + 24*1024*1024)) ] || { echo 'Недостаточно места в /tmp для распаковки ядра' >&2; exit 1; }
 [ "$MEM_FREE" -ge $((RAW + CONTROLLER_RAW + 64*1024*1024)) ] || { echo 'Недостаточно свободной RAM для безопасного запуска' >&2; exit 1; }
fi
[ "$MODE" != --check ] || { echo 'Предварительная проверка пройдена; роутер не изменён.'; exit 0; }
if [ "$MODE" != --disabled ] && pidof sing-box >/dev/null 2>&1 && [ ! -S /tmp/routerbox/control.sock ]; then
 echo 'Уже работает другое ядро sing-box. Остановите его перед установкой RouterBox.' >&2
 exit 1
fi
mkdir -p /etc/apk/keys
cp keys/routerbox.pub /etc/apk/keys/routerbox.pub
apk update
if [ "$MODE" = --disabled ]; then
 [ ! -S /tmp/routerbox/control.sock ] || { echo 'RouterBox уже запущен; остановите его для установки без запуска.' >&2; exit 1; }
 apk add --no-scripts --no-commit-hooks ./routerbox-core-1.14.2-r13.apk ./luci-app-routerbox-0.3.3-r1.apk
 rm -f /etc/uci-defaults/90-routerbox
 /etc/init.d/routerbox disable
 mkdir -p /etc/routerbox
 chmod 700 /etc/routerbox
 [ -f /etc/routerbox/settings.json ] || /usr/bin/routerbox defaults > /etc/routerbox/settings.json
 chmod 600 /etc/routerbox/settings.json
 /etc/init.d/rpcd reload
 rm -f /tmp/luci-indexcache
 echo 'Установлено без запуска и автозапуска RouterBox.'
 exit 0
elif [ "$MODE" = --app-only ]; then
 apk add ./luci-app-routerbox-0.3.3-r1.apk
else
 apk add ./routerbox-core-1.14.2-r13.apk ./luci-app-routerbox-0.3.3-r1.apk
fi
echo 'Установлено. Откройте LuCI → Сервисы → RouterBox. Подключение по умолчанию отключено.'
