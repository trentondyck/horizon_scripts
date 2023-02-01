#!/bin/bash

init(){

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
	else
		# Let's hard code latest version to v1.0.1, since the installer isn't complete we need to download & complete the install on v1.0.1 before updating
		# See Note: https://github.com/hilts-vaughan/hilts-vaughan.github.io/blob/master/_posts/2022-12-16-installing-horizon-xi-linux.md#install-horizonxi---steam-play-steam-deck--other-systems
		export latest_version="v1.0.1"
	fi
	export download_url=$(echo ${horizon_json} | jq -r '.[] | select(.tag_name=="'${latest_version}'") | .assets[] | select ( .name | endswith ("exe") ) | .browser_download_url')
	export nupkg_name=$(echo ${horizon_json} | jq -r '.[] | select(.tag_name=="'${latest_version}'") | .assets[] | select ( .name | endswith ("nupkg") ) | .name ')
	export current_version=$(cat $config_json | jq -r '.__internal__.migrations.version' | sed 's/^/v/g')
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
			steam steam://AddNonSteamGame
		fi
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

