# Telegram Download/Upload Bot

A Telegram bot for handling file downloads and uploads with progress tracking, built with `python-telegram-bot`.

> Note: Dockerized version with UI will be available in the future.
> 

---

## 📌 Description

## **Telegram Download Bot** allows you to download any file shared through Telegram without size limitations. All downloaded files are saved directly to the server where the bot is hosted. You can also specify a custom destination path for storing downloaded files.

## 🚀 Demo

https://media.omeshapasan.site/Static/tgbot.gif

![Demo](https://media.omeshapasan.site/Static/tgbot.gif)

## 🚀 Features

- Download files sent to the bot via Telegram
- Change the download output directory
- Download files from direct URLs with progress tracking
- Upload files from a specified directory to Telegram
- Track upload progress with human-readable file sizes
- Stop ongoing uploads

---

## 🛠️ Prerequisites

- Python 3.7+
- Telegram Bot Token (get one from [@BotFather](https://t.me/BotFather))
- (Optional) [Telegram Bot API Server](https://github.com/tdlib/telegram-bot-api) to bypass the 20MB official limit and improve performance

---

## ⚙️ Installation

---
## ⚡ Quick Install (Auto-Installer)

If you prefer a one-line install instead of manual setup, you can use the provided auto-installer script:

✅ Using curl
```bash
bash <(curl -s https://raw.githubusercontent.com/omeshapasan2/Telegram-File-Link-Download-Bot/main/install.sh)
```

✅ Using wget
```bash
wget -qO- https://raw.githubusercontent.com/omeshapasan2/Telegram-File-Link-Download-Bot/main/install.sh | bash
```

This will:

- Install dependencies
- Build and run the Telegram Bot API server
- Install and configure the bot
- Create and enable systemd services so both auto-start on reboot
---

## ⚙️ Manual Install 

### 1. Clone the repository

```bash
git clone <https://github.com/omeshapasan2/Telegram-File-Link-Download-Bot.git>
cd Telegram-File-Link-Download-Bot

```

### 2. Create a virtual environment (recommended)

```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\\Scripts\\activate

```

### 3. Install dependencies

```bash
pip install -r requirements.txt

```

If `requirements.txt` is missing, use:

```
python-telegram-bot==20.7
requests
humanize
python-dotenv

```

### 4. Configure environment variables

Create a `.env` file in the project root:

```
TELEGRAM_TOKEN=your_telegram_bot_token
BASE_URL=http://localhost:8081/bot  # Optional: only needed with local Bot API server

```

---

## ▶️ Usage

Start the bot:

```bash
python bot.py

```

Send or forward any document to the bot — it will be downloaded on your server!

---

## 💬 Commands

- `/start` — Show welcome message
- `/setoutputdir [path]` — Change the output directory
- `/download [url]` — Download a file from a direct URL
- `/upload [directory]` — Upload all files from a directory to Telegram
- `/stopupload` — Stop ongoing uploads

---

## ⚡ Running Telegram Bot API Locally (To bypass 20MB limit)

Using a local Telegram Bot API server can bypass size limits and increase speed.

### Install dependencies

```bash
sudo apt update
sudo apt install -y build-essential make git zlib1g-dev libssl-dev gperf cmake clang-14 libc++-dev libc++abi-dev

```

### Build the server

```bash
git clone --recursive <https://github.com/tdlib/telegram-bot-api.git>
cd telegram-bot-api
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr/local ..
cmake --build . --target install

```

## 🔑 Get Telegram API Credentials

1. Go to [my.telegram.org](https://my.telegram.org/)
2. Log in and navigate to "API development tools"
3. Create an app and obtain your `api_id` and `api_hash`

### Run the server

```bash
telegram-bot-api --api-id=YOUR_API_ID --api-hash=YOUR_API_HASH --local

```

---

## 🔧 Setting Up as a Service on Ubuntu

### Create `telegram-bot-api.service`

```
[Unit]
Description=Telegram Bot API Server
After=network.target

[Service]
Type=simple
User=YOUR_USERNAME
ExecStart=/usr/local/bin/telegram-bot-api --api-id=YOUR_API_ID --api-hash=YOUR_API_HASH --local
Restart=on-failure

[Install]
WantedBy=multi-user.target

```

### Create `telegram-download-bot.service`

```
[Unit]
Description=Telegram Download Bot
After=network.target telegram-bot-api.service
Requires=telegram-bot-api.service

[Service]
Type=simple
User=YOUR_USERNAME
WorkingDirectory=/path/to/telegram-download-bot
ExecStart=/path/to/telegram-download-bot/venv/bin/python /path/to/telegram-download-bot/bot.py
Environment=PYTHONUNBUFFERED=1
Restart=on-failure

[Install]
WantedBy=multi-user.target

```

### Enable and start services

```bash
sudo systemctl daemon-reload
sudo systemctl enable telegram-bot-api.service
sudo systemctl enable telegram-download-bot.service
sudo systemctl start telegram-bot-api.service
sudo systemctl start telegram-download-bot.service

```

### View logs

```bash
sudo journalctl -u telegram-bot-api.service -f
sudo journalctl -u telegram-download-bot.service -f

```

---
## 🗑️ Uninstallation

If you want to remove the Telegram Download Bot and/or Local API Server:

### Quick Uninstall (Auto-Uninstaller)

✅ Using curl

bash

```bash
bash <(curl -s https://raw.githubusercontent.com/omeshapasan2/Telegram-File-Link-Download-Bot/main/uninstall.sh)
```

✅ Using wget

bash

```bash
wget -qO- https://raw.githubusercontent.com/omeshapasan2/Telegram-File-Link-Download-Bot/main/uninstall.sh | bash
```

The uninstaller will:

- Detect what components are installed (Bot and/or API Server)
- Give you options to remove specific components or everything
- Stop and remove systemd services
- Clean up all installation directories and files
- Provide confirmation prompts for safety

### Manual Uninstall

If you prefer manual removal:

bash

```bash
*# Stop services*
sudo systemctl stop telegram-download-bot.service telegram-bot-api.service

*# Disable services*
sudo systemctl disable telegram-download-bot.service telegram-bot-api.service

*# Remove service files*
sudo rm -f /etc/systemd/system/telegram-download-bot.service
sudo rm -f /etc/systemd/system/telegram-bot-api.service

*# Remove installation directories*
sudo rm -rf /opt/Telegram-File-Link-Download-Bot
sudo rm -rf /opt/telegram-bot-api

*# Remove API server binary*
sudo rm -f /usr/local/bin/telegram-bot-api

*# Reload systemd*
sudo systemctl daemon-reload
```
---



## 🧰 Troubleshooting

- Use the local API server to bypass 20MB file size limits
- Ensure the output directory is writable
- Use `journalctl` logs to investigate issues

---

## 📄 License

[MIT License](https://www.notion.so/omeshapasan/LICENSE)

---
