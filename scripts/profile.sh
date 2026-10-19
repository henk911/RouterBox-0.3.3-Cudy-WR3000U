# Build profiles: one OpenWrt target and APK architecture each.
# Sourced by build.sh and package-apk.sh. Select with ROUTERBOX_PROFILE.
ROUTERBOX_PROFILE=${ROUTERBOX_PROFILE:-mt7621}
case "$ROUTERBOX_PROFILE" in
 mt7621)
  # ASUS RT-AX53U and other ramips/mt7621 routers: 32-bit MIPS, no FPU.
  ROUTERBOX_GOARCH=mipsle
  ROUTERBOX_APK_ARCH=mipsel_24kc
  ROUTERBOX_TARGET=ramips/mt7621
  ROUTERBOX_PLATFORM=MT7621
  ;;
 filogic)
  # MediaTek Filogic (MT7981/MT7986), e.g. Cudy WR3000/WR3000U: 64-bit ARMv8.0-A.
  ROUTERBOX_GOARCH=arm64
  ROUTERBOX_APK_ARCH=aarch64_cortex-a53
  ROUTERBOX_TARGET=mediatek/filogic
  ROUTERBOX_PLATFORM='MediaTek Filogic'
  ;;
 *)
  echo "Unknown ROUTERBOX_PROFILE '$ROUTERBOX_PROFILE' (expected mt7621 or filogic)" >&2
  exit 1
  ;;
esac
export ROUTERBOX_PROFILE ROUTERBOX_GOARCH ROUTERBOX_APK_ARCH ROUTERBOX_TARGET ROUTERBOX_PLATFORM
