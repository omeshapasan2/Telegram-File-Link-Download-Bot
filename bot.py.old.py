import logging
import os
import requests
import time
from shutil import move
from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes, MessageHandler, filters

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO
)
logger = logging.getLogger(__name__)

TOKEN = "7037133664:AAHa0UxzgSA_dIR-5q60GnIe-HRgQ5bPOkk"
BASE_URL = "http://localhost:8081/bot"
OUTPUT_DIR = "/DATA/Media/TGdownloads/"
EMBY_SERVER_URL = "http://144.91.114.217:8096"
EMBY_API_KEY = "c98274b854fa40af95d53908c8c86a1b"

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    user = update.effective_user
    await update.message.reply_html(
        rf"Halo {user.mention_html()}!"
    )

async def set_output_dir(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    global OUTPUT_DIR
    new_dir = ' '.join(context.args).strip()
    if not os.path.exists(new_dir):
        os.makedirs(new_dir)
    OUTPUT_DIR = new_dir
    await update.message.reply_text(f"Output directory set to: {OUTPUT_DIR}")

async def download_progress(current, total, start_time, update, context, document):
    percentage = (current / total) * 100
    elapsed_time = time.time() - start_time
    download_speed = current / elapsed_time
    estimated_total_time = total / download_speed
    estimated_time_remaining = estimated_total_time - elapsed_time

    progress_message = (f"Downloading: {document.file_name}\n"
                        f"Progress: {percentage:.2f}%\n"
                        f"Speed: {download_speed / 1024:.2f} KB/s\n"
                        f"Time remaining: {estimated_time_remaining:.2f} s")
    
    await context.bot.send_message(
        chat_id=update.message.chat_id,
        text=progress_message
    )

async def downloader(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    document = update.message.document
    await update.message.reply_text(f"Downloading {document.file_name}!")

    file = await context.bot.get_file(document.file_id)
    temp_file_path = f"/tmp/{document.file_name}"
    start_time = time.time()

    with open(temp_file_path, 'wb') as f:
        current = 0
        total = file.file_size
        for chunk in file.download_as_bytearray(chunk_size=1024):
            if chunk:
                f.write(chunk)
                current += len(chunk)
                await download_progress(current, total, start_time, update, context, document)

    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    try:
        move(temp_file_path, f"{OUTPUT_DIR}/{document.file_name}")
        await update.message.reply_text(f"《Done》\n\nFile Location: {OUTPUT_DIR}/{document.file_name}")
    except Exception as e:
        await update.message.reply_text(f"Failed to move file: {str(e)}")

async def scan_all_libraries(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    url = f"{EMBY_SERVER_URL}/emby/Library/Sections"
    headers = {
        "X-Emby-Token": EMBY_API_KEY
    }

    response = requests.get(url, headers=headers)
    messages = []

    if response.status_code == 200:
        libraries = response.json()
        for library in libraries["Items"]:
            library_id = library["Id"]
            scan_url = f"{EMBY_SERVER_URL}/emby/Library/Sections/{library_id}/Refresh"
            scan_response = requests.post(scan_url, headers=headers)
            if scan_response.status_code == 200:
                messages.append(f"Scanning library {library['Name']} (ID: {library_id}) successful.")
            else:
                messages.append(f"Failed to scan library {library['Name']} (ID: {library_id})")

        all_messages = "\n".join(messages)
        await update.message.reply_text("Library scanning results:\n" + all_messages)
        await update.message.reply_text("Library scanning completed.")
    else:
        await update.message.reply_text(f"Failed to retrieve libraries. Status code: {response.status_code}")
        await update.message.reply_text(response.json())

def main() -> None:
    application = Application.builder().token(TOKEN).base_url(BASE_URL).base_file_url("").read_timeout(864000).build()
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("setoutputdir", set_output_dir))
    application.add_handler(CommandHandler("scanalllibraries", scan_all_libraries))
    application.add_handler(MessageHandler(filters.Document.ALL, downloader))
    application.run_polling()

if __name__ == "__main__":
    main()