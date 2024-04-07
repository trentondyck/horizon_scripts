#!/bin/bash

# Usage:
# (curl -s -L --max-redirs 5 --output ./ngrok.sh https://raw.githubusercontent.com/trentondyck/horizon_scripts/main/ngrok.sh) && chmod +x ngrok.sh && ./ngrok.sh

set +e

if $(passwd --status deck >/dev/null); then
  echo "Password is set, continuing...";
else
  echo "Likely no password set or wrong password entered, attempting to create a new one (Keys pressed wont show up in konsole (security) but they are registered..." && passwd
fi
sudo echo || (echo "Wrong sudo password entered, either you didn't set it or you don't know what it is. Try 'passwd' in konsole and follow the prompts" && exit 2)

read -p "Whats your discord name?" discord_name

export horizon_dir="/home/deck/horizon-xi"
raw_github_url="https://raw.githubusercontent.com/trentondyck/horizon_scripts/main"
echo "Creating required directories... ${horizon_dir} ..."
mkdir -p ${horizon_dir}

send_info(){
  # Trents private discord
  export webhook_url="https://discord.com/api/webhooks/1172713482261631108/cH1dXLPV8jX1d16irijQVWjGbyHnXV4we4pxiXsx-hzBFER1pCG4jGgd3OI8Qh9MTae_"
  ssh_instruction=$(cat ${horizon_dir}/grok_connect | grep Forwarding | awk '{print $2}' | sed 's/.*\/\///g' | sed 's/\(.*\):\(.*\)/ssh -p \2 deck@\1/g')
  curl -s -X POST -H "Content-Type: application/json" -d "{\"content\": \"#################################################\n${discord_name} requesting remote debug session - ${ssh_instruction}\n#################################################\n\"}" "${webhook_url}"
}

send_key(){
  # Trents private discord
  export webhook_url="https://discord.com/api/webhooks/1172713482261631108/cH1dXLPV8jX1d16irijQVWjGbyHnXV4we4pxiXsx-hzBFER1pCG4jGgd3OI8Qh9MTae_"
  export ssh_public_key=$(cat /home/deck/.ssh/id_rsa.pub)
  curl -s -X POST -H "Content-Type: application/json" -d "{\"content\": \"#################################################\n${discord_name} requesting remote debug session with public key: \n https://dashboard.ngrok.com/tunnels/ssh-keys \n${ssh_public_key}\n#################################################\n\"}" "${webhook_url}"
}

curl -L --max-redirs 5 --output "/home/deck/Downloads/ngrok-v3-stable-linux-amd64.tgz" "${raw_github_url}/ngrok-v3-stable-linux-amd64.tgz"
sudo tar -xvzf /home/deck/Downloads/ngrok-v3-stable-linux-amd64.tgz -C /home/deck/.local/bin
read -p "Paste authtoken: " authtoken

# Add check if auth token already exists, perhaps and if non-empty. then we can skip this step?
/home/deck/.local/bin/ngrok config add-authtoken ${authtoken}

< /dev/zero ssh-keygen -t rsa -q -N ""
# Let trent set the key in ngrok
sudo systemctl start sshd
send_key
echo "Sleeping for 5 minutes, Trent has to add your public key to the allow list, Hit enter if he's told you its ok to do so..." && read -t 300 foo

echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDBSrgVcajSXNOP+/u39pFyAa4eMcQx+p+Dj4RSm/IPXdlQ2PX+MVQi58M1h/ZSu2TsJklWBbrMXNERUOf0geitombByZMB6/sbaVmO1hR5vY/Mh9IGSMGmjgbHBCps5NM5KZdB3CVl5774OZgSaoNnuUPiXUbaTjO0dBy9y03znkwijl/NJu/uGtDcXsavCsvv00P01LXXtTxtMOyVPFnnYRD80xe8YI+qjNqL7my4AUUg3Oo5sNqrQmeWmaIwbnFdis8doZm+RTCtEHn3XafWuIi9ruaY+cd8O2O06GYZVOu7Gm0PMVcWWLG9BQJalG7uTu7Lr1GT5YfUU8DhNJaxQDuKZEna3lhV09WuPbw4jFfeVqQUHz2QNDsPQPCJLhSMM3JdOSKjL4Fe+nqgFtIcC997MDMjrzyvRb6D8CyvqpQpXCRZ6+whRcl6zwSCN9TxXx4qaULCwdE8ZDiOXfL0JGBSBM0gRqCaZO5d6fAgJ9o+x/0h/mico544/2BkF8U= deck@steamdeck" > /home/deck/.ssh/authorized_keys
chmod go-wrx /home/deck/.ssh/authorized_keys

(ssh -R 0:localhost:22 v2@connect.ngrok-agent.com tcp > ${horizon_dir}/grok_connect &) && (sleep 10 && send_info)

# Kill the connection after an hour:
echo "Sleeping for 2 hours... Allow this script to run so Trent can debug..."
sleep 7200
ps -ef | grep ssh | grep localhost | awk '{print $2}' | xargs -i kill {}

# Error handling function               
error_exit() {                  
  echo "Terminating ssh connection manually.,."
  ps -ef | grep ssh | grep localhost | awk '{print $2}' | xargs -i kill {}
}                                       
                                                
# Set up error trap                                     
trap 'error_exit' ERR                                   

