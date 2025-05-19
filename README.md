# My personal .dotfiles/installation script

Use this commands to install the dotfiles:
```bash
cd /tmp
curl -L -o config.json https://raw.githubusercontent.com/janusz-bit/janusz-arch/main/archinstall-config.json
archinstall --config config.json
```

after installing arch linux run

```bash
curl -L -o config.json https://raw.githubusercontent.com/janusz-bit/janusz-arch/main/post-build.sh
chmod +x post-build.sh
./post-build.sh
```