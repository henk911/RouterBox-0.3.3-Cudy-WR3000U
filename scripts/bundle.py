#!/usr/bin/env python3
import hashlib,io,json,os,pathlib,tarfile,gzip,shutil
root=pathlib.Path(__file__).resolve().parent.parent
dist=root/'dist'
profile=os.environ.get('ROUTERBOX_PROFILE','mt7621')
bundle='routerbox-%s' % profile
files=['luci-app-routerbox-0.3.3-r2.apk','routerbox-core-1.14.2-r13.apk','keys/routerbox.pub','manifest.json','install.sh','README.ru.md','INSTALL.ru.md']
shutil.copyfile(root/'install.sh',dist/'install.sh')
# Commands in the bundled instructions refer to this bundle's own file names.
manifest=json.loads((dist/'manifest.json').read_text())
note='> Этот комплект собран для профиля `%s`: OpenWrt target `%s`, архитектура APK `%s`. Инструкция ниже написана для MT7621; команды установки те же, имена файлов указаны для этого комплекта.\n\n' % (profile,manifest['target'],manifest['arch'])
def names(text):
 text=text.replace('routerbox-mt7621', bundle)
 if profile!='mt7621':
  title,_,rest=text.partition('\n')
  text=title+'\n\n'+note+rest.lstrip('\n')
 return text
(dist/'README.ru.md').write_text(names((root/'README.md').read_text().replace('](docs/screenshots/', '](https://raw.githubusercontent.com/nekl3103/RouterBox/main/docs/screenshots/').replace('](docs/INSTALL.md', '](https://github.com/nekl3103/RouterBox/blob/main/docs/INSTALL.md')))
(dist/'INSTALL.ru.md').write_text(names((root/'docs/INSTALL.md').read_text().replace('](../README.md)', '](README.ru.md)')))
checks=''.join(hashlib.sha256((dist/name).read_bytes()).hexdigest()+'  '+name+'\n' for name in files)
(dist/'SHA256SUMS').write_text(checks)
files.append('SHA256SUMS')
with (dist/(bundle+'-0.3.3.tar.gz')).open('wb') as f:
 with gzip.GzipFile(fileobj=f,mode='wb',mtime=0,filename='') as gz:
  with tarfile.open(fileobj=gz,mode='w|') as tar:
   for name in sorted(files):
    data=(dist/name).read_bytes();info=tarfile.TarInfo(bundle+'/'+name);info.size=len(data);info.mode=0o755 if name=='install.sh' else 0o644;info.mtime=0;tar.addfile(info,io.BytesIO(data))
print(json.dumps({'bundle':bundle+'-0.3.3.tar.gz','bundle_bytes':(dist/(bundle+'-0.3.3.tar.gz')).stat().st_size,'app_apk_bytes':(dist/files[0]).stat().st_size,'core_apk_bytes':(dist/files[1]).stat().st_size}))
