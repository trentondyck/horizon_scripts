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

	        steam_id_grep=$(grep -sir "Horizon XI" ${steam_dir}/userdata/ | grep -v backup | grep screenshots | awk '{print $2}' | sed 's/"//g')

		# Calculating the steam ID is faster, less error prone (also incorrect)
		# The CRC32 algorithm is only for Big Picture, and possibly even old Big Picture. Regular Steam apps no longer use the CRC algorithm. See here (https://github.com/boppreh/steamgrid/blob/master/games.go#L115-L137) and this comment by DavidoTek that verifies that the CRC calculation is not correct anymore (DavidoTek/ProtonUp-Qt#175 (comment)).
		# That said, the legacy steam id works on my deck. leaving this blurb here for investigation later.

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
                                        echo "All methods to find a steam ID failed. Please seek further guidance or debug manually"
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
                                export steam_id=${steam_id_grep}
                        fi
                fi

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

uninstall(){

	for cj in ${config_json}; do
		export horizon_directory=$(echo $cj | sed 's/pfx.*$//g')
		rm -Rf ~/horizon-xi
		if [[ $(ps -ef | grep steam | wc -l) -le 12 ]]; then
			restart_steam
        		steam steam://rungameid/${steam_id}
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

