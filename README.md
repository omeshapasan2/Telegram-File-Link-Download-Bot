# Telegram Download Bot
Telegram bot to download files on Telegram with no size limit.

## Requirements
- Python 3.7+

## Install
1. Install this bot:
	```bash
	git clone https://github.com/RtiM0/telegram-download-bot.git
	cd telegram-download-bot
	python3 -m venv env
	source env/bin/activate
	python -m pip install -r requirements.txt
	deactivate
	```
2. Set your Bot Token (can be obtained by [@BotFather](https://t.me/BotFather)) in `line  14`
	```python
	TOKEN = "BOT-TOKEN"
	```	
	Set your output directory to store the downloaded files in `line 16`
	```python
	OUTPUT_DIR  =  "/home/potato/tgdownloadbot/"
	```
3. You need to run [Telegram Bot API Server](https://github.com/tdlib/telegram-bot-api#usage) locally on your machine to bypass the 20MB Download limit imposed with official Bot API.
Use this [guide to quickly install Telegram Bot API Server locally](https://tdlib.github.io/telegram-bot-api/build.html).
4. Run the Telegram Bot API Server
	```bash
	cd telegram-bot-api/bin/
	./telegram-bot-api --api-id <API-ID> --api-hash <API-HASH> --local
	```
5. In a new terminal run the bot.
	```bash
	cd telegram-download-bot
	source env/bin/activate
	python bot.py
	```
## Usage
Just send or forward the bot any document and it will download it on your server!
=======
# Telegram Download/Upload Bot

A Telegram bot for handling file downloads and uploads with progress tracking, built with python-telegram-bot.

**Dockerized version with UI will be available in the Future...**

## Features

- Download files sent to the bot
- Download files from direct URLs with progress tracking
- Upload files from a specified directory to Telegram
- Stop ongoing uploads
- Change the download output directory
- Track upload progress with human-readable file sizes

## Prerequisites

- Python 3.7+
- Telegram Bot API server (optional but recommended for faster file transfers)
- A Telegram Bot Token (obtained from [@BotFather](https://t.me/BotFather))

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/telegram-download-bot.git
cd telegram-download-bot
```

### 2. Create a virtual environment (optional but recommended)

```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

### 4. Create the requirements.txt file with the following content:

```
python-telegram-bot==20.7
requests
humanize
python-dotenv
```

### 5. Configure environment variables

Create a `.env` file in the project directory with the following content:

```
TELEGRAM_TOKEN=your_telegram_bot_token
BASE_URL=http://localhost:8081/bot  # Only needed if using local Telegram Bot API server
```

Replace `your_telegram_bot_token` with the token obtained from [@BotFather](https://t.me/BotFather).

## Usage

### Start the bot

```bash
python bot.py
```

### Available commands

- `/start` - Welcome message
- `/setoutputdir [path]` - Change the download directory (default: `/DATA/Media/`)
- `/download [url]` - Download a file from a direct URL
- `/upload [directory]` - Upload all files from a directory to Telegram
- `/stopupload` - Stop an ongoing upload

## Setting up Telegram Bot API Server (Optional but recommended)

Using the Telegram Bot API server locally improves file transfer speed significantly.

### 1. Install dependencies

```bash
sudo apt-get update
sudo apt-get install -y build-essential make git zlib1g-dev libssl-dev gperf cmake clang-14 libc++-dev libc++abi-dev
```

### 2. Clone and build the Telegram Bot API

```bash
git clone --recursive https://github.com/tdlib/telegram-bot-api.git
cd telegram-bot-api
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr/local ..
cmake --build . --target install
```

### 3. Run the Telegram Bot API server

```bash
telegram-bot-api --api-id=YOUR_API_ID --api-hash=YOUR_API_HASH --local
```

Replace `YOUR_API_ID` and `YOUR_API_HASH` with your values obtained from [my.telegram.org](https://my.telegram.org).

## Setting Up Services in Ubuntu

### 1. Create a systemd service for the Telegram Bot API

Create a file at `/etc/systemd/system/telegram-bot-api.service` with the following content:

```ini
[Unit]
Description=Telegram Bot API Server
After=network.target

[Service]
Type=simple
User=YOUR_USERNAME
ExecStart=/usr/local/bin/telegram-bot-api --api-id=YOUR_API_ID --api-hash=YOUR_API_HASH --local
Restart=on-failure
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
```

Replace `YOUR_USERNAME`, `YOUR_API_ID`, and `YOUR_API_HASH` with your values.

### 2. Create a systemd service for the Download Bot

Create a file at `/etc/systemd/system/telegram-download-bot.service` with the following content:

```ini
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
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
```

Replace `YOUR_USERNAME` and `/path/to/telegram-download-bot` with your actual username and the path to your bot directory.

### 3. Enable and start the services

```bash
# Reload systemd to recognize new services
sudo systemctl daemon-reload

# Enable services to start at boot
sudo systemctl enable telegram-bot-api.service
sudo systemctl enable telegram-download-bot.service

# Start services
sudo systemctl start telegram-bot-api.service
sudo systemctl start telegram-download-bot.service

# Check status
sudo systemctl status telegram-bot-api.service
sudo systemctl status telegram-download-bot.service
```

### 4. View logs

```bash
# For Telegram Bot API server
sudo journalctl -u telegram-bot-api.service -f

# For Download Bot
sudo journalctl -u telegram-download-bot.service -f
```

## Obtaining Telegram API Credentials

1. Visit [my.telegram.org](https://my.telegram.org) and log in
2. Click on "API development tools"
3. Create a new application (or use an existing one)
4. Note down the "App api_id" and "App api_hash" values
5. Use these values in the telegram-bot-api.service configuration

## Troubleshooting

- If files larger than 50MB don't upload, you likely need to use the local Telegram Bot API server
- Make sure the output directory is writable by the user running the bot
- Check the logs for any errors using the journalctl commands above

## License

[MIT License](LICENSE)
