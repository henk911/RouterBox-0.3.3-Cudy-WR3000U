#!/bin/sh
# One-step RouterBox installer for Cudy WR3000U and other MediaTek Filogic routers.
#
# From a computer:
#   ssh root@192.168.1.1 "wget -qO- https://github.com/henk911/RouterBox-0.3.3-Cudy-WR3000U/raw/main/setup.sh | sh"
# On the router:
#   wget -qO- https://github.com/henk911/RouterBox-0.3.3-Cudy-WR3000U/raw/main/setup.sh | sh
#
# Pass an install.sh mode after "sh -s --": --flash (default), --disabled, --check, --app-only.
#   wget -qO- .../setup.sh | sh -s -- --disabled
#
# The bundle is accepted only if its SHA256 matches the value below.
#
# Everything runs inside main(), so the shell has read the whole script
# before any command starts; with "wget | sh" a command reading stdin
# could otherwise swallow the rest of the script.

main() {
 set -eu
 FILE=routerbox-filogic-0.3.3.tar.gz
 SHA256=2c35ce18f08756d158d0eb3b1bd827ebd4992c9a70d6c9b5ecfd86e259242d15
 URL=${ROUTERBOX_URL:-https://github.com/henk911/RouterBox-0.3.3-Cudy-WR3000U/raw/main/release/$FILE}
 TARGET=mediatek/filogic
 ARCH_WANT=aarch64_cortex-a53
 WORK=/tmp/routerbox-setup

 MODE=${1:---flash}
 case "$MODE" in
  --flash|--disabled|--check|--app-only) ;;
  *) die "неизвестный режим $MODE (допустимо: --flash, --disabled, --check, --app-only)" ;;
 esac

 [ "$(id -u)" = 0 ] || die 'запустите от root'
 [ -f /etc/openwrt_release ] || die 'это не OpenWrt'
 . /etc/openwrt_release
 [ "${DISTRIB_TARGET:-}" = "$TARGET" ] || die "комплект для $TARGET, а прошивка роутера — ${DISTRIB_TARGET:-неизвестный target}"
 command -v apk >/dev/null || die 'нужен OpenWrt 25.12 или новее с менеджером пакетов APK'
 # OpenWrt lists the package architectures apk accepts in /etc/apk/arch;
 # apk --print-arch reports only apk-tools' generic build arch (aarch64).
 if [ -f /etc/apk/arch ]; then
  ARCHES=$(tr -s ' \t' '\n\n' < /etc/apk/arch)
  printf '%s\n' "$ARCHES" | grep -qx "$ARCH_WANT" || die "комплект для архитектуры $ARCH_WANT, а роутер принимает: $(echo $ARCHES)"
 else
  [ "$(uname -m)" = aarch64 ] || die "комплект для архитектуры $ARCH_WANT, а процессор роутера $(uname -m)"
 fi
 command -v wget >/dev/null || die 'нет wget (uclient-fetch)'

 # install.sh reserves /tmp (RAM) for unpacking the core: core + controller
 # + 24 MiB from this bundle's manifest.json. The bundle itself needs about
 # 36 MB while unpacking, so put it on flash when it would eat into that.
 TMP_NEED=75759868
 FLASH_NEED=26190309
 BUNDLE_ROOM=$((40*1024*1024))
 TMP_FREE=$(free_bytes /tmp); TMP_FREE=${TMP_FREE:-0}
 FLASH_FREE=$(free_bytes /overlay); FLASH_FREE=${FLASH_FREE:-0}
 if [ "$MODE" != --disabled ] && [ "$TMP_FREE" -lt $((TMP_NEED + BUNDLE_ROOM)) ] && [ "$FLASH_FREE" -ge $((FLASH_NEED + BUNDLE_ROOM)) ]; then
  WORK=/root/routerbox-setup
  echo "В /tmp мало места, комплект временно распаковывается во flash: $WORK"
 fi

 rm -rf "$WORK"
 mkdir -p "$WORK"
 trap 'rm -rf "$WORK"' EXIT INT TERM
 cd "$WORK"

 echo "Скачивание $FILE..."
 wget -q -O "$FILE" "$URL" </dev/null || die "не удалось скачать $URL"
 echo "$SHA256  $FILE" > "$FILE.sha256"
 sha256sum -c "$FILE.sha256" >/dev/null 2>&1 || die 'SHA256 архива не совпадает, установка отменена'
 echo 'SHA256 архива совпадает.'
 tar -xzf "$FILE" </dev/null
 # Free /tmp before install.sh measures it: the core is unpacked there later.
 rm -f "$FILE" "$FILE.sha256"

 cd routerbox-filogic
 ./install.sh "$MODE" </dev/null
 if [ "$MODE" = --disabled ]; then
  /etc/init.d/routerbox start </dev/null
  echo 'Контроллер запущен для настройки; VPN выключен, автозапуск отключён.'
 fi
 if [ "$MODE" != --check ]; then
  LAN=$(uci -q get network.lan.ipaddr 2>/dev/null || true)
  LAN=${LAN%%/*}
  echo "Адрес LuCI: http://${LAN:-192.168.1.1}"
 fi
}

die() { echo "RouterBox: $*" >&2; exit 1; }
free_bytes() { df -Pk "$1" 2>/dev/null | awk 'NR==2 {printf "%.0f", $4*1024}' || true; }

main "$@"
