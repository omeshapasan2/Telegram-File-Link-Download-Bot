#!/bin/bash

echo "🗑️  Telegram Download Bot Uninstaller"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Detection Functions ---
check_service_exists() {
    systemctl list-unit-files | grep -q "^$1"
}

check_service_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

check_directory_exists() {
    [ -d "$1" ]
}

check_file_exists() {
    [ -f "$1" ]
}

# --- Detect Installation Status ---
echo "🔍 Detecting current installation..."

BOT_SERVICE_EXISTS=false
API_SERVICE_EXISTS=false
BOT_DIR_EXISTS=false
API_DIR_EXISTS=false
API_BINARY_EXISTS=false

# Check services
if check_service_exists "telegram-download-bot.service"; then
    BOT_SERVICE_EXISTS=true
    echo "✅ Found: telegram-download-bot service"
fi

if check_service_exists "telegram-bot-api.service"; then
    API_SERVICE_EXISTS=true
    echo "✅ Found: telegram-bot-api service"
fi

# Check directories
if check_directory_exists "/opt/Telegram-File-Link-Download-Bot"; then
    BOT_DIR_EXISTS=true
    echo "✅ Found: Bot installation directory"
fi

if check_directory_exists "/opt/telegram-bot-api"; then
    API_DIR_EXISTS=true
    echo "✅ Found: API server source directory"
fi

# Check API binary
if check_file_exists "/usr/local/bin/telegram-bot-api"; then
    API_BINARY_EXISTS=true
    echo "✅ Found: API server binary"
fi

# --- Determine Installation Type ---
if [ "$BOT_SERVICE_EXISTS" = false ] && [ "$API_SERVICE_EXISTS" = false ] && [ "$BOT_DIR_EXISTS" = false ]; then
    echo ""
    echo "❌ No Telegram Bot installation found!"
    echo "Nothing to uninstall."
    exit 0
fi

echo ""
echo "📋 Installation Summary:"
echo "========================"

if [ "$BOT_SERVICE_EXISTS" = true ] || [ "$BOT_DIR_EXISTS" = true ]; then
    echo -e "${GREEN}🤖 Telegram Download Bot: INSTALLED${NC}"
    if check_service_active "telegram-download-bot.service"; then
        echo -e "   Status: ${GREEN}RUNNING${NC}"
    else
        echo -e "   Status: ${YELLOW}STOPPED${NC}"
    fi
fi

if [ "$API_SERVICE_EXISTS" = true ] || [ "$API_DIR_EXISTS" = true ] || [ "$API_BINARY_EXISTS" = true ]; then
    echo -e "${GREEN}⚡ Local API Server: INSTALLED${NC}"
    if check_service_active "telegram-bot-api.service"; then
        echo -e "   Status: ${GREEN}RUNNING${NC}"
    else
        echo -e "   Status: ${YELLOW}STOPPED${NC}"
    fi
fi

echo ""

# --- Removal Options ---
BOTH_INSTALLED=false
if ([ "$BOT_SERVICE_EXISTS" = true ] || [ "$BOT_DIR_EXISTS" = true ]) && \
   ([ "$API_SERVICE_EXISTS" = true ] || [ "$API_DIR_EXISTS" = true ] || [ "$API_BINARY_EXISTS" = true ]); then
    BOTH_INSTALLED=true
fi

if [ "$BOTH_INSTALLED" = true ]; then
    echo "🤔 What would you like to remove?"
    echo "1. Only the Telegram Download Bot"
    echo "2. Only the Local API Server"
    echo "3. Both Bot and API Server (Complete removal)"
    echo "4. Cancel (Exit without removing anything)"
    echo ""
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            REMOVE_BOT=true
            REMOVE_API=false
            echo -e "${YELLOW}Will remove: Telegram Download Bot only${NC}"
            ;;
        2)
            REMOVE_BOT=false
            REMOVE_API=true
            echo -e "${YELLOW}Will remove: Local API Server only${NC}"
            ;;
        3)
            REMOVE_BOT=true
            REMOVE_API=true
            echo -e "${YELLOW}Will remove: Both Bot and API Server${NC}"
            ;;
        4)
            echo "❌ Cancelled by user"
            exit 0
            ;;
        *)
            echo "❌ Invalid choice"
            exit 1
            ;;
    esac
else
    # Only one component installed
    if [ "$BOT_SERVICE_EXISTS" = true ] || [ "$BOT_DIR_EXISTS" = true ]; then
        REMOVE_BOT=true
        REMOVE_API=false
        echo -e "${YELLOW}Will remove: Telegram Download Bot${NC}"
    else
        REMOVE_BOT=false
        REMOVE_API=true
        echo -e "${YELLOW}Will remove: Local API Server${NC}"
    fi
    
    echo ""
    read -p "Proceed with removal? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "❌ Cancelled by user"
        exit 0
    fi
fi

echo ""
echo "⚠️  WARNING: This will permanently delete the selected components!"
read -p "Are you sure? Type 'YES' to confirm: " final_confirm

if [ "$final_confirm" != "YES" ]; then
    echo "❌ Cancelled - 'YES' not entered"
    exit 0
fi

echo ""
echo "🗑️  Starting removal process..."

# --- Remove Bot ---
if [ "$REMOVE_BOT" = true ]; then
    echo ""
    echo "🤖 Removing Telegram Download Bot..."
    
    # Stop and disable bot service
    if [ "$BOT_SERVICE_EXISTS" = true ]; then
        echo "🛑 Stopping telegram-download-bot service..."
        sudo systemctl stop telegram-download-bot.service 2>/dev/null || true
        
        echo "❌ Disabling telegram-download-bot service..."
        sudo systemctl disable telegram-download-bot.service 2>/dev/null || true
        
        echo "🗑️  Removing service file..."
        sudo rm -f /etc/systemd/system/telegram-download-bot.service
    fi
    
    # Remove bot directory
    if [ "$BOT_DIR_EXISTS" = true ]; then
        echo "🗂️  Removing bot installation directory..."
        sudo rm -rf /opt/Telegram-File-Link-Download-Bot
    fi
    
    echo -e "${GREEN}✅ Telegram Download Bot removed successfully${NC}"
fi

# --- Remove API Server ---
if [ "$REMOVE_API" = true ]; then
    echo ""
    echo "⚡ Removing Local API Server..."
    
    # Stop and disable API service
    if [ "$API_SERVICE_EXISTS" = true ]; then
        echo "🛑 Stopping telegram-bot-api service..."
        sudo systemctl stop telegram-bot-api.service 2>/dev/null || true
        
        echo "❌ Disabling telegram-bot-api service..."
        sudo systemctl disable telegram-bot-api.service 2>/dev/null || true
        
        echo "🗑️  Removing service file..."
        sudo rm -f /etc/systemd/system/telegram-bot-api.service
    fi
    
    # Remove API binary
    if [ "$API_BINARY_EXISTS" = true ]; then
        echo "🗑️  Removing API server binary..."
        sudo rm -f /usr/local/bin/telegram-bot-api
    fi
    
    # Remove API source directory
    if [ "$API_DIR_EXISTS" = true ]; then
        echo "🗂️  Removing API server source directory..."
        sudo rm -rf /opt/telegram-bot-api
    fi
    
    echo -e "${GREEN}✅ Local API Server removed successfully${NC}"
fi

# --- Cleanup ---
echo ""
echo "🧹 Performing cleanup..."

# Reload systemd
sudo systemctl daemon-reload

# Remove any leftover API server files
if [ "$REMOVE_API" = true ]; then
    echo "🔍 Checking for additional API server files..."
    
    # Remove any remaining binaries
    sudo find /usr/local -name "*telegram-bot-api*" -delete 2>/dev/null || true
    
    # Remove any config directories
    sudo rm -rf ~/.telegram-bot-api 2>/dev/null || true
    sudo rm -rf /etc/telegram-bot-api 2>/dev/null || true
fi

echo "✅ Cleanup completed"

# --- Final Status ---
echo ""
echo "🎉 Uninstallation completed successfully!"
echo "========================================"

if [ "$REMOVE_BOT" = true ] && [ "$REMOVE_API" = true ]; then
    echo -e "${GREEN}✅ Complete removal: Both Bot and API Server${NC}"
elif [ "$REMOVE_BOT" = true ]; then
    echo -e "${GREEN}✅ Telegram Download Bot removed${NC}"
    if [ "$API_SERVICE_EXISTS" = true ]; then
        echo -e "${BLUE}ℹ️  Local API Server is still installed and running${NC}"
    fi
elif [ "$REMOVE_API" = true ]; then
    echo -e "${GREEN}✅ Local API Server removed${NC}"
    if [ "$BOT_SERVICE_EXISTS" = true ]; then
        echo -e "${BLUE}ℹ️  Telegram Download Bot is still installed${NC}"
        echo -e "${YELLOW}⚠️  Bot may need reconfiguration to use official API${NC}"
    fi
fi

echo ""
echo "📋 What was removed:"
if [ "$REMOVE_BOT" = true ]; then
    echo "🤖 Bot components:"
    echo "   • Service: telegram-download-bot.service"
    echo "   • Directory: /opt/Telegram-File-Link-Download-Bot"
    echo "   • Python virtual environment and dependencies"
fi

if [ "$REMOVE_API" = true ]; then
    echo "⚡ API Server components:"
    echo "   • Service: telegram-bot-api.service"
    echo "   • Binary: /usr/local/bin/telegram-bot-api"
    echo "   • Source: /opt/telegram-bot-api"
    echo "   • Build dependencies (kept for other uses)"
fi

echo ""
echo "💡 Note: System packages (python3, git, etc.) were not removed"
echo "    as they might be used by other applications."

if [ "$REMOVE_BOT" = true ] && [ "$REMOVE_API" = false ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Important: If you reinstall the bot, you may need to:${NC}"
    echo "   • Use official Telegram API (https://api.telegram.org/bot)"
    echo "   • Or reconfigure to use your existing local API server"
fi

echo ""
echo "🚀 Uninstallation script completed!"
