# TaskGlass Neo

TaskGlass Neo is a futuristic Ubuntu task manager built as a local desktop web app: Chromium renders the glass UI while a local Python/psutil service provides real process and system telemetry.

## Why this build is different

This version does **not** use Tkinter panels or an ASCII-style widget theme. The UI is CSS glassmorphism with translucent surfaces, backdrop blur, layered ambient light, rounded cards, animated telemetry charts, responsive layouts, and an app-style Chromium window.

## Features

- Live process list with CPU, memory, state and thread count
- Search and sort processes
- Terminate, force-kill, suspend and resume
- Raise/lower process priority
- Process inspector with executable, RSS/VMS, files, connections and command
- Launch command dialog
- CPU, RAM, disk and network live charts
- Network interfaces and socket snapshot
- Mounted volume/capacity view
- Kernel/OS/uptime/load/CPU topology/swap telemetry
- Battery reporting when exposed by the system
- Responsive layout and native maximize/minimize via the app window

## Install

```bash
sudo apt update
sudo apt install -y python3 python3-pip chromium curl
python3 -m pip install -r requirements.txt
./run.sh
```

No external web service is needed. The app serves its UI from `127.0.0.1` only.

## Notes

Process actions such as killing system-owned processes can require elevated privileges. The app does not automatically run itself as root.
