#!/bin/bash
set -e

echo "🚀 Telegram Download Bot Auto-Installer"
echo "========================================"

# --- Input Validation Function ---
validate_input() {
    local var_name=$1
    local var_value=$2
    if [ -z "$var_value" ]; then
        echo "❌ Error: $var_name cannot be empty"
        exit 1
    fi
}

# --- Collect Inputs ---
echo "📋 Please provide the following information:"
read -p "Enter your TELEGRAM_TOKEN: " TELEGRAM_TOKEN
read -p "Enter your BASE_URL (default: http://localhost:8081/bot): " BASE_URL
BASE_URL=${BASE_URL:-http://localhost:8081/bot}
read -p "Enter your TELEGRAM API_ID: " API_ID
read -p "Enter your TELEGRAM API_HASH: " API_HASH

# Validate inputs
validate_input "TELEGRAM_TOKEN" "$TELEGRAM_TOKEN"
validate_input "API_ID" "$API_ID"
validate_input "API_HASH" "$API_HASH"

echo "✅ All inputs collected successfully"

# --- Install Dependencies ---
echo "📦 Installing system dependencies..."
sudo apt update
sudo apt install -y python3 python3-venv python3-pip build-essential \
    make git zlib1g-dev libssl-dev gperf cmake clang-14 libc++-dev libc++abi-dev

if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi

echo "✅ Dependencies installed successfully"

# --- Build Telegram Bot API Server ---
echo "⚙️ Building Telegram Bot API server..."
if [ ! -d "/opt/telegram-bot-api" ]; then
    echo "📥 Cloning Telegram Bot API repository..."
    sudo git clone --recursive https://github.com/tdlib/telegram-bot-api.git /opt/telegram-bot-api
    if [ $? -ne 0 ]; then
        echo "❌ Failed to clone Telegram Bot API repository"
        exit 1
    fi
fi

cd /opt/telegram-bot-api
sudo mkdir -p build && cd build

echo "🔨 Compiling Telegram Bot API..."
sudo cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr/local ..
sudo cmake --build . --target install

# Verify build success
if [ ! -f "/usr/local/bin/telegram-bot-api" ]; then
    echo "❌ Failed to build telegram-bot-api"
    exit 1
fi

echo "✅ Telegram Bot API server built successfully"

# --- Setup Bot ---
echo "📂 Setting up Telegram Download Bot..."
if [ ! -d "/opt/Telegram-File-Link-Download-Bot" ]; then
    echo "📥 Cloning Telegram Download Bot repository..."
    sudo git clone https://github.com/omeshapasan2/Telegram-File-Link-Download-Bot.git /opt/Telegram-File-Link-Download-Bot
    if [ $? -ne 0 ]; then
        echo "❌ Failed to clone bot repository"
        exit 1
    fi
fi

cd /opt/Telegram-File-Link-Download-Bot

# Fix ownership
sudo chown -R $USER:$USER /opt/Telegram-File-Link-Download-Bot

# Create downloads directory
mkdir -p downloads

# Create virtual environment
echo "🐍 Setting up Python virtual environment..."
python3 -m venv venv
if [ $? -ne 0 ]; then
    echo "❌ Failed to create virtual environment"
    exit 1
fi

# Activate virtual environment
source venv/bin/activate
if [ $? -ne 0 ]; then
    echo "❌ Failed to activate virtual environment"
    exit 1
fi

# Check if requirements.txt exists, create if missing
if [ ! -f "requirements.txt" ]; then
    echo "📝 Creating requirements.txt..."
    cat <<EOF > requirements.txt
python-telegram-bot==20.7
requests
humanize
python-dotenv
EOF
fi

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "❌ Failed to install Python dependencies"
    exit 1
fi

echo "✅ Bot setup completed successfully"

# --- Create .env ---
echo "🔑 Creating environment configuration..."
cat <<EOF > .env
TELEGRAM_TOKEN=$TELEGRAM_TOKEN
BASE_URL=$BASE_URL
EOF

echo "✅ Environment file created"

# --- Create systemd Services ---
echo "⚡ Creating systemd services..."

# telegram-bot-api.service
sudo tee /etc/systemd/system/telegram-bot-api.service > /dev/null <<EOF
[Unit]
Description=Telegram Bot API Server
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/local/bin/telegram-bot-api --api-id=$API_ID --api-hash=$API_HASH --local
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# telegram-download-bot.service
sudo tee /etc/systemd/system/telegram-download-bot.service > /dev/null <<EOF
[Unit]
Description=Telegram Download Bot
After=network.target telegram-bot-api.service
Requires=telegram-bot-api.service

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/Telegram-File-Link-Download-Bot
ExecStart=/opt/Telegram-File-Link-Download-Bot/venv/bin/python /opt/Telegram-File-Link-Download-Bot/bot.py
Environment=PYTHONUNBUFFERED=1
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Systemd services created"

# --- Enable & Start Services ---
echo "🚀 Enabling and starting services..."
sudo systemctl daemon-reload

sudo systemctl enable telegram-bot-api.service
sudo systemctl enable telegram-download-bot.service

echo "🔄 Starting services..."
sudo systemctl restart telegram-bot-api.service
sudo systemctl restart telegram-download-bot.service

# Wait a moment for services to start
sleep 5

# --- Check Service Status ---
echo "🔍 Checking service status..."
if sudo systemctl is-active --quiet telegram-bot-api.service; then
    echo "✅ telegram-bot-api service is running"
else
    echo "❌ telegram-bot-api service failed to start"
    echo "📋 Checking logs..."
    sudo journalctl -u telegram-bot-api.service --no-pager -l
fi

if sudo systemctl is-active --quiet telegram-download-bot.service; then
    echo "✅ telegram-download-bot service is running"
else
    echo "❌ telegram-download-bot service failed to start"
    echo "📋 Checking logs..."
    sudo journalctl -u telegram-download-bot.service --no-pager -l
fi

echo ""
echo "🎉 Installation completed!"
echo "========================================"
echo "📁 Bot installed in: /opt/Telegram-File-Link-Download-Bot"
echo "📥 Downloads will be saved to: /opt/Telegram-File-Link-Download-Bot/downloads"
echo ""
echo "📋 Useful commands:"
echo "👉 Check API server logs: sudo journalctl -u telegram-bot-api.service -f"
echo "👉 Check bot logs: sudo journalctl -u telegram-download-bot.service -f"
echo "👉 Restart API server: sudo systemctl restart telegram-bot-api.service"
echo "👉 Restart bot: sudo systemctl restart telegram-download-bot.service"
echo "👉 Stop services: sudo systemctl stop telegram-bot-api.service telegram-download-bot.service"
echo ""
echo "🤖 Your bot should now be ready to use!"
echo "Send /start to your bot to test it."
