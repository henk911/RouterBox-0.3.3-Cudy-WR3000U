#!/usr/bin/env python3
"""Deterministic staging. Only the selected core protocols are linked."""
import gzip, hashlib, json, os, pathlib, shutil
root = pathlib.Path(__file__).resolve().parent.parent
dist, build = root/'dist', root/'build'
profile = os.environ.get('ROUTERBOX_PROFILE', 'mt7621')
goarch = os.environ.get('ROUTERBOX_GOARCH', 'mipsle')
apk_arch = os.environ.get('ROUTERBOX_APK_ARCH', 'mipsel_24kc')
target = os.environ.get('ROUTERBOX_TARGET', 'ramips/mt7621')
app, core = build/'stage-app', build/'stage-core'
for p in (app, core):
    if p.exists(): shutil.rmtree(p)
    p.mkdir()
shutil.copytree(root/'files', app, dirs_exist_ok=True)
config = app/'etc/config/routerbox'
config.write_text(config.read_text().replace("option profile 'mt7621'", "option profile '%s'" % profile))
(app/'usr/bin').mkdir(parents=True, exist_ok=True)
(app/'usr/lib/routerbox').mkdir(parents=True,exist_ok=True)
with (dist/('routerbox-'+goarch)).open('rb') as src, (app/'usr/lib/routerbox/controller.gz').open('wb') as dst:
    with gzip.GzipFile(filename='',mode='wb',compresslevel=9,fileobj=dst,mtime=0) as zipped:
        shutil.copyfileobj(src,zipped)
name='sing-box-1.14.2-lx.12-%s.gz' % profile
with (dist/('sing-box-'+goarch)).open('rb') as src, (dist/name).open('wb') as dst:
    with gzip.GzipFile(filename='', mode='wb', compresslevel=9, fileobj=dst, mtime=0) as zipped:
        shutil.copyfileobj(src, zipped)
sha=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
info={'version':'1.14.2-lx.12-router.1','patches':['sing-tun-32bit-route-table'],'profile':profile,'target':target,'arch':apk_arch,'sha256':sha(dist/name),'size':(dist/('sing-box-'+goarch)).stat().st_size,'compressed_size':(dist/name).stat().st_size,'binary_sha256':sha(dist/('sing-box-'+goarch)),'controller_size':(app/'usr/lib/routerbox/controller.gz').stat().st_size,'controller_binary_size':(dist/('routerbox-'+goarch)).stat().st_size,'source':'https://github.com/Leadaxe/sing-box-lx','commit':'a97658c1d122a64b405621a94e1db971f8939f8d','tags':['with_gvisor','with_quic','with_wireguard','with_utls','with_clash_api','with_xhttp','with_awg']}
(app/'usr/share/routerbox').mkdir(parents=True,exist_ok=True)
(app/'usr/share/routerbox/core.json').write_text(json.dumps(info,indent=2)+'\n')
(dist/'manifest.json').write_text(json.dumps(info,indent=2)+'\n')
(core/'usr/lib/routerbox').mkdir(parents=True,exist_ok=True)
shutil.copyfile(dist/name,core/'usr/lib/routerbox/sing-box.gz')
for stage in (app,core):
    for p in stage.rglob('*'):
        os.chmod(p,0o755 if p.is_dir() or p in [app/'usr/bin/routerbox',app/'etc/init.d/routerbox',app/'etc/uci-defaults/90-routerbox',app/'usr/lib/routerbox/network',app/'usr/libexec/rpcd/routerbox'] else 0o644)
        os.utime(p,(0,0))
    os.utime(stage,(0,0))
print('Core compressed:',info['compressed_size'],'bytes; executable:',info['size'],'bytes; controller:',info['controller_size'],'bytes')
