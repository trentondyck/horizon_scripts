#!/bin/bash
set -e

uninstall_init(){

	read -p "Starting uninstall process... continue? (ctrl +c to abort, enter to continue)" somevar

	if $(passwd --status deck >/dev/null); then
	  echo "Password is set, continuing...";
	else
	  echo "Likely no password set or wrong password entered, attempting to create a new one (Keys pressed wont show up in konsole (security) but they are registered..." && passwd
	fi
	sudo echo || (echo "Wrong sudo password entered, either you didn't set it or you don't know what it is. Try 'passwd' in konsole and follow the prompts" && exit 2)

	if [[ -d /run/media/mmcblk0p1/steamapps/compatdata/ ]]; then
		echo "Found a SD card, lets check if we can find an install there"
		if [[ $(sudo find /run/media/mmcblk0p1/steamapps/compatdata/ -name config.json -type f | grep HorizonXI) ]]; then
			echo "Media based install"
			export config_json=$(sudo find /run/media/mmcblk0p1/steamapps/compatdata/ -name config.json -type f | grep HorizonXI)
		else
			echo "Couldn't find config json in the SD card"
	                export config_json=$(sudo find /home/deck/.local/share/Steam/steamapps/compatdata/ -name config.json -type f | grep HorizonXI)
		fi

	else
		echo "No SD installation found"
		if [[ $(sudo find /home/deck/.local/share/Steam/steamapps/compatdata/ -name config.json -type f | grep HorizonXI) ]]; then
			echo "Deck based install"
			export config_json=$(sudo find /home/deck/.local/share/Steam/steamapps/compatdata/ -name config.json -type f | grep HorizonXI)
		else
			echo "No horizon XI install found, exiting..."
			exit 2
		fi
	fi

		echo "config_json: $config_json"
	        steam_id_grep=$(grep -sir "Horizon XI" ${steam_dir}/userdata/ | grep -v backup | grep screenshots | awk '{print $2}' | sed 's/"//g')
		echo "steam_id_grep: $steam_id_grep"

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
		steam steam://uninstall/${app_id} || send_discord_failure
		rm -Rf ${horizon_directory}
	done

}

send_discord_notification() {


        log_out=$(curl -k -s --data-binary @log.out https://paste.rs/)
        log_lines=$(cat log.out | wc -l)

        # Send JSON payload with curl
        # echo "curl -X POST -H \"Content-Type: application/json\" -d \"{\"content\": \"$output\"}\" \"${webhook_url}\""
        curl -s -X POST -H "Content-Type: application/json" -d "{\"content\": \"#################################################\n Uninstall.sh ${discord_name} - ${log_out} - total_log_lines: ${log_lines}\n#################################################\n\"}" "${webhook_url}"

}

send_discord_success(){
	export webhook_url="https://discord.com/api/webhooks/1173033339834351737/dcInAlstUBdRZeRjZmYakF_rjMA1ZxLdnDtLYNVKvTOfz9iBMWlBhOkEU8zelfuQTkH_"
	send_discord_notification
}

send_discord_failure(){
	export webhook_url="https://discord.com/api/webhooks/1173033667115892849/Zkzmj6P2KXn5b4oJjuN5cWi1qM5vLCgKFrA_sUrTcNFvymWptpgtodmQdq1abnJcWSm8"
	send_discord_notification
}

# Error handling function
error_exit() {
	echo ""
	echo " ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR "
	echo ""
	send_discord_failure
	exit 1
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

uninstall_init
uninstall

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

