# horizon_scripts
Check out [vaughan's gist](https://github.com/hilts-vaughan/hilts-vaughan.github.io/blob/master/_posts/2022-12-16-installing-horizon-xi-linux.md#install-horizonxi---steam-play-steam-deck--other-systems) for the step-by-step instructions if you run into trouble.

This script should:
- attempt to download/install v1.0.1
- add the steam shortcut
- subsequently update your launcher version

### Installation

In desktop mode:

Download this script, and run like so in konsole:

```
./install-or-update-horizon.sh
```

Or, for the incredibly lazy, open konsole, and paste:
```
(curl -s -L --max-redirs 5 --output ./install-or-update-horizon.sh https://raw.githubusercontent.com/trentondyck/horizon_scripts/main/install-or-update-horizon.sh) && chmod +x install-or-update-horizon.sh && ./install-or-update-horizon.sh
```

- After the first installation is complete and you have installed files from the official launcher, rerun the script to upgrade to the latest:

```
./install-or-update-horizon.sh
```

For any update after the first you can copy to your desktop and run it with double click.

### Uninstallation

```
(curl -s -L --max-redirs 5 --output ./uninstall.sh https://raw.githubusercontent.com/trentondyck/horizon_scripts/main/uninstall.sh) && chmod +x uninstall.sh && ./uninstall.sh
```

### Images only

If you already installed everything and you just want the images, run this script and restart steam:

```
./images_only.sh
```

