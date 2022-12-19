#!/bin/bash

init(){
	export horizon_json=$(curl https://api.github.com/repos/HorizonFFXI/HorizonXI-Launcher-Binaries/releases | jq '.')
	export latest_version=$(echo ${horizon_json} | jq -r '.[].name' | head -n1)
	export download_url=$(echo ${horizon_json} | jq -r '.[] | select(.tag_name=="'${latest_version}'") | .assets[] | select ( .name | endswith ("exe") ) | .browser_download_url')
	export nupkg_name=$(echo ${horizon_json} | jq -r '.[] | select(.tag_name=="'${latest_version}'") | .assets[] | select ( .name | endswith ("nupkg") ) | .name ')
}


check(){

	echo "Checking for version update..."
	if [[ -f ~/horizon-xi/current_version ]]; then
		current_version=$(cat ~/horizon-xi/current_version)
		echo "Installed version: $current_version"
		echo "Latest version: $latest_version"
		if [[ ${current_version} == ${latest_version} ]]; then
			echo "Latest already installed, nothing to do!"
		else
			echo "Updating and launching"
			update
			launch
			echo "$latest_version" > ~/horizon-xi/current_version
		fi
	else
		echo "No current_version exists, updating and logging"
		echo "Updating and launching"
		update
		launch
		echo "$latest_version" > ~/horizon-xi/current_version
	fi

}

update(){

	echo "Creating required directories..."
	mkdir -p ~/horizon-xi
	echo "Found latest version... $latest_version"
	echo "Downloading... $download_url"
	curl -L --max-redirs 5 --output ~/horizon-xi/installer.exe "${download_url}"
	cd ~/horizon-xi
	echo "Expanding installers..."
	7z -y x installer.exe
	echo "Expanding ${nupkg_name}..."
	7z -y x ${nupkg_name}
	echo "Done!"

}

launch(){

	steam_id=$(grep -sir "Horizon XI" /home/deck/.local/share/Steam/userdata/ | grep screenshots | awk '{print $2}' | sed 's/"//g')
        steam steam://rungameid/${steam_id}

}

init
check

