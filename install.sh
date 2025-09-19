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

# --- Check if URL points to current server ---
is_local_server() {
    local url=$1
    local hostname=$(echo $url | sed -n 's|.*://\([^:/]*\).*|\1|p')
    local port=$(echo $url | sed -n 's|.*:\([0-9]*\)/.*|\1|p')
    
    # Get current server IP
    local current_ip=$(hostname -I | awk '{print $1}')
    local public_ip=$(curl -s ifconfig.me 2>/dev/null || echo "")
    
    echo "🔍 Analyzing server configuration..."
    echo "Current server IP: $current_ip"
    [ ! -z "$public_ip" ] && echo "Public IP: $public_ip"
    echo "Target hostname: $hostname"
    [ ! -z "$port" ] && echo "Target port: $port"
    
    # Check if hostname matches current server
    if [[ "$hostname" == "localhost" ]] || \
       [[ "$hostname" == "127.0.0.1" ]] || \
       [[ "$hostname" == "$current_ip" ]] || \
       [[ "$hostname" == "$public_ip" ]] || \
       [[ "$hostname" == "$(hostname)" ]] || \
       [[ "$hostname" == "$(hostname -f)" ]]; then
        return 0  # true - local server
    else
        return 1  # false - external server
    fi
}

# --- Collect Inputs ---
echo "📋 Please provide the following information:"
read -p "Enter your TELEGRAM_TOKEN: " TELEGRAM_TOKEN
validate_input "TELEGRAM_TOKEN" "$TELEGRAM_TOKEN"

echo ""
echo "🌐 Bot API Server Configuration:"
echo "You can either:"
echo "  1. Use the official Telegram API (20MB file limit)"
echo "  2. Use a local API server (no file size limit)"
echo "  3. Use an external API server"
echo ""
read -p "Enter BASE_URL (default: https://api.telegram.org/bot for official API, or http://localhost:8081/bot for local): " BASE_URL

# Determine if we need local API server
INSTALL_LOCAL_API=false
USE_OFFICIAL_API=false

if [ -z "$BASE_URL" ]; then
    echo "ℹ️  No BASE_URL provided. Choose an option:"
    echo "  1. Use official Telegram API (20MB limit)"
    echo "  2. Install local API server (no limits)"
    read -p "Enter choice (1 or 2): " choice
    case $choice in
        1)
            BASE_URL="https://api.telegram.org/bot"
            USE_OFFICIAL_API=true
            echo "✅ Using official Telegram API"
            ;;
        2)
            BASE_URL="http://localhost:8081/bot"
            INSTALL_LOCAL_API=true
            echo "✅ Will install local API server"
            ;;
        *)
            echo "❌ Invalid choice"
            exit 1
            ;;
    esac
elif [[ "$BASE_URL" == "https://api.telegram.org/bot"* ]]; then
    USE_OFFICIAL_API=true
    echo "✅ Using official Telegram API (20MB file limit)"
elif is_local_server "$BASE_URL"; then
    INSTALL_LOCAL_API=true
    echo "✅ Detected local server - will install API server"
else
    echo "✅ Using external API server: $BASE_URL"
    echo "ℹ️  Skipping local API server installation"
fi

# Collect API credentials only if needed
if [ "$INSTALL_LOCAL_API" = true ]; then
    echo ""
    echo "🔑 Local API server requires Telegram API credentials:"
    echo "Get them from https://my.telegram.org/ > API development tools"
    read -p "Enter your TELEGRAM API_ID: " API_ID
    read -p "Enter your TELEGRAM API_HASH: " API_HASH
    validate_input "API_ID" "$API_ID"
    validate_input "API_HASH" "$API_HASH"
fi

echo "✅ All inputs collected successfully"

# --- Install Dependencies ---
echo "📦 Installing system dependencies..."
sudo apt update
sudo apt install -y python3 python3-venv python3-pip git

# Install build dependencies only if needed
if [ "$INSTALL_LOCAL_API" = true ]; then
    echo "📦 Installing build dependencies for local API server..."
    sudo apt install -y build-essential make zlib1g-dev libssl-dev gperf cmake clang-14 libc++-dev libc++abi-dev
fi

if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi

echo "✅ Dependencies installed successfully"

# --- Build Telegram Bot API Server (only if needed) ---
if [ "$INSTALL_LOCAL_API" = true ]; then
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
else
    echo "⏭️  Skipping local API server installation"
fi

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
if [ "$USE_OFFICIAL_API" = true ]; then
    # For official API, don't include BASE_URL (use default)
    cat <<EOF > .env
TELEGRAM_TOKEN=$TELEGRAM_TOKEN
EOF
else
    cat <<EOF > .env
TELEGRAM_TOKEN=$TELEGRAM_TOKEN
BASE_URL=$BASE_URL
EOF
fi

echo "✅ Environment file created"

# --- Create systemd Services ---
echo "⚡ Creating systemd services..."

# Create local API service only if needed
if [ "$INSTALL_LOCAL_API" = true ]; then
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
    echo "✅ Local API server service created"
fi

# Create bot service (with or without API dependency)
if [ "$INSTALL_LOCAL_API" = true ]; then
    # Bot depends on local API service
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
else
    # Bot runs independently
    sudo tee /etc/systemd/system/telegram-download-bot.service > /dev/null <<EOF
[Unit]
Description=Telegram Download Bot
After=network.target

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
fi

echo "✅ Bot service created"

# --- Enable & Start Services ---
echo "🚀 Enabling and starting services..."
sudo systemctl daemon-reload

if [ "$INSTALL_LOCAL_API" = true ]; then
    sudo systemctl enable telegram-bot-api.service
    echo "🔄 Starting API server..."
    sudo systemctl restart telegram-bot-api.service
    sleep 3
fi

sudo systemctl enable telegram-download-bot.service
echo "🔄 Starting bot..."
sudo systemctl restart telegram-download-bot.service

# Wait a moment for services to start
sleep 5

# --- Check Service Status ---
echo "🔍 Checking service status..."

if [ "$INSTALL_LOCAL_API" = true ]; then
    if sudo systemctl is-active --quiet telegram-bot-api.service; then
        echo "✅ telegram-bot-api service is running"
    else
        echo "❌ telegram-bot-api service failed to start"
        echo "📋 Checking logs..."
        sudo journalctl -u telegram-bot-api.service --no-pager -l
    fi
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

if [ "$USE_OFFICIAL_API" = true ]; then
    echo "⚠️  Using official Telegram API (20MB file size limit)"
elif [ "$INSTALL_LOCAL_API" = true ]; then
    echo "🚀 Using local API server (no file size limits)"
else
    echo "🌐 Using external API server: $BASE_URL"
fi

echo ""
echo "📋 Useful commands:"
if [ "$INSTALL_LOCAL_API" = true ]; then
    echo "👉 Check API server logs: sudo journalctl -u telegram-bot-api.service -f"
    echo "👉 Restart API server: sudo systemctl restart telegram-bot-api.service"
fi
echo "👉 Check bot logs: sudo journalctl -u telegram-download-bot.service -f"
echo "👉 Restart bot: sudo systemctl restart telegram-download-bot.service"
if [ "$INSTALL_LOCAL_API" = true ]; then
    echo "👉 Stop all services: sudo systemctl stop telegram-bot-api.service telegram-download-bot.service"
else
    echo "👉 Stop bot: sudo systemctl stop telegram-download-bot.service"
fi
echo ""
echo "🤖 Your bot should now be ready to use!"
echo "Send /start to your bot to test it."
