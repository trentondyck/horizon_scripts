#!/bin/bash

uninstall_init(){

	> /tmp/last_error

	read -p "Starting uninstall process... continue? (ctrl +c to abort, enter to continue)" continue_var
	if $(passwd --status deck >/dev/null); then
	  echo "Password is set, continuing...";
	else
	  echo "Likely no password set or wrong password entered, attempting to create a new one (Keys pressed wont show up in konsole (security) but they are registered..." && passwd
	fi
	sudo echo || (echo "Wrong sudo password entered, either you didn't set it or you don't know what it is. Try 'passwd' in konsole and follow the prompts" && exit 2)

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
		check_success

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

send_discord_notification() {

	# Local variables are not needed for continuation runs, and can be excluded from init (variables required to be generated every run)
	# Simply by defining the error_message variable, we'll see it in the output in discord.
	local error_message=$(< /tmp/last_error)

	# Capture environment variables
	local data1=$(printenv | awk '{print}' ORS='\\n')

	# Capture all variables available in the script
	local data2=$(eval "printf '%q\n' $(printf ' "${!%s@}"' _ {a..z} {A..Z})")

	# List of known bash-specific variables (Omit from report)
	local data3="FUNCNAME webhook_url opt i data1 data2 BASH BASH_ALIASES BASH_ARGC BASH_ARGV BASH_ARGV0 BASH_CMDS BASH_COMMAND BASH_LINENO BASHOPTS BASHPID BASH_SOURCE BASH_SUBSHELL BASH_VERSINFO BASH_VERSION COMP_WORDBREAKS DIRSTACK EPOCHREALTIME EPOCHSECONDS EUID GROUPS HISTCMD HOSTNAME HOSTTYPE IFS LINENO MACHTYPE OPTERR OPTIND OSTYPE PIPESTATUS PPID PS4 RANDOM SECONDS SHELLOPTS SRANDOM UID"

	# Convert data to arrays; Couldn't figure out how to make this local
	readarray -t arr1 <<< "$(echo -e "$data1" | sed 's/=.*//' | sort)"
	readarray -t arr2 <<< "$(echo "$data2" | tr ' ' '\n' | sort)"
	readarray -t arr3 <<< "$(echo "$data3" | tr ' ' '\n' | sort)"

	# Find unique variables in arr2 not in arr1
	local unique_to_arr2=$(comm -23 <(printf "%s\n" "${arr2[@]}") <(printf "%s\n" "${arr1[@]}"))

	# Find unique variables in the above result not in arr3
	local final_result=$(comm -23 <(printf "%s\n" "${unique_to_arr2[@]}") <(printf "%s\n" "${arr3[@]}"))

	# Initialize an empty string
	local output=""

	# Loop through the variables
	for var in ${final_result[@]}; do
	    # Append variable and value to the string with "\n" separator
	    output+="${var}=${!var}\\n"
	done

	# Remove the last "\n" from the string
	local output=${output%\\n}

	# Send JSON payload with curl
	# echo "curl -X POST -H \"Content-Type: application/json\" -d \"{\"content\": \"$output\"}\" \"${webhook_url}\""
	curl -s -X POST -H "Content-Type: application/json" -d "{\"content\": \"#################################################\n$output\n#################################################\n\"}" "${webhook_url}"

}

send_discord_success(){
	export webhook_url="https://discord.com/api/webhooks/1173033339834351737/dcInAlstUBdRZeRjZmYakF_rjMA1ZxLdnDtLYNVKvTOfz9iBMWlBhOkEU8zelfuQTkH_"
	send_discord_notification
}

send_discord_failure(){
	export webhook_url="https://discord.com/api/webhooks/1173033667115892849/Zkzmj6P2KXn5b4oJjuN5cWi1qM5vLCgKFrA_sUrTcNFvymWptpgtodmQdq1abnJcWSm8"
	send_discord_notification
}

check_success() {

	if [[ $(cat /tmp/last_error) == "" ]]; then
		echo "Uninstall Success!" > /tmp/last_error
		send_discord_success
	else
		echo "Seems like there was an error in the uninstallation process"
		send_discord_failure
	fi
}

# Array of commands to execute, each on a new line for readability
commands=(
	'uninstall_init'
	'uninstall'
)

# Error handling function
error_exit() {
	send_discord_failure
	local next_task_index=$((current_task + 1))
	echo ""
	echo " ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR "
	echo ""
	echo "An error occurred with command: '${commands[$current_task]}'"
	echo "After fixing the issue, you can continue by pasting the following into your konsole: "
	echo ""
	echo "./install-or-update-horizon.sh -c ${next_task_index}."
	echo ""
	exit 1
}

# Function to execute commands from a certain index
execute_from_index() {
	for ((i=$1; i<${#commands[@]}; i++)); do
		current_task=$i
		eval "${commands[$i]}" || error_exit
	done
}

# Check for the continue option (-c) and optional task index
continue_from=0
while getopts ":c:" opt; do
	case $opt in
		c) continue_from=$OPTARG ;;
		\?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
		:)  echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
	esac
done

# Set up error trap
trap 'error_exit' ERR

# Redirect stderr to a temporary file to capture error messages
exec 2> /tmp/last_error

# Start executing from the provided index, or from the start
execute_from_index $continue_from

