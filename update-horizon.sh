#!/bin/bash

update(){

	echo "Creating required directories..."
	mkdir -p ~/horizon-xi
	horizon_json=$(curl https://api.github.com/repos/HorizonFFXI/HorizonXI-Launcher-Binaries/releases | jq '.')
	latest_version=$(echo ${horizon_json} | jq -r '.[].name' | head -n1)
	echo "Found latest version... $latest_version"
	download_url=$(echo ${horizon_json} | jq -r '.[] | select(.tag_name=="'${latest_version}'") | .assets[] | select ( .name | endswith ("exe") ) | .browser_download_url')
	nupkg_name=$(echo ${horizon_json} | jq -r '.[] | select(.tag_name=="'${latest_version}'") | .assets[] | select ( .name | endswith ("nupkg") ) | .name ')
	echo "Downloading... $download_url"
	curl -L --max-redirs 5 --output ~/horizon-xi/installer.exe "${download_url}"
	cd ~/horizon-xi
	echo "Expanding installers..."
	7z -y x installer.exe
	echo "Expanding ${nupkg_name}..."
	7z -y x ${nupkg_name}
	echo "Done!"

}

update

