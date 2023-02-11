#!/bin/bash
set -e

init(){

	export app_name="Horizon XI"
	export raw_github_url="https://raw.githubusercontent.com/trentondyck/horizon_scripts/main"
	export sd_link="false"
	export horizon_dir="/home/deck/horizon-xi"
	export steam_dir="/home/deck/.local/share/Steam"
	if [[ $(df -h | grep " /home$" | awk '{print $4}' | sed 's/G//g') -le 60 ]]; then
		export compat_size=$((cd ${steam_dir}/steamapps && du --max-depth 1 -h) | grep compatdata | awk '{print $1}' | sed 's/G//g')
		export home_free_space=$(df -h | grep " /home$" | awk '{print $4}' | sed 's/G//g')
		export card_free_space=$(df -h | grep "/run/media" | awk '{print $4}' | sed 's/G//g')
		export sd_link="true"
	fi
	export config_json=$(sudo find ${steam_dir}/steamapps/compatdata/ -name config.json -type f | grep HorizonXI)
	if [[ $(echo $config_json | sed 's/ /\n/g' | wc -l) -gt 1 ]]; then
		echo "too many installations found. try uninstalling one of them"
		echo $config_json | sed 's/ /\n/g'
		exit 2
	fi
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

add_non_steam_game(){


	# Source - https://github.com/sonic2kk/steamtinkerlaunch/issues/729
	# 1 Download the latest release
	if [[ $( which ${horizon_dir}/stl/sonic2kk-steamtinkerlaunch-e7c5ada/steamtinkerlaunch ) ]]; then
	        echo "Steam tinker launch already installed, continuing..."
	else
	        stl_json=$(curl https://api.github.com/repos/sonic2kk/steamtinkerlaunch/releases)
	        latest_stl_version=$(echo ${stl_json} | jq -r '.[].tag_name' | head -n1)
	        stl_zip_url=$(echo ${stl_json} | jq -r '.[] | select(.tag_name=="'${latest_stl_version}'") | .zipball_url')
	        echo "Downloading... ${stl_zip_url}"
		curl -L --max-redirs 5 --output ${horizon_dir}/stl.zip "${stl_zip_url}"
		unzip ${horizon_dir}/stl.zip -d ${horizon_dir}/stl
	fi

	# 1 Download icon
	curl -L --max-redirs 5 --output ${horizon_dir}/icon.png "${raw_github_url}/icon.png"

	# 2 Add a non-steam game via stl
	# docs - https://github.com/sonic2kk/steamtinkerlaunch/wiki/Add-Non-Steam-Game
	${horizon_dir}/stl/sonic2kk-steamtinkerlaunch-e7c5ada/steamtinkerlaunch addnonsteamgame --appname="${app_name}" --exepath=${horizon_dir}/lib/net45/HorizonXI-Launcher.exe --startdir=${horizon_dir}/lib/net45/ --iconpath=${horizon_dir}/icon.png

	# 3 Download pip
	if [[ $(which /home/deck/.local/bin/pip) ]]; then 
	        echo "pip already installed. Carrying on...";
	else 
	        wget https://bootstrap.pypa.io/get-pip.py
	        python get-pip.py --user
	fi
	# 4 install vdf module
	/home/deck/.local/bin/pip install vdf

	# 6 load the vdf, grab the app_id
	# Source - https://github.com/DavidoTek/ProtonUp-Qt/issues/175
	userdata_int=$(ls ${steam_dir}/userdata/)
	shortcuts_vdf=$(echo ${steam_dir}/userdata/${userdata_int}/config/shortcuts.vdf)

	echo "Installing to $shortcuts_vdf"
	# Documentation - https://github.com/ValvePython/vdf
	# app_id=$(python -c "import vdf; d=vdf.binary_loads(open('${shortcuts_vdf}', 'rb').read()); items = list(d['shortcuts'].values()); print([i for i in items if i['appname'] in ['${app_name}']][0]['appid']+2**32);")

app_id=$(
python << END

import vdf
d=vdf.binary_loads(open('${shortcuts_vdf}', 'rb').read());
items = list(d['shortcuts'].values());
data = items

def get_appid(appname):
    for item in data:
        if item.get("AppName") == appname or item.get("appname") == appname:
            return item.get("appid")

appname = "Horizon XI"
appid = get_appid(appname)

#if appid:
#    print(f"The appid for the app named {appname} is: {appid}")
#else:
#    print(f"No app found with name {appname}")

print(appid+2**32)

END
)

	echo "app_id: $app_id"

	# Download assets and place them in steam grid
	grid_dir=$(echo ${steam_dir}/userdata/${userdata_int}/config/grid)
	mkdir -p ${grid_dir}
	curl -L --max-redirs 5 --output "${grid_dir}/${app_id}_hero.png" "${raw_github_url}/appid_hero.png"
	curl -L --max-redirs 5 --output "${grid_dir}/${app_id}_logo.png" "${raw_github_url}/appid_logo.png"
	curl -L --max-redirs 5 --output "${grid_dir}/${app_id}.png" "${raw_github_url}/appid.png"
	curl -L --max-redirs 5 --output "${grid_dir}/${app_id}p.png" "${raw_github_url}/appidp.png"

	config_vdf=${steam_dir}/config/config.vdf
	cp -f ${config_vdf} ${horizon_dir}/bak.config_vdf
	# Documentation - https://github.com/ValvePython/vdf
	python -c "import vdf; d=vdf.load(open('${config_vdf}')); ctm = d['InstallConfigStore']['Software']['Valve']['Steam']['CompatToolMapping']; ctm['${app_id}']={ 'name': 'GE-Proton7-42', 'config': '', 'priority': '250' }; vdf.dump(d, open('${horizon_dir}/config.vdf','w'), pretty=True);"


        cp -f ${horizon_dir}/config.vdf $config_vdf
	# Restart steam
	killall steam
	sleep 10
	(steam &>/dev/null) &
	echo "Successfully added nonsteam game"

}

update(){

	echo "Creating required directories..."
	mkdir -p ${horizon_dir}
	echo "Found latest version... $latest_version"
	echo "Downloading... $download_url"
	curl -L --max-redirs 5 --output ${horizon_dir}/installer.exe "${download_url}"
	cd ${horizon_dir}
	echo "Expanding installers..."
	7z -y x installer.exe
	echo "Expanding ${nupkg_name}..."
	7z -y x ${nupkg_name}
	if [[ ${latest_version} == "v1.0.1" ]]; then
		if [[ $(ps -ef | grep steam | wc -l) -le 12 ]]; then
			echo "Steam is not running, manually start steam and add the game as per the instructions above"
			exit 2
		else
			# Install ProtonQT
			proton_json=$(curl https://api.github.com/repos/DavidoTek/ProtonUp-Qt/releases | jq '.')
			latest_p_version=$(echo ${proton_json} | jq -r '.[].tag_name' | head -n1)
			proton_qt_release_url=$(echo ${proton_json} | jq -r '.[] | select(.tag_name=="'${latest_p_version}'") | .assets | .[].browser_download_url' | grep -v zsync)
	                curl -L --max-redirs 5 --output ${horizon_dir}/proton_qt.AppImage "${proton_qt_release_url}"
			chmod +x ${horizon_dir}/proton_qt.AppImage
			(${horizon_dir}/proton_qt.AppImage &>/dev/null) &
			# Install GE-Proton
			echo "Launching ProtonQT..."
			read -p "Install GE-Proton via ProtonQT, after adding proton, hit enter to continue" </dev/tty
			add_non_steam_game
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
					cp -r ${steam_dir}/steamapps/compatdata/* /run/media/mmcblk0p1/steamapps/compatdata/
					cd ${steam_dir}/steamapps
					ln -s /run/media/mmcblk0p1/steamapps/compatdata
				else
					mkdir -p "/run/media/mmcblk0p1/steamapps/compatdata"
					cp -r ${steam_dir}/steamapps/compatdata/* /run/media/mmcblk0p1/steamapps/compatdata/
					mv ${steam_dir}/steamapps/compatdata ${steam_dir}/steamapps/compatdata_backup
					cd ${steam_dir}/steamapps
					ln -s /run/media/mmcblk0p1/steamapps/compatdata
				fi
			fi

			# Unsure about spacing, anyways hoping this allows the user to not have to set the install directory

			# This doesnt work for now. the file doesnt exist before launching horizon.
#python << END
#import json
#
#f = open('${storage_json}')
#data = json.load(f)
#data['paths']['installPath']['path']='C:\\Program Files\\HorizonXI\\Game'
#with open("${storage_json}", "w") as outfile:
#  json.dump(data, outfile, indent=4)
#
#END

			# I'll leave this help text until the above is tested/verified
			echo "You should pick C:\\Program Files when prompted for an install path."
			echo "You should not pick anything else. You can move compatdata to an SD card later if needed."

			# Necessary help text
			echo "Sometimes you may have to launch the game multiple times initially to get it working"
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

	steam_id=$(grep -sir "Horizon XI" ${steam_dir}/userdata/ | grep -v backup | grep screenshots | awk '{print $2}' | sed 's/"//g')
	if [[ $(ps -ef | grep steam | wc -l) -le 12 ]]; then
		echo "Steam is not running. Start steam and try again"
		exit 2
	else
        	steam steam://rungameid/${steam_id}
	fi
}

init
check

