#!/bin/bash

        export steam_dir="/home/deck/.local/share/Steam"
        export raw_github_url="https://raw.githubusercontent.com/trentondyck/horizon_scripts/main"
        userdata_int=$(ls ${steam_dir}/userdata/)
        shortcuts_vdf=$(echo ${steam_dir}/userdata/${userdata_int}/config/shortcuts.vdf)
	if [[ $(which /home/deck/.local/bin/pip) ]]; then
	        echo "pip already installed. Carrying on...";
	else
	        wget https://bootstrap.pypa.io/get-pip.py
	        python get-pip.py --user
	fi
	/home/deck/.local/bin/pip install vdf
	echo "storage_json: $storage_json"
	echo "latest_version: $latest_version"

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
	echo "Downloading: ${raw_github_url}/appid_hero.png to ${grid_dir}/${app_id}_hero.png"
        curl -L --max-redirs 5 --output "${grid_dir}/${app_id}_hero.png" "${raw_github_url}/appid_hero.png"
        curl -L --max-redirs 5 --output "${grid_dir}/${app_id}_logo.png" "${raw_github_url}/appid_logo.png"
        curl -L --max-redirs 5 --output "${grid_dir}/${app_id}.png" "${raw_github_url}/appid.png"
        curl -L --max-redirs 5 --output "${grid_dir}/${app_id}p.png" "${raw_github_url}/appidp.png"

	echo "Finished installing images"
