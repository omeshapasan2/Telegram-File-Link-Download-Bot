import logging
import os
import requests
import asyncio
import time
from pathlib import Path
from shutil import move
from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes, MessageHandler, filters
import humanize
from dotenv import load_dotenv

load_dotenv()

# Logging configuration
logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Configuration constants - load from environment variables
TOKEN = os.getenv("TELEGRAM_TOKEN")
BASE_URL = os.getenv("BASE_URL", "http://localhost:8081/bot")
OUTPUT_DIR = "/DATA/Media/"
UPDATE_INTERVAL = 3

# Track processed files and upload states
processed_files = set()
upload_states = {}

class UploadState:
    def __init__(self):
        self.is_uploading = False
        self.should_stop = False

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle the /start command - welcome the user."""
    user = update.effective_user
    await update.message.reply_html(
        rf"Halo {user.mention_html()}!"
    )

async def set_output_dir(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle the /setoutputdir command - change the download directory."""
    global OUTPUT_DIR
    new_dir = ' '.join(context.args).strip()
    if not os.path.exists(new_dir):
        os.makedirs(new_dir)
    OUTPUT_DIR = new_dir
    await update.message.reply_text(f"Output directory set to: {OUTPUT_DIR}")

async def downloader(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """
    Handle file downloads from Telegram.
    Downloads files sent to the bot and saves them to the specified directory.
    """
    document = update.message.document
    
    # Send initial message
    await update.message.reply_text(f"Downloading!!! \n\n {document.file_name} ")

    # Get file from Telegram
    file = await context.bot.get_file(document.file_id)

    # Download to temporary location
    temp_file_path = f"/tmp/{document.file_name}"
    
    # Use download_to_drive method instead of download
    await file.download_to_drive(custom_path=temp_file_path)

    # Ensure output directory exists
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    # Move file to final location
    try:
        move(temp_file_path, f"{OUTPUT_DIR}/{document.file_name}")
        await update.message.reply_text(
            f">••Done••< \n\n\n ■ File Location: {OUTPUT_DIR}/{document.file_name}\n"
        )
    except Exception as e:
        await update.message.reply_text(f"Failed to move file: {str(e)}")

async def download_from_link(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle URL downloads with progress tracking."""
    if not context.args:
        await update.message.reply_text("Please provide a direct download link.")
        return

    download_url = ' '.join(context.args).strip()
    file_name = download_url.split("/")[-1]

    progress_message = await update.message.reply_text(f"Starting download from: {download_url}")

    try:
        if not os.path.exists(OUTPUT_DIR):
            os.makedirs(OUTPUT_DIR)

        response = requests.get(download_url, stream=True)
        response.raise_for_status()
        total_size = int(response.headers.get('content-length', 0))
        
        file_path = os.path.join(OUTPUT_DIR, file_name)
        downloaded = 0

        with open(file_path, "wb") as file:
            for chunk in response.iter_content(chunk_size=8192):
                file.write(chunk)
                downloaded += len(chunk)
                if downloaded % (1024 * 1024) == 0:  # Update every 1MB
                    await progress_message.edit_text(
                        f"Downloading: {file_name}\nProgress: {humanize.naturalsize(downloaded)} / {humanize.naturalsize(total_size)}"
                    )

        await progress_message.edit_text(
            f"Download complete!\nFile: {file_name}\nSize: {humanize.naturalsize(total_size)}\nLocation: {file_path}"
        )
    except Exception as e:
        await progress_message.edit_text(f"Failed to download file: {str(e)}")

async def stop_upload(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle the /stopupload command to stop ongoing uploads."""
    chat_id = update.effective_chat.id

    if chat_id in upload_states and upload_states[chat_id].is_uploading:
        upload_states[chat_id].should_stop = True
        await update.message.reply_text("Stopping upload after current file completes...")
    else:
        await update.message.reply_text("No active upload to stop.")

async def upload_from_directory(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Upload files from a specified directory to Telegram with the ability to stop."""
    chat_id = update.effective_chat.id

    if chat_id in upload_states and upload_states[chat_id].is_uploading:
        await update.message.reply_text("An upload is already in progress. Use /stopupload to stop it.")
        return

    if not context.args:
        await update.message.reply_text("Please provide a directory path.")
        return

    upload_dir = ' '.join(context.args).strip()
    if not os.path.exists(upload_dir):
        await update.message.reply_text(f"Directory not found: {upload_dir}")
        return

    upload_states[chat_id] = UploadState()
    upload_states[chat_id].is_uploading = True

    try:
        directory = Path(upload_dir)
        files = [f for f in directory.glob('*') if f.is_file() and f not in processed_files]

        if not files:
            await update.message.reply_text("No new files found in the directory.")
            return

        total_size = sum(f.stat().st_size for f in files)
        current_size = 0
        start_time = time.time()

        status_message = await update.message.reply_text(
            f"Starting upload from: {upload_dir}\nFiles to process: {len(files)}\nTotal size: {humanize.naturalsize(total_size)}"
        )

        for index, file_path in enumerate(files, 1):
            if upload_states[chat_id].should_stop:
                await status_message.edit_text(
                    f"Upload stopped!\nFiles uploaded: {index - 1}/{len(files)}\nSize uploaded: {humanize.naturalsize(current_size)}/{humanize.naturalsize(total_size)}"
                )
                break

            file_size = file_path.stat().st_size
            with open(file_path, 'rb') as file:
                await update.message.reply_document(
                    document=file,
                    filename=file_path.name,
                    caption=f"{file_path.name}"
                )

            processed_files.add(file_path)
            current_size += file_size
            await asyncio.sleep(2)

        if not upload_states[chat_id].should_stop:
            total_time = time.time() - start_time
            await status_message.edit_text(
                f"Upload completed!\nTotal files: {len(files)}\nTotal size: {humanize.naturalsize(total_size)}\nTime taken: {humanize.naturaldelta(total_time)}\nAverage speed: {humanize.naturalsize(total_size / total_time)}/s"
            )

    finally:
        upload_states[chat_id].is_uploading = False
        upload_states[chat_id].should_stop = False

def main() -> None:
    """Initialize and start the bot with all command handlers."""
    # Verify that TOKEN is present
    if not TOKEN:
        logger.error("No TELEGRAM_TOKEN environment variable set!")
        exit(1)
        
    application = Application.builder().token(TOKEN).base_url(BASE_URL).base_file_url("").read_timeout(864000).build()

    # Command handlers
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("setoutputdir", set_output_dir))
    application.add_handler(CommandHandler("download", download_from_link))
    application.add_handler(CommandHandler("upload", upload_from_directory))
    application.add_handler(CommandHandler("stopupload", stop_upload))
    
    # Message handlers
    application.add_handler(MessageHandler(filters.Document.ALL, downloader))

    application.run_polling()

if __name__ == "__main__":
    main()
