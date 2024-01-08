#!/bin/bash
set -e

init(){

	if $(passwd --status deck >/dev/null); then
	  echo "Password is set, continuing...";
	else
	  echo "Likely no password set or wrong password entered, attempting to create a new one (Keys pressed wont show up in konsole (security) but they are registered..." && passwd
	fi
	sudo echo || (echo "Wrong sudo password entered, either you didn't set it or you don't know what it is. Try 'passwd' in konsole and follow the prompts" && exit 2)

	# Killing instances between runs because its required to reload storage json
	(ps -ef | grep horizon | grep ":\\\home\\\deck\\\horizon-xi\\\lib\\\net45\\\HorizonXI-Launcher.exe$" | awk '{print $2}' | xargs -i kill {}) || echo "No Instances found running, continuing..."

	export webhook_url="https://discord.com/api/webhooks/1172713482261631108/cH1dXLPV8jX1d16irijQVWjGbyHnXV4we4pxiXsx-hzBFER1pCG4jGgd3OI8Qh9MTae_" # Replace with your Slack webhook URL
	export initial_install="false"
	export app_name="Horizon XI"
	export raw_github_url="https://raw.githubusercontent.com/trentondyck/horizon_scripts/main"
	export sd_link="false"
	export horizon_dir="/home/deck/horizon-xi"
	export steam_dir="/home/deck/.local/share/Steam"
	if [[ $(df -k | grep " /home$" | awk '{print $4}') -le 66124876 ]]; then
		export compat_size=$((cd ${steam_dir}/steamapps && du --max-depth 1 -h) | grep compatdata | awk '{print $1}' | sed 's/G//g')
		export home_free_space=$(df -h | grep " /home$" | awk '{print $4}' | sed 's/G//g')
		export card_free_space=$(df -h | grep "/run/media" | awk '{print $4}' | sed 's/G//g')
		export sd_link="true"
		if [[ -d "/run/media/mmcblk0p1/" ]]; then
			echo "SD card found and formatted, continuing..."
		else
			echo "SD Card not formatted. Do that manually and try running the script again..."
			echo "https://www.tomsguide.com/how-to/how-to-format-an-sd-card-on-the-steam-deck"
			echo "https://www.youtube.com/watch?v=mdcCVqJUsrk"
                        exit 2
    		fi
	fi
	mkdir -p "${steam_dir}/steamapps/compatdata/"
	echo "Searching for the config.json file, if you have a ton on the disk this may take a while..."
	export config_json=$(sudo find ${steam_dir}/steamapps/compatdata/ -name config.json -type f | grep HorizonXI)

	if [[ $(find "/home/deck/.local/share/Steam/steamapps/compatdata/" -name "HorizonXI" -type d | wc -l) -gt 1 ]]; then
		echo "Found too many installation folders, run the uninstall.sh script to get to a clean slate or"
		echo "manually clean up the unused folders:"
		echo "#################################################################################"
		find "/home/deck/.local/share/Steam/steamapps/compatdata/" -name "HorizonXI" -type d
		echo "#################################################################################"
		send_discord_failure
		exit 2
	fi

	# Check for too many config.json files
	if [[ $(echo $config_json | sed 's/ /\n/g' | wc -l) -gt 1 ]]; then
		echo "too many installations found. try uninstalling one of them, or uninstall all of them with ./uninstall.sh then reinstall with this script."
		echo $config_json | sed 's/ /\n/g'
		send_discord_failure
		exit 2
	fi
	
	export config_prefix=$(echo $config_json | sed 's/\/config.json//g')
	export storage_json=$(echo ${config_prefix}/storage.json)
	export base_downloaded_boolean=$(cat $storage_json | jq '.GAME_UPDATER.baseGame.downloaded')
	export base_extracted_boolean=$(cat $storage_json | jq '.GAME_UPDATER.baseGame.extracted')
	# Not actually booleans, this must have changed.
	export updater_downloaded_boolean=$(cat $storage_json | jq '.GAME_UPDATER.updater.downloaded')
	export updater_extracted_boolean=$(cat $storage_json | jq '.GAME_UPDATER.updater.extracted')
	export horizon_json=$(curl -s "https://api.github.com/repos/HorizonFFXI/HorizonXI-Launcher-Binaries/releases" | jq '.')
	if [[ ${base_downloaded_boolean} == "true" && ${base_extracted_boolean} == "true" ]]; then
		export latest_version=$(echo ${horizon_json} | jq -r '.[].name' | head -n1)
		# Since everythings done downloading we can clean up
		echo "Searching home directory for horizon zip, this may take a while..."
		sudo find /home -name "HorizonXI.zip" -type f | sed 's/ /\\ /g' | xargs -i rm {}
		export current_version=$(cat $config_json | jq -r '.__internal__.migrations.version' | sed 's/^/v/g')

		# I think we can assume this is the second install at least here
		# GamePad settings
                cat <<< $(jq '.registrySettings.padmode000.value = [1,1,0,0,1,1]' "${config_json}") > "${config_json}"
                cat <<< $(jq '.registrySettings.padsin000.value = [8,9,13,12,10,0,1,3,2,15,-1,-1,14,-33,-33,32,32,-36,-36,35,35,6,7,5,4,11,-1]' "${config_json}") > "${config_json}"

	elif [[ (-f ${horizon_dir}/current_version) && (! -f ${storage_json}) ]]; then 
		current_version=$(cat ${horizon_dir}/current_version)
                export latest_version=$(echo ${horizon_json} | jq -r '.[].name' | head -n1)
                # Since everythings done downloading we can clean up
                echo "Base and extracted not true, Searching home directory for horizon zip, this may take a while..."
                sudo find /home -name "HorizonXI.zip" -type f | sed 's/ /\\ /g' | xargs -i rm {}
	elif [[ -f $storage_json && "$install_path" == '""' && "$download_path" == '""' && "$updater_downloaded_boolean" == "0" && "$updater_extracted_boolean" == "0" ]]; then
                echo "Found an issue with storage json config, Did you install Horizon to C:\\Program Files ?"
                cat $storage_json
                echo "If not, modify the $storage_json install_path and download_path to the correct values."
                read -p "If you did install to C:\\Program Files, we can fix this bug, just hit enter (Ctrl + c to abort)"
                # Kill currently running horizon process if exists
                ps -ef | grep horizon | grep ":\\\home\\\deck\\\horizon-xi\\\lib\\\net45\\\HorizonXI-Launcher.exe$" | awk '{print $2}' | xargs -i kill {}
                cat <<< $(jq '.paths.installPath.path = "C:\\Program Files\\HorizonXI\\Game"' "${storage_json}") > "${storage_json}"
                cat <<< $(jq '.paths.downloadPath.path = "C:\\Program Files\\HorizonXI\\Downloads"' "${storage_json}") > "${storage_json}"
                cat <<< $(jq '.GAME_UPDATER.updater.downloaded = 1' "${storage_json}") > "${storage_json}"
                cat <<< $(jq '.GAME_UPDATER.updater.extracted = 1' "${storage_json}") > "${storage_json}"
#	else
#		# Let's hard code latest version to v1.0.1, since the installer isn't complete we need to download & complete the install on v1.0.1 before updating
		# See Note: https://github.com/hilts-vaughan/hilts-vaughan.github.io/blob/master/_posts/2022-12-16-installing-horizon-xi-linux.md#install-horizonxi---steam-play-steam-deck--other-systems
		echo "Seems like theres no storage json, hard coding to v1.0.1"
		export latest_version="v1.0.1"
	fi
	export download_url=$(echo ${horizon_json} | jq -r '.[] | select(.tag_name=="'${latest_version}'") | .assets[] | select ( .name | endswith ("exe") ) | .browser_download_url')
	export nupkg_name=$(echo ${horizon_json} | jq -r '.[] | select(.tag_name=="'${latest_version}'") | .assets[] | select ( .name | endswith ("nupkg") ) | .name ')
	echo "config_json: $config_json"
	echo "storage_json: $storage_json"
	cat "${storage_json}" || echo "First time install so storage_json does not exist"
	echo "latest_version: $latest_version"
	echo "current_version: $current_version"
}


check(){

	echo "Checking bootloader..."
	# Bad
	# 094254091e67e1153ec1be7215f86772  horizon-loader.exe
	# Good, i.e.
	# 4695c8046ad15471cf51b540c094c588

	export steam_dir="/home/deck/.local/share/Steam"
	export loader_exe=$(sudo find ${steam_dir}/steamapps/compatdata/ -name horizon-loader.exe -type f)
	export loader_prefix=$(echo $loader_exe | sed 's/\/horizon-loader.exe//g')
	echo "loader_prefix: $loader_prefix"
	md=$(md5sum "${loader_prefix}/horizon-loader.exe" | awk '{print $1}')

        if [[ $md == "094254091e67e1153ec1be7215f86772" ]]; then
		echo Bad bootloader found, re-downloading
	        curl -s -L --max-redirs 5 --output "${loader_prefix}/horizon-loader.exe" "https://raw.githubusercontent.com/trentondyck/horizon_scripts/main/horizon-loader.exe"
	else
		echo "Bootloader is fine (probably?), continuing..."
		echo "MD5 sum found - $md"
	fi

	echo "Checking for version update..."
	echo "Installed version: $current_version"
	echo "Latest version: $latest_version"
	if [[ ${current_version} == ${latest_version} ]]; then
		echo "Latest already installed, nothing to do!"
		launch
	else
		echo "Updating version: ${current_version} to ${latest_version}"
		read -p "Whats your discord name (useful in case something goes wrong for debugging, required. Ctrl + C to abort update process)?" discord_name
		if [[ "discord_name" == "" ]]; then
			exit 2
		fi
		update
		echo "Launching"
		launch
	fi
}

add_non_steam_game(){


	# Source - https://github.com/sonic2kk/steamtinkerlaunch/issues/729
	# 1 Download the latest release
	stl_suffix=$(ls -l ${horizon_dir}/stl/ 2>/dev/null | grep sonic | awk '{print $9}' 2>/dev/null)
	stl_dir="${horizon_dir}/stl/${stl_suffix}"

	if [[ $( which ${stl_dir}/steamtinkerlaunch 2>/dev/null ) ]]; then
	        echo "Steam tinker launch already installed, continuing..."
	else
	        stl_json=$(curl -s "https://api.github.com/repos/sonic2kk/steamtinkerlaunch/releases")
	        latest_stl_version=$(echo ${stl_json} | jq -r '.[].tag_name' | head -n1)
	        stl_zip_url=$(echo ${stl_json} | jq -r '.[] | select(.tag_name=="'${latest_stl_version}'") | .zipball_url')
	        echo "Downloading... ${stl_zip_url}"
		curl -s -L --max-redirs 5 --output "${horizon_dir}/stl.zip" "${stl_zip_url}"
		unzip ${horizon_dir}/stl.zip -d ${horizon_dir}/stl
	        export stl_suffix=$(ls -l ${horizon_dir}/stl/ | grep sonic | awk '{print $9}')
	        export stl_dir="${horizon_dir}/stl/${stl_suffix}"
	fi

	# 1 Download icon
	curl -s -L --max-redirs 5 --output "${horizon_dir}/icon.png" "${raw_github_url}/icon.png"

	# 2 Add a non-steam game via stl
	# docs - https://github.com/sonic2kk/steamtinkerlaunch/wiki/Add-Non-Steam-Game
	${stl_dir}/steamtinkerlaunch addnonsteamgame --appname="${app_name}" --exepath=${horizon_dir}/lib/net45/HorizonXI-Launcher.exe --startdir=${horizon_dir}/lib/net45/ --iconpath=${horizon_dir}/icon.png

	# 4 install vdf module
	# https://pythonspeed.com/articles/externally-managed-environment-pep-668/
	python -m venv ./myvenv
        . ./myvenv/bin/activate
	pip install --upgrade pip
        pip install vdf

	# 6 load the vdf, grab the app_id
	# Source - https://github.com/DavidoTek/ProtonUp-Qt/issues/175

	# These two are broken for multi-user installs
	# userdata_int=$(ls ${steam_dir}/userdata/)
	# shortcuts_vdf=$(echo ${steam_dir}/userdata/${userdata_int}/config/shortcuts.vdf)

	# Multi-user support for shortcuts vdf:
	shortcuts_vdf=$(grep -sir "Horizon XI" /home/deck/.local/share/Steam/userdata/ 2>&1 | grep "shortcuts.vdf" | awk '{print $2}' | sed 's/://g')
	echo "Shortcuts_vdf: $shortcuts_vdf"

	for sv in ${shortcuts_vdf}; do

		userdata_int=$(echo $sv | sed 's/.*userdata\///g' | sed 's/\/config.*$//g')
		echo "Installing to $sv for $userdata_int"

		# Documentation - https://github.com/ValvePython/vdf
		# app_id=$(python -c "import vdf; d=vdf.binary_loads(open('${shortcuts_vdf}', 'rb').read()); items = list(d['shortcuts'].values()); print([i for i in items if i['appname'] in ['${app_name}']][0]['appid']+2**32);")

app_id=$(
python << END

import vdf
d=vdf.binary_loads(open('${sv}', 'rb').read());
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
		curl -s -L --max-redirs 5 --output "${grid_dir}/${app_id}_hero.png" "${raw_github_url}/appid_hero.png"
		curl -s -L --max-redirs 5 --output "${grid_dir}/${app_id}_logo.png" "${raw_github_url}/appid_logo.png"
		curl -s -L --max-redirs 5 --output "${grid_dir}/${app_id}.png" "${raw_github_url}/appid.png"
		curl -s -L --max-redirs 5 --output "${grid_dir}/${app_id}p.png" "${raw_github_url}/appidp.png"

	done
		
	# Before modifying config.vdf Steam needs to be closed. See https://github.com/sonic2kk/steamtinkerlaunch/pull/908#issuecomment-1722569450
        killall steam
	sleep 10
	if [[ $(ps -ef | grep steam | wc -l) -le 12 ]]; then
		echo "Steam isn't running, continuing..."
	else
		echo "Steam was still running after killall command"
	fi
	config_vdf=${steam_dir}/config/config.vdf
	echo "Config VDF before adding $app_id"
	cat $config_vdf
	cp -f ${config_vdf} ${horizon_dir}/bak.config_vdf
	# Documentation - https://github.com/ValvePython/vdf
	echo "Installing Proton layer to ${config_vdf}"

python << END

import vdf
d=vdf.load(open('${config_vdf}'))

if not 'CompatToolMapping' in d['InstallConfigStore']['Software']['Valve']['Steam']:
  d['InstallConfigStore']['Software']['Valve']['Steam']['CompatToolMapping']={}

ctm = d['InstallConfigStore']['Software']['Valve']['Steam']['CompatToolMapping']
ctm['${app_id}']={ 'name': 'GE-Proton8-25', 'config': '', 'priority': '250' }
vdf.dump(d, open('${horizon_dir}/config.vdf','w'), pretty=True)

END

	cp -f ${horizon_dir}/config.vdf ${config_vdf}
	echo "Should have copied ${horizon_dir}/config.vdf to $config_vdf"
	echo "Config VDF after adding $app_id"
	cat $config_vdf | grep "${app_id}" -A6

	restart_steam
	echo "Successfully added nonsteam game"

}

restart_steam(){

	if [[ $(ps -ef | grep steam | wc -l) -le 12 ]]; then
		echo "Steam isn't running, continuing..."
	else
        	killall steam
        	sleep 10
	fi
        # Restart steam
        (steam &>/dev/null) &

}

update(){

	echo "Creating required directories... ${horizon_dir} ..."
	mkdir -p ${horizon_dir}
	sudo chown -R deck: ${horizon_dir}
	echo "Found latest version... $latest_version"
	echo "Downloading... $download_url"
	curl -s -L --max-redirs 5 --output "${horizon_dir}/installer.exe" "${download_url}"
	cd ${horizon_dir}
	echo "Expanding installers..."
	7z -y x installer.exe
	echo "Expanding ${nupkg_name}..."
	7z -y x ${nupkg_name}
	echo "current_version=${latest_version}" > ${horizon_dir}/current_version
	if [[ ${latest_version} == "v1.0.1" ]]; then
			restart_steam
			# Install GE-Proton8-25, known to work with Horizon. Later versions can be found via `/home/deck/.local/bin/protonup --releases`
			# https://pythonspeed.com/articles/externally-managed-environment-pep-668/
	                python -m venv ./myvenv
                        . ./myvenv/bin/activate
			pip install --upgrade pip
			pip install protonup
			echo "Downloading GE-Proton8-25, this may take a while..."
			protonup -t GE-Proton8-25 -y
			restart_steam
			add_non_steam_game
			# Low disk space version
			if [[ "${sd_link}" == "true" ]]; then
				read -p "Not enough disk space found on the main /home drive, install to SD Card? (Enter to continue, Ctrl + c to abort" </dev/tty
				if [[ ${card_free_space} -le 60 ]]; then
					echo "There's not enough space on the memory card either. aborting installation"
					exit 2
				fi
				my_link="/home/deck/.local/share/Steam/steamapps/compatdata"
				if [[ ${home_free_space} -le ${compat_size} ]]; then
					read -p "Theres not enough space to make a backup, continue without backup? (Enter to continue, Ctrl + c to abort)" </dev/tty
					if [[ -L ${my_link} ]] && [[ -e ${my_link} ]]; then
						echo "Found simlink, nothing further to do here"
					else
						if [[ ${compat_size} -ge ${card_free_space} ]]; then
							echo "Theres not enough free space to make a backup of compatdata on the memory card. aborting installation"
							echo "clean up $steam_dir/steamapps/compatdata or the SD card manually"
							exit 2
						else
							mkdir -p "/run/media/mmcblk0p1/steamapps/compatdata"
							if [[ -d ${steam_dir}/steamapps/compatdata ]]; then
								cp -r ${steam_dir}/steamapps/compatdata/* /run/media/mmcblk0p1/steamapps/compatdata/
							else
								mkdir -p ${steam_dir}/steamapps/
							fi
							cd ${steam_dir}/steamapps
							ln -s /run/media/mmcblk0p1/steamapps/compatdata
						fi
					fi
				else
					if [[ -L ${my_link} ]] && [[ -e ${my_link} ]]; then
						echo "Found simlink, nothing further to do here"
					else
						if [[ ${compat_size} -ge ${card_free_space} ]]; then
							echo "Theres not enough free space to make a backup of compatdata on the memory card. aborting installation"
							echo "clean up $steam_dir/steamapps/compatdata or the SD card manually"
							exit 2
						else
							mkdir -p "/run/media/mmcblk0p1/steamapps/compatdata"
							if [[ -d ${steam_dir}/steamapps/compatdata ]]; then
                                                	        echo "Taking backup..."
								cp -r ${steam_dir}/steamapps/compatdata/* /run/media/mmcblk0p1/steamapps/compatdata/
								mv ${steam_dir}/steamapps/compatdata ${steam_dir}/steamapps/compatdata_backup
                                                	        ls ${steam_dir}/steamapps
							else
                                                		echo "creating steamapps"
								mkdir -p ${steam_dir}/steamapps/
                                                	        ls ${steam_dir}/steamapps
							fi
							cd ${steam_dir}/steamapps
                                                	ls ${steam_dir}/steamapps
   							ln -s /run/media/mmcblk0p1/steamapps/compatdata
						fi
					fi
				fi
			fi

			# I'll leave this help text until the above is tested/verified
			echo ""
			echo "You should pick C:\\Program Files when prompted for an install path."
			echo "You should not pick anything else. You can move compatdata to an SD card later if needed."

			# Necessary help text
			echo ""
			echo "########################################################################################################"
			echo "After the game launches, complete the initial download (within the launcher), exit the launcher, and run"
		        echo "./install-or-update-horizon.sh"
			echo "DOUBLE CHECK your Steam library -> Manage game -> compatibility -> Check box GE-Proton8-25"
			echo "########################################################################################################"
			echo ""
			echo "to update the launcher to the latest version."
			echo "If the launcher is stuck 'verifying game files', or it opens and minimizes/exits immediately, try downloading in game mode"
			echo ""
	else
		# Latest version is not v1.0.1
		echo "Continue..."
	fi
	echo "Done!"
        send_discord_success

}

launch(){

	if [[ ${initial_install} == "false" ]]; then

		# Leaving the old way here, commented out in case I need to revert for some reason, or make an if/else block.
		# Usually only one id here but mine had two for some reason, and the second one worked to launch the game.
		steam_id_grep=$(grep -sir "Horizon XI" ${steam_dir}/userdata/ 2>/dev/null | grep -v backup | grep screenshots | awk '{print $2}' | sed 's/"//g' | tail -n1)

                # Calculating the steam ID is faster, less error prone (also incorrect)
                # The CRC32 algorithm is only for Big Picture, and possibly even old Big Picture. Regular Steam apps no longer use the CRC algorithm. See here (https://github.com/boppreh/steamgrid/blob/master/games.go#L115-L137) and this comment by DavidoTek that verifies that the CRC calculation is not correct anymore (DavidoTek/ProtonUp-Qt#175 (comment)).
                # That said, the legacy steam id works on my deck. leaving this blurb here for investigation later.

		# Never had an issue with this but. eh. lets see.
		python -m venv ./myvenv
        	. ./myvenv/bin/activate
		pip install crcmod

export steam_ids_python=$(
python << END
import crcmod.predefined

target = r'"/home/deck/horizon-xi/lib/net45/HorizonXI-Launcher.exe"'
label = 'Horizon XI'

crc32_func = crcmod.predefined.mkPredefinedCrcFun('crc-32')
checksum = crc32_func((target + label).encode('utf-8'))

steam_id = checksum | 0x80000000

top_32 = steam_id
bottom_32 = 0x02000000
legacy_steam_id = (top_32 << 32) | bottom_32

print(str(steam_id) + "," + str(legacy_steam_id))
END
)
		new_steam_id=$(echo $steam_ids_python | sed 's/,.*//g')
		legacy_steam_id=$(echo $steam_ids_python | sed 's/.*,//g')

		if [[ ${steam_id_grep} == "" ]]; then
			if [[ ${legacy_steam_id} == "" ]]; then
				if [[ ${new_steam_id} == "" ]]; then
					echo "All methods to find a steam ID failed. Maybe just try running it from steam? Launching from commandline failed."
					send_discord_failure
					exit 2
				else
					export steam_id=${new_steam_id}	
				fi
			else
				export steam_id=${legacy_steam_id}
			fi
		else
			if [[ ${steam_id_grep} == ${legacy_steam_id} ]]; then
				echo "Steam ID from grep matches legacy steam ID from python"
				export steam_id=${steam_id_grep}
			else
				echo "Steam ID from grep is a mismatch from python"
				echo "Grep Steam ID: ${steam_id_grep}"
				echo "Legacy Steam ID: ${legacy_steam_id}"
				echo "Setting steam_id to Grep Steam ID..."
				export steam_id=${steam_id_grep}
			fi
		fi
		if [[ $(ps -ef | grep steam | wc -l) -le 12 ]]; then
			restart_steam
			steam steam://rungameid/${steam_id} 2>/dev/null
			send_discord_success
		else
			steam steam://rungameid/${steam_id} 2>/dev/null
			send_discord_success
		fi
	fi
}

send_discord_notification() {

        log_out=$(curl -k -s --data-binary @log.out https://paste.rs/)
	log_lines=$(cat log.out | wc -l)

	# Send JSON payload with curl
	# echo "curl -X POST -H \"Content-Type: application/json\" -d \"{\"content\": \"$output\"}\" \"${webhook_url}\""
	curl -s -X POST -H "Content-Type: application/json" -d "{\"content\": \"#################################################\n${discord_name} - ${log_out} - total_log_lines: ${log_lines}\n#################################################\n\"}" "${webhook_url}"

}

send_discord_success(){
	export webhook_url="https://discord.com/api/webhooks/1173033339834351737/dcInAlstUBdRZeRjZmYakF_rjMA1ZxLdnDtLYNVKvTOfz9iBMWlBhOkEU8zelfuQTkH_"
	send_discord_notification
}

send_discord_failure(){
	echo "There seems to have been an issue with your installation or launching of Horizon. If your installation is not working,"
	echo "Please copy the entire konsole log, visit"
	echo "https://pastebin.com/"
	echo "and paste it there. Then share the link in the Steam deck discord"
        echo "https://discord.com/channels/933423693848260678/1050099981987618906"
        echo "and tag @trent"
	export webhook_url="https://discord.com/api/webhooks/1173033667115892849/Zkzmj6P2KXn5b4oJjuN5cWi1qM5vLCgKFrA_sUrTcNFvymWptpgtodmQdq1abnJcWSm8"
	send_discord_notification
}

OUTPUT_LOG=log.out
OUTPUT_PIPE=output.pipe

if [ ! -e $OUTPUT_PIPE ]; then
    mkfifo $OUTPUT_PIPE
fi

if [ -e $OUTPUT_LOG ]; then
    rm $OUTPUT_LOG
fi

exec 3>&1 4>&2
tee $OUTPUT_LOG < $OUTPUT_PIPE >&3 &
tpid=$!
exec > $OUTPUT_PIPE 2>&1

init
check

exec 1>&3 3>&- 2>&4 4>&-
wait $tpid
rm $OUTPUT_PIPE

# Error handling function
error_exit() {
	send_discord_failure
	exit 1
}

# Set up error trap
trap 'error_exit' ERR

