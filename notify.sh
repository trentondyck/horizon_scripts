#!/bin/bash
# set -x

> /tmp/last_error

init(){

  aecho $a  # Command to echo variable a
}
send_variables() {

webhook_url="https://discord.com/api/webhooks/1172713482261631108/cH1dXLPV8jX1d16irijQVWjGbyHnXV4we4pxiXsx-hzBFER1pCG4jGgd3OI8Qh9MTae_" # Replace with your Slack webhook URL
local error_message=$(< /tmp/last_error)

# Capture environment variables
data1=$(printenv | awk '{print}' ORS='\\n')

# Capture all variables available in the script
data2=$(eval "printf '%q\n' $(printf ' "${!%s@}"' _ {a..z} {A..Z})")

# List of known bash-specific variables (Omit from report)
data3="FUNCNAME webhook_url opt i data1 data2 BASH BASH_ALIASES BASH_ARGC BASH_ARGV BASH_ARGV0 BASH_CMDS BASH_COMMAND BASH_LINENO BASHOPTS BASHPID BASH_SOURCE BASH_SUBSHELL BASH_VERSINFO BASH_VERSION COMP_WORDBREAKS DIRSTACK EPOCHREALTIME EPOCHSECONDS EUID GROUPS HISTCMD HOSTNAME HOSTTYPE IFS LINENO MACHTYPE OPTERR OPTIND OSTYPE PIPESTATUS PPID PS4 RANDOM SECONDS SHELLOPTS SRANDOM UID"

# Convert data to arrays
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

# Remove the last "\n" from the string
output=${output%\\n}

# Send JSON payload with curl
# echo "curl -X POST -H \"Content-Type: application/json\" -d \"{\"content\": \"$output\"}\" \"${webhook_url}\""
curl -X POST -H "Content-Type: application/json" -d "{\"content\": \"$output\"}" "${webhook_url}"

}

# Function to send notification to Discord
send_discord_notification() {
    send_variables
}

# Redirect stderr to a temporary file to capture error messages
exec 2> /tmp/last_error

# Array of commands to execute, each on a new line for readability
commands=(
  'init'
  'echo $b'  # Command to echo variable b
)

# Error handling function
error_exit() {
  send_discord_notification
  local next_task_index=$((current_task + 1))
  echo ""
  echo " ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR  ERROR "
  echo ""
  echo "An error occurred with command: '${commands[$current_task]}'"
  echo "After fixing the issue, you can continue by pasting the following into your konsole: "
  echo ""
  echo "./install-or-update.sh -c ${next_task_index}."
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

a=1
b=2

# Set up error trap
trap 'error_exit' ERR

# Start executing from the provided index, or from the start
execute_from_index $continue_from

