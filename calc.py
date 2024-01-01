import os
import hashlib
import glob
import requests

# How to use
# (curl -s -L --max-redirs 5 --output ./calc.py https://raw.githubusercontent.com/trentondyck/horizon_scripts/main/calc.py) && python calc.py

def calculate_md5(file_path):
    hash_md5 = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

def find_dat_files(root_directory, base_folder_name):
    dat_files = {}
    for root, dirs, files in os.walk(root_directory):
        for file in files:
            if file.endswith(".DAT"):
                full_path = os.path.join(root, file)
                relative_path = os.path.join(base_folder_name, os.path.relpath(full_path, root_directory))
                dat_files[relative_path] = calculate_md5(full_path)
    return dat_files

def find_directory_path():
    manifest_files = glob.glob('/home/deck/.local/share/Steam/steamapps/compatdata/*/pfx/drive_c/Program Files/HorizonXI/Game/SquareEnix/FINAL FANTASY XI/polboot.exe.manifest')
    if manifest_files:
        return os.path.dirname(manifest_files[0])
    else:
        raise FileNotFoundError("polboot.exe.manifest not found")

# Find directory path
directory_path = find_directory_path()

rom_directories = [d for d in os.listdir(directory_path) if os.path.isdir(os.path.join(directory_path, d)) and d.startswith("ROM")]

file_md5_map = {}
for dir in rom_directories:
    file_md5_map.update(find_dat_files(os.path.join(directory_path, dir), dir))

# Log file path
log_file_path = 'dat_file_md5_map.log'

# Write the map to a log file
with open(log_file_path, 'w') as log_file:
    for file_path, md5 in file_md5_map.items():
        log_file.write(f"{file_path}: {md5}\n")

print(f"MD5 mapping completed. Results written to: {log_file_path}")

def send_to_pasters(file_path):
    with open(file_path, 'rb') as file:
        response = requests.post("https://paste.rs/", data=file)
        return response.text

def send_to_discord(webhook_url, message):
    payload = {"content": message}
    response = requests.post(webhook_url, json=payload)
    return response.status_code

# Log file path
log_file_path = 'dat_file_md5_map.log'

# Discord webhook URL
webhook_url = "https://discord.com/api/webhooks/1191228624653791332/li0RSjJKK1itj1XlyWBjnFsNpjVZaCOwFZqnpQh5spsXWqHNTwVyZq5Y6BQYmL8MSZrr"

# Send log file to paste.rs
paste_url = send_to_pasters(log_file_path)

# Format the message
message = f"###################################\n{paste_url}\n###################################\n"

# Send the message to Discord
response_status = send_to_discord(webhook_url, message)

if response_status == 204:
    print("Message successfully sent to Discord.")
else:
    print(f"Failed to send message to Discord. Status code: {response_status}")

