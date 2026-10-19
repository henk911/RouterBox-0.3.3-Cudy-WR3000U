#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
ROOT="$PWD"
. ./scripts/profile.sh
export GOTOOLCHAIN=go1.26.8
export GOMODCACHE="$ROOT/build/gomod"
export GOCACHE="$ROOT/build/gocache"
export CGO_ENABLED=0
CORE_TAG=v1.14.2-lx.12
CORE_COMMIT=a97658c1d122a64b405621a94e1db971f8939f8d
TAGS=with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_xhttp,with_awg
mkdir -p build dist
[ -f build/go.mod ] || printf 'module routerbox-build-cache\n\ngo 1.25.0\n' > build/go.mod
if [ ! -d build/core-source ]; then
 git clone --depth 1 --branch "$CORE_TAG" https://github.com/Leadaxe/sing-box-lx.git build/core-source
 git -C build/core-source submodule update --init --depth 1 submodules/sing-tun submodules/gvisor submodules/utls submodules/wireguard-go
fi
[ "$(git -C build/core-source rev-parse HEAD)" = "$CORE_COMMIT" ] || { echo 'Unexpected core source revision' >&2; exit 1; }
./scripts/patch-core.sh
go mod download
export GOOS=linux GOARCH="$ROUTERBOX_GOARCH"
case "$GOARCH" in
 mipsle) export GOMIPS=softfloat ;;
 arm64) export GOARM64=v8.0 ;;
esac
echo "Profile $ROUTERBOX_PROFILE: $ROUTERBOX_TARGET, APK $ROUTERBOX_APK_ARCH, GOARCH=$GOARCH"
PKG=routerbox/internal/routerbox
go build -trimpath -ldflags "-s -w -buildid= -X $PKG.Profile=$ROUTERBOX_PROFILE -X '$PKG.Platform=$ROUTERBOX_PLATFORM'" -o "dist/routerbox-$GOARCH" ./cmd/routerbox
(
 cd build/core-source
 go build -trimpath -tags "$TAGS" -ldflags '-s -w -buildid= -checklinkname=0 -X github.com/sagernet/sing-box/constant.Version=1.14.2-lx.12-router.1' -o "../../dist/sing-box-$GOARCH" ./cmd/sing-box
)
python3 scripts/stage.py
./scripts/package-apk.sh
