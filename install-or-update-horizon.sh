#!/bin/bash

init(){

	export sd_link="false"
	if [[ $(df -h | grep " /home$" | awk '{print $4}' | sed 's/G//g') -le 60 ]]; then
		export compat_size=$((cd /home/deck/.local/share/Steam/steamapps && du --max-depth 1 -h) | grep compatdata | awk '{print $1}' | sed 's/G//g')
		export home_free_space=$(df -h | grep " /home$" | awk '{print $4}' | sed 's/G//g')
		export card_free_space=$(df -h | grep "/run/media" | awk '{print $4}' | sed 's/G//g')
		export sd_link="true"
	fi
	export config_json=$(sudo find /home/deck/.local/share/Steam/steamapps/compatdata/ -name config.json -type f | grep HorizonXI)
	export config_prefix=$(echo $config_json | sed 's/config.json$//g')
	export storage_json=$(echo ${config_prefix}storage.json)
	export base_downloaded_boolean=$(cat $storage_json | jq '.GAME_UPDATER.baseGame.downloaded')
	export base_extracted_boolean=$(cat $storage_json | jq '.GAME_UPDATER.baseGame.extracted')
	export updater_downloaded_boolean=$(cat $storage_json | jq '.GAME_UPDATER.updater.downloaded')
	export updater_extracted_boolean=$(cat $storage_json | jq '.GAME_UPDATER.updater.extracted')
	export horizon_json=$(curl https://api.github.com/repos/HorizonFFXI/HorizonXI-Launcher-Binaries/releases | jq '.')
	if [[ ${base_downloaded_boolean} == "true" && ${base_extracted_boolean} == "true" && ${updater_downloaded_boolean} == "true" && ${updater_extracted_boolean} == "true" ]]; then
		export latest_version=$(echo ${horizon_json} | jq -r '.[].name' | head -n1)
		# Since everythings done downloading we can clean up
		echo "Searching home directory for horizon zip, this may take a while..."
		sudo find /home -name "HorizonXI.zip" -type f | sed 's/ /\\ /g' | xargs -i rm {}
		export current_version=$(cat $config_json | jq -r '.__internal__.migrations.version' | sed 's/^/v/g')
	else
		# Let's hard code latest version to v1.0.1, since the installer isn't complete we need to download & complete the install on v1.0.1 before updating
		# See Note: https://github.com/hilts-vaughan/hilts-vaughan.github.io/blob/master/_posts/2022-12-16-installing-horizon-xi-linux.md#install-horizonxi---steam-play-steam-deck--other-systems
		export latest_version="v1.0.1"
	fi
	export download_url=$(echo ${horizon_json} | jq -r '.[] | select(.tag_name=="'${latest_version}'") | .assets[] | select ( .name | endswith ("exe") ) | .browser_download_url')
	export nupkg_name=$(echo ${horizon_json} | jq -r '.[] | select(.tag_name=="'${latest_version}'") | .assets[] | select ( .name | endswith ("nupkg") ) | .name ')
	echo "storage_json: $storage_json"
	echo "latest_version: $latest_version"
	echo "current_version: $current_version"
}


check(){

	echo "Checking for version update..."
	echo "Installed version: $current_version"
	echo "Latest version: $latest_version"
	if [[ ${current_version} == ${latest_version} ]]; then
		echo "Latest already installed, nothing to do!"
		launch
	else
		echo "Updating and launching"
		update
		launch
	fi
}

update(){

	echo "Creating required directories..."
	mkdir -p ~/horizon-xi
	echo "Found latest version... $latest_version"
	echo "Downloading... $download_url"
	curl -L --max-redirs 5 --output ~/horizon-xi/installer.exe "${download_url}"
	cd ~/horizon-xi
	echo "Expanding installers..."
	7z -y x installer.exe
	echo "Expanding ${nupkg_name}..."
	7z -y x ${nupkg_name}
	if [[ ${latest_version} == "v1.0.1" ]]; then
		echo "Add a non-steam game now to steam, then re-run update-horizon.sh"
		echo "TARGET: \"/home/deck/horizon-xi/lib/net45/HorizonXI-Launcher.exe\""
		echo "START IN: \"/home/deck/horizon-xi/lib/net45/\""
		if [[ $(ps -ef | grep steam | wc -l) -le 12 ]]; then
			echo "Steam is not running, manually start steam and add the game as per the instructions above"
			exit 2
		else
			# Install ProtonQT
			proton_json=$(curl https://api.github.com/repos/DavidoTek/ProtonUp-Qt/releases | jq '.')
			latest_p_version=$(echo ${proton_json} | jq -r '.[].tag_name' | head -n1)
			proton_qt_release_url=$(echo ${proton_json} | jq -r '.[] | select(.tag_name=="'${latest_p_version}'") | .assets | .[].browser_download_url' | grep -v zsync)
	                curl -L --max-redirs 5 --output ~/horizon-xi/proton_qt.AppImage "${proton_qt_release_url}"
			chmod +x ~/horizon-xi/proton_qt.AppImage
			(~/horizon-xi/proton_qt.AppImage &>/dev/null) &
			# Install GE-Proton
			echo "Launching ProtonQT..."
			read -p "Install GE-Proton via ProtonQT, after adding proton, hit enter to continue" </dev/tty
			# If someone can decipher this: https://developer.valvesoftware.com/wiki/Add_Non-Steam_Game
			# maybe we can automate the game shortcut installation. until then, a manual effort:
			steam steam://AddNonSteamGame
			echo "Install by browsing to /home/deck/horixon-xi/lib/net45 & select file type All files. Choose HorizonXI-Launcher.exe"
			echo "Right click the new entry, hit Properties > Compatibility"
			echo "Change to the new version of Proton GE you just installed"
			# Low disk space version
			if [[ "${sd_link}" == "true" ]]; then
				read -p "Not enough disk space found on the main /home drive, install to SD Card? (Enter to continue, Ctrl + c to abort" </dev/tty
				if [[ ${card_free_space} -le 60 ]]; then
					echo "There's not enough space on the memory card either. aborting installation"
					exit 2
				fi
				if [[ ${home_free_space} -le ${compat_size} ]]; then
					read -p "Theres not enough space to make a backup, continue without backup? (Enter to continue, Ctrl + c to abort)" </dev/tty
					mkdir -p "/run/media/mmcblk0p1/steamapps/compatdata"
					cp -r /home/deck/.local/share/Steam/steamapps/compatdata/* /run/media/mmcblk0p1/steamapps/compatdata/
					cd /home/deck/.local/share/Steam/steamapps
					ln -s /run/media/mmcblk0p1/steamapps/compatdata
				else
					mkdir -p "/run/media/mmcblk0p1/steamapps/compatdata"
					cp -r /home/deck/.local/share/Steam/steamapps/compatdata/* /run/media/mmcblk0p1/steamapps/compatdata/
					mv /home/deck/.local/share/Steam/steamapps/compatdata /home/deck/.local/share/Steam/steamapps/compatdata_backup
					cd /home/deck/.local/share/Steam/steamapps
					ln -s /run/media/mmcblk0p1/steamapps/compatdata
				fi
			fi
			echo "You should pick C:\\Program Files when prompted for an install path."
			echo "You should not pick anything else. You can move compatdata to an SD card later if needed."
			echo "After the game launches, complete the download before running update-horizon.sh again"
			echo "If the launcher is stuck 'verifying game files', or it opens and minimizes/exits immediately, try downloading in game mode"
		fi
	else
		# Latest version is not v1.0.1
		echo "Continue..."
	fi
	echo "Done!"

}

launch(){

	steam_id=$(grep -sir "Horizon XI" /home/deck/.local/share/Steam/userdata/ | grep screenshots | awk '{print $2}' | sed 's/"//g')
	if [[ $(ps -ef | grep steam | wc -l) -le 12 ]]; then
		echo "Steam is not running. Start steam and try again"
		exit 2
	else
        	steam steam://rungameid/${steam_id}
	fi
}

init
check

