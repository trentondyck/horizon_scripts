# horizon_scripts
Check out [vaughan's gist](https://github.com/hilts-vaughan/hilts-vaughan.github.io/blob/master/_posts/2022-12-16-installing-horizon-xi-linux.md#install-horizonxi---steam-play-steam-deck--other-systems) for the step-by-step instructions if you run into trouble.

### Installation

This script should:
- see if you don't have the base game downloaded & extracted
- attempt to download/install v1.0.1
- add the steam shortcut
- after files are downloaded & extracted and the steam shortcut added, the next time you launch update-horizon.sh it should upgrade to the latest


Just download this script, and run like so in konsole:

```
./install-or-update-horizon.sh
```

Or, for the incredibly lazy, open konsole, and paste:
```
(curl -L --max-redirs 5 --output ./install-or-update-horizon.sh https://raw.githubusercontent.com/trentondyck/horizon_scripts/main/install-or-update-horizon.sh) && chmod +x install-or-update-horizon.sh && ./install-or-update-horizon.sh
```

For any update after the first you can copy to your desktop and run it with double click.

### Uninstallation

```
./uninstall.sh
```

### Images only

If you already installed everything and you just want the images, run this script and restart steam:

```
./images_only.sh
```

#### Support
Send gil to Fatso if you want to support the author
