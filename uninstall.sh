#!/bin/bash

init(){

	if [[ -d /run/media/mmcblk0p1/steamapps/compatdata/ ]]; then
		if [[ $(sudo find /run/media/mmcblk0p1/steamapps/compatdata/ -name config.json -type f | grep HorizonXI) ]]; then
			echo "Media based install"
			export config_json=$(sudo find /run/media/mmcblk0p1/steamapps/compatdata/ -name config.json -type f | grep HorizonXI)
		fi
	else
		if [[ $(sudo find /home/deck/.local/share/Steam/steamapps/compatdata/ -name config.json -type f | grep HorizonXI) ]]; then
			echo "Deck based install"
			export config_json=$(sudo find /home/deck/.local/share/Steam/steamapps/compatdata/ -name config.json -type f | grep HorizonXI)
		else
			echo "No horizon XI install found, exiting..."
			exit 2
		fi
	fi
}

uninstall(){

	for cj in ${config_json}; do
		export horizon_directory=$(echo $cj | sed 's/pfx.*$//g')
		export steam_id=$(grep -sir "Horizon XI" /home/deck/.local/share/Steam/userdata/ | grep screenshots | awk '{print $2}' | sed 's/"//g')
		rm -Rf ~/horizon-xi
		if [[ $(ps -ef | grep steam | wc -l) -le 12 ]]; then
			echo "Steam is not running. Start steam and try again"
			exit 2
		else
        		steam steam://rungameid/${steam_id}
		fi
		# This may be dangerous, we may want to get this from python as with the installer script
		app_id=$(ps -ef | grep horizon | grep AppId | awk '{print $10}' | sed 's/AppId=//g')
		killall horizon
		steam steam://uninstall/${app_id}
		rm -Rf ${horizon_directory}
	done

}

init
uninstall

