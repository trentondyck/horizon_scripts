add_non_steam_game(){

        app_name="Horizon XI test 3"

        # Source - https://github.com/sonic2kk/steamtinkerlaunch/issues/729
        # 1 Download the latest release
        if [[ $( which /home/deck/horizon-xi/stl/sonic2kk-steamtinkerlaunch-e7c5ada/steamtinkerlaunch ) ]]; then
                echo "Steam tinker launch already installed, continuing..."
        else
                stl_json=$(curl https://api.github.com/repos/sonic2kk/steamtinkerlaunch/releases)
                latest_stl_version=$(echo ${stl_json} | jq -r '.[].tag_name' | head -n1)
                stl_zip_url=$(echo ${stl_json} | jq -r '.[] | select(.tag_name=="'${latest_stl_version}'") | .zipball_url')
                echo "Downloading... ${stl_zip_url}"
                curl -L --max-redirs 5 --output /home/deck/horizon-xi/stl.zip "${stl_zip_url}"
                unzip /home/deck/horizon-xi/stl.zip -d /home/deck/horixon-xi/stl
        fi

        # 2 Add a non-steam game via stl
        # docs - https://github.com/sonic2kk/steamtinkerlaunch/wiki/Add-Non-Steam-Game
        /home/deck/horizon-xi/stl/sonic2kk-steamtinkerlaunch-e7c5ada/steamtinkerlaunch addnonsteamgame --appname="${app_name}" --exepath=/home/deck/horizon-xi/lib/net45/HorizonXI-Launcher.exe --startdir=/home/deck/horizon-xi/lib/net45/

        # 3 Download pip
        if [[ $(which /home/deck/.local/bin/pip) ]]; then 
                echo "pip already installed. Carrying on...";
        else 
                wget https://bootstrap.pypa.io/get-pip.py
                python get-pip.py --user
        fi
        # 4 install vdf module
        /home/deck/.local/bin/pip install vdf

        # 6 load the vdf, grab the app_id
        # Source - https://github.com/DavidoTek/ProtonUp-Qt/issues/175
        shortcuts_vdf=$(find /home/deck/.local/share/Steam/ -name "shortcuts.vdf" -type f)
        echo "Installing to $shortcuts_vdf"
        # Documentation - https://github.com/ValvePython/vdf
        app_id=$(python -c "import vdf; d=vdf.binary_loads(open('${shortcuts_vdf}', 'rb').read()); items = list(d['shortcuts'].values()); print([i for i in items if i['appname'] in ['${app_name}']][0]['appid']+2**32);")
        echo "app_id: $app_id"
        config_vdf=/home/deck/.local/share/Steam/config/config.vdf
        # Documentation - https://github.com/ValvePython/vdf
        python -c "import vdf; d=vdf.load(open('${config_vdf}')); ctm = d['InstallConfigStore']['Software']['Valve']['Steam']['CompatToolMapping']; ctm['${app_id}']={ 'name': 'GE-Proton7-42', 'config': '', 'priority': '250' }; vdf.dump(d, open('/home/deck/horizon-xi/config.vdf','w'), pretty=True);"
        cp -f /home/deck/horizon-xi/config.vdf $config_vdf
        echo "Successfully added nonsteam game"

}

add_non_steam_game
