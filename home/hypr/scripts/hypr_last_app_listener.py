import subprocess
import json
import os
import time

CACHE_FILE = os.path.expanduser("~/.cache/last_closed_app")

def get_process_cmdline(pid):
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            cmdline_bytes = f.read()
        parts = cmdline_bytes.split(b'\0')
        cmdline = [p.decode('utf-8', errors='ignore') for p in parts if p]
        return " ".join(cmdline)
    except Exception:
        return None

def get_window_info(window_address):
    try:
        result = subprocess.run(['hyprctl', 'clients', '-j'], capture_output=True, text=True, check=True)
        clients = json.loads(result.stdout)
        for client in clients:
            if client.get('address') == window_address:
                return client
    except Exception:
        return None

def listen_to_hyprland_events():
    print("Starting Hyprland event listener...")

    # The most reliable way to get the signature is from the environment variable
    # set by Hyprland itself.
    instance_signature = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')

    if not instance_signature:
        print("ERROR: HYPRLAND_INSTANCE_SIGNATURE environment variable not found.")
        print("This script needs to be launched from within Hyprland (e.g., via exec-once in hyprland.conf).")
        print("Exiting.")
        return

    event_socket_path = f"/tmp/hypr/{instance_signature}/.socket2.sock"
    print(f"Found instance signature. Connecting to socket: {event_socket_path}")

    command = ['socat', f'UNIX-CONNECT:{event_socket_path}', 'STDIN']
    
    while True:
        try:
            process = subprocess.Popen(command, stdout=subprocess.PIPE, text=True, bufsize=1)
            for line in iter(process.stdout.readline, ''):
                if line.startswith('closewindow>>'):
                    window_address = line.split('>>')[1].strip()
                    # Give Hyprland a moment to update its client list
                    time.sleep(0.1) 
                    client_info = get_window_info(window_address)
                    if client_info:
                        pid = client_info.get('pid')
                        if pid and (cmdline := get_process_cmdline(pid)):
                            with open(CACHE_FILE, "w") as f:
                                f.write(cmdline)
                            print(f"Saved command: '{cmdline}'")

            # If socat exits, Hyprland probably restarted. Loop and reconnect.
            print("Listener socket closed. Reconnecting in 2 seconds...")
            time.sleep(2)

        except FileNotFoundError:
            print(f"FATAL: socat command not found or socket disconnected. Retrying in 5s.")
            time.sleep(5)
        except Exception as e:
            print(f"An unexpected error occurred: {e}. Retrying in 5s.")
            time.sleep(5)

if __name__ == "__main__":
    os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
    listen_to_hyprland_events()