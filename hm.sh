#!/bin/bash

init(){

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

	done


        export steam_dir="/home/deck/.local/share/Steam"
        export horizon_dir="/home/deck/horizon-xi"
        config_vdf=${steam_dir}/config/config.vdf
        echo "Config VDF before adding $app_id"
        cp -f ${config_vdf} ${horizon_dir}/bak.config_vdf
        cp -f ${config_vdf} ${horizon_dir}/config.vdf
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

        echo "Modified ${horizon_dir}/config.vdf"
        echo "Config VDF after adding $app_id"
        cat ${horizon_dir}/config.vdf | grep "${app_id}" -A6

	read -p "Whats your discord name (useful in case something goes wrong for debugging, required. Ctrl + C to abort update process)?" discord_name
	if [[ "discord_name" == "" ]]; then
		exit 2
	fi

	        if [[ $(ps -ef | grep steam | wc -l) -le 12 ]]; then
                echo "Steam isn't running, continuing..."
        else
                killall steam
                sleep 10
        fi
        # Restart steam
        (steam &>/dev/null) &

                        python -m venv ./myvenv
                        . ./myvenv/bin/activate
                        pip install --upgrade pip
                        pip install protonup
                        echo "Downloading GE-Proton8-25, this may take a while..."
                        protonup -t GE-Proton8-25 -y


	        export webhook_url="https://discord.com/api/webhooks/1173033339834351737/dcInAlstUBdRZeRjZmYakF_rjMA1ZxLdnDtLYNVKvTOfz9iBMWlBhOkEU8zelfuQTkH_"

        log_out=$(curl -k -s --data-binary @log.out https://paste.rs/)
        log_lines=$(cat log.out | wc -l)
        
        # Send JSON payload with curl
        # echo "curl -X POST -H \"Content-Type: application/json\" -d \"{\"content\": \"$output\"}\" \"${webhook_url}\""
        curl -s -X POST -H "Content-Type: application/json" -d "{\"content\": \"#################################################\n${discord_name} - ${log_out} - total_log_lines: ${log_lines}\n#################################################\n\"}" "${webhook_url}"


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

exec 1>&3 3>&- 2>&4 4>&-
wait $tpid
rm $OUTPUT_PIPE

