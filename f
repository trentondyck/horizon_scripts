#!/bin/bash

	export webhook_url="https://discord.com/api/webhooks/1172713482261631108/cH1dXLPV8jX1d16irijQVWjGbyHnXV4we4pxiXsx-hzBFER1pCG4jGgd3OI8Qh9MTae_" # Replace with your Slack webhook URL
	# Make sure last_error is all on one line
	echo "trent" > /tmp/last_error
	sed -i ':a;N;$!ba;s/\n/,/g' /tmp/last_error

	# Local variables are not needed for continuation runs, and can be excluded from init (variables required to be generated every run)
	# Simply by defining the error_message variable, we'll see it in the output in discord.
	error_message=$(< /tmp/last_error)

	# Capture environment variables
	data1=$(printenv | awk '{print}' ORS='\\n')

	# Capture all variables available in the script
	data2=$(eval "printf '%q\n' $(printf ' "${!%s@}"' _ {a..z} {A..Z})")

	# List of known bash-specific variables (Omit from report)
	data3="FUNCNAME webhook_url opt i data1 data2 BASH BASH_ALIASES BASH_ARGC BASH_ARGV BASH_ARGV0 BASH_CMDS BASH_COMMAND BASH_LINENO BASHOPTS BASHPID BASH_SOURCE BASH_SUBSHELL BASH_VERSINFO BASH_VERSION COMP_WORDBREAKS DIRSTACK EPOCHREALTIME EPOCHSECONDS EUID GROUPS HISTCMD HOSTNAME HOSTTYPE IFS LINENO MACHTYPE OPTERR OPTIND OSTYPE PIPESTATUS PPID PS4 RANDOM SECONDS SHELLOPTS SRANDOM UID"

	# Convert data to arrays; Couldn't figure out how to make this
	readarray -t arr1 <<< "$(echo -e "$data1" | sed 's/=.*//' | sort)"
	readarray -t arr2 <<< "$(echo "$data2" | tr ' ' '\n' | sort)"
	readarray -t arr3 <<< "$(echo "$data3" | tr ' ' '\n' | sort)"

	# Find unique variables in arr2 not in arr1
	unique_to_arr2=$(comm -23 <(printf "%s\n" "${arr2[@]}") <(printf "%s\n" "${arr1[@]}"))

	# Find unique variables in the above result not in arr3
	final_result=$(comm -23 <(printf "%s\n" "${unique_to_arr2[@]}") <(printf "%s\n" "${arr3[@]}"))

	# Initialize an empty string
	output=""

	# Loop through the variables
	for var in ${final_result[@]}; do
	    # Append variable and value to the string with "\n" separator
	    output+="${var}=${!var}\\n"
	done

	# Get release info
	for line in $(ls /etc/*release); do
		output+="${line}\\n"
	done

	for line in $(cat /etc/*release); do
            sanitized=$(echo $line | sed 's/"//g')
	    output+="${sanitized}\\n"
	done

	# Remove the last "\n" from the string
	output=${output%\\n}

	echo "output:"
	echo $output

	# Send JSON payload with curl
	# echo "curl -X POST -H \"Content-Type: application/json\" -d \"{\"content\": \"$output\"}\" \"${webhook_url}\""
	curl -s -X POST -H "Content-Type: application/json" -d "{\"content\": \"#################################################\n$output\n#################################################\n\"}" "${webhook_url}"

	echo "" > /tmp/last_error
