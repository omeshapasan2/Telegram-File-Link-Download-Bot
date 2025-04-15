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
# Import necessary libraries for GoFile downloader
from concurrent.futures import ThreadPoolExecutor
from threading import Lock
from platform import system
from hashlib import sha256
from sys import exit, stdout, stderr

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

# GoFile downloader constants
NEW_LINE = "\n" if system() != "Windows" else "\r\n"

class UploadState:
    def __init__(self):
        self.is_uploading = False
        self.should_stop = False

# GoFile downloader helper functions
def _print(msg: str, error: bool = False) -> None:
    """Print a message."""
    output = stderr if error else stdout
    output.write(msg)
    output.flush()

def die(msg: str):
    """Display a message of error and exit."""
    _print(f"{msg}{NEW_LINE}", True)
    exit(-1)

# GoFile downloader class
class GoFileDownloader:
    def __init__(self, url: str, password: str | None = None, max_workers: int = 5, output_dir: str = None) -> None:
        self._root_dir = output_dir if output_dir else os.getcwd()
        self._lock = Lock()
        self._max_workers = max_workers
        token = os.getenv("GF_TOKEN")
        self._message = " "
        self._content_dir = None
        self._files_info = {}
        self._token = token if token else self._get_token()
        self._download_progress = {}
        
    def _threaded_downloads(self) -> None:
        """Parallelize the downloads."""
        if not self._content_dir:
            _print(f"Content directory wasn't created, nothing done.{NEW_LINE}")
            return

        os.chdir(self._content_dir)

        with ThreadPoolExecutor(max_workers=self._max_workers) as executor:
            for item in self._files_info.values():
                executor.submit(self._download_content, item)

        os.chdir(self._root_dir)

    def _create_dir(self, dirname: str) -> None:
        """Creates a directory where the files will be saved if it doesn't exist."""
        try:
            os.mkdir(dirname)
        except FileExistsError:
            pass

    @staticmethod
    def _get_token() -> str:
        """Gets the access token of account created."""
        user_agent = os.getenv("GF_USERAGENT")
        headers = {
            "User-Agent": user_agent if user_agent else "Mozilla/5.0",
            "Accept-Encoding": "gzip, deflate, br",
            "Accept": "*/*",
            "Connection": "keep-alive",
        }

        create_account_response = requests.post("https://api.gofile.io/accounts", headers=headers).json()

        if create_account_response["status"] != "ok":
            die("Account creation failed!")

        return create_account_response["data"]["token"]

    def _download_content(self, file_info: dict[str, str], chunk_size: int = 16384) -> None:
        """Requests the contents of the file and writes it."""
        filepath = os.path.join(file_info["path"], file_info["filename"])
        if os.path.exists(filepath):
            if os.path.getsize(filepath) > 0:
                _print(f"{filepath} already exist, skipping.{NEW_LINE}")
                return

        tmp_file = f"{filepath}.part"
        url = file_info["link"]
        user_agent = os.getenv("GF_USERAGENT")

        headers = {
            "Cookie": f"accountToken={self._token}",
            "Accept-Encoding": "gzip, deflate, br",
            "User-Agent": user_agent if user_agent else "Mozilla/5.0",
            "Accept": "*/*",
            "Referer": f"{url}{('/' if not url.endswith('/') else '')}",
            "Origin": url,
            "Connection": "keep-alive",
            "Sec-Fetch-Dest": "empty",
            "Sec-Fetch-Mode": "cors",
            "Sec-Fetch-Site": "same-site",
            "Pragma": "no-cache",
            "Cache-Control": "no-cache"
        }

        # Check for partial download and resume from last byte
        part_size = 0
        if os.path.isfile(tmp_file):
            part_size = int(os.path.getsize(tmp_file))
            headers["Range"] = f"bytes={part_size}-"

        has_size = None
        status_code = None

        try:
            with requests.get(url, headers=headers, stream=True, timeout=(9, 27)) as response_handler:
                status_code = response_handler.status_code

                if ((response_handler.status_code in (403, 404, 405, 500)) or
                    (part_size == 0 and response_handler.status_code != 200) or
                    (part_size > 0 and response_handler.status_code != 206)):
                    _print(
                        f"Couldn't download the file from {url}."
                        f"{NEW_LINE}"
                        f"Status code: {status_code}"
                        f"{NEW_LINE}"
                    )
                    return

                content_length = response_handler.headers.get("Content-Length")
                content_range = response_handler.headers.get("Content-Range")
                has_size = content_length if part_size == 0 \
                    else content_range.split("/")[-1] if content_range else None

                if not has_size:
                    _print(
                        f"Couldn't find the file size from {url}."
                        f"{NEW_LINE}"
                        f"Status code: {status_code}"
                        f"{NEW_LINE}"
                    )
                    return

                with open(tmp_file, "ab") as handler:
                    total_size = float(has_size)

                    start_time = time.perf_counter()
                    for i, chunk in enumerate(response_handler.iter_content(chunk_size=chunk_size)):
                        progress = (part_size + (i * len(chunk))) / total_size * 100
                        
                        # Update progress for tracking
                        self._download_progress[file_info["filename"]] = {
                            "current": part_size + (i * len(chunk)),
                            "total": int(has_size),
                            "progress": round(progress, 1)
                        }
                        
                        handler.write(chunk)

                        rate = (i * len(chunk)) / (time.perf_counter()-start_time)
                        unit = "B/s"
                        if rate < (1024):
                            unit = "B/s"
                        elif rate < (1024*1024):
                            rate /= 1024
                            unit = "KB/s"
                        elif rate < (1024*1024*1024):
                            rate /= (1024 * 1024)
                            unit = "MB/s"
                        elif rate < (1024*1024*1024*1024):
                            rate /= (1024 * 1024 * 1024)
                            unit = "GB/s"

                        # Thread safe update the self._message
                        with self._lock:
                            _print(f"\r{' ' * len(self._message)}")
                            self._message = f"\rDownloading {file_info['filename']}: {part_size + i * len(chunk)}" \
                            f" of {has_size} {round(progress, 1)}% {round(rate, 1)}{unit}"
                            _print(self._message)
        finally:
            with self._lock:
                if has_size and os.path.getsize(tmp_file) == int(has_size):
                    _print(f"\r{' ' * len(self._message)}")
                    _print(f"\rDownloading {file_info['filename']}: "
                        f"{os.path.getsize(tmp_file)} of {has_size} Done!"
                        f"{NEW_LINE}"
                    )
                    move(tmp_file, filepath)

    def _parse_links_recursively(
        self,
        content_id: str,
        password: str | None = None,
        pathing_count: dict[str, int] = {},
        recursive_files_index: dict[str, int] = {"index": 0}
    ) -> None:
        """Parses for possible links recursively and populate a list with file's info."""
        url = f"https://api.gofile.io/contents/{content_id}?wt=4fd6sg89d7s6&cache=true&sortField=createTime&sortDirection=1"

        if password:
            url = f"{url}&password={password}"

        user_agent = os.getenv("GF_USERAGENT")

        headers = {
            "User-Agent": user_agent if user_agent else "Mozilla/5.0",
            "Accept-Encoding": "gzip, deflate, br",
            "Accept": "*/*",
            "Connection": "keep-alive",
            "Authorization": f"Bearer {self._token}",
        }

        response = requests.get(url, headers=headers).json()

        if response["status"] != "ok":
            _print(f"Failed to get a link as response from the {url}.{NEW_LINE}")
            return

        data = response["data"]

        if "password" in data and "passwordStatus" in data and data["passwordStatus"] != "passwordOk":
            _print(f"Password protected link. Please provide the password.{NEW_LINE}")
            return

        if data["type"] != "folder":
            current_dir = os.getcwd()
            filename = data["name"]
            recursive_files_index["index"] += 1
            filepath = os.path.join(current_dir, filename)

            if filepath in pathing_count:
                pathing_count[filepath] += 1
            else:
                pathing_count[filepath] = 0

            if pathing_count and pathing_count[filepath] > 0:
                extension = ""
                filename, extension = os.path.splitext(filename)
                filename = f"{filename}({pathing_count[filepath]}){extension}"

            self._files_info[str(recursive_files_index["index"])] = {
                "path": current_dir,
                "filename": filename,
                "link": data["link"]
            }

            return

        # Do not use the default root directory named "root"
        folder_name = data["name"]

        if not self._content_dir and folder_name != content_id:
            self._content_dir = os.path.join(self._root_dir, content_id)
            self._create_dir(self._content_dir)
            os.chdir(self._content_dir)
        elif not self._content_dir and folder_name == content_id:
            self._content_dir = os.path.join(self._root_dir, content_id)
            self._create_dir(self._content_dir)

        # Only create subdirectories after the content directory is already created
        absolute_path = os.path.join(os.getcwd(), folder_name)

        if absolute_path in pathing_count:
            pathing_count[absolute_path] += 1
        else:
            pathing_count[absolute_path] = 0

        if pathing_count and pathing_count[absolute_path] > 0:
            absolute_path = f"{absolute_path}({pathing_count[absolute_path]})"

        self._create_dir(absolute_path)
        os.chdir(absolute_path)

        for child_id in data["children"]:
            child = data["children"][child_id]

            if child["type"] == "folder":
                self._parse_links_recursively(child["id"], password, pathing_count, recursive_files_index)
            else:
                current_dir = os.getcwd()
                filename = child["name"]
                recursive_files_index["index"] += 1
                filepath = os.path.join(current_dir, filename)

                if filepath in pathing_count:
                    pathing_count[filepath] += 1
                else:
                    pathing_count[filepath] = 0

                if pathing_count and pathing_count[filepath] > 0:
                    extension = ""
                    filename, extension = os.path.splitext(filename)
                    filename = f"{filename}({pathing_count[filepath]}){extension}"

                self._files_info[str(recursive_files_index["index"])] = {
                    "path": current_dir,
                    "filename": filename,
                    "link": child["link"]
                }

        os.chdir(os.path.pardir)

    def download(self, url: str, password: str | None = None) -> dict:
        """Main function to start the download process."""
        try:
            if not url.split("/")[-2] == "d":
                return {"status": "error", "message": f"The url probably doesn't have an id in it: {url}"}

            content_id = url.split("/")[-1]
        except IndexError:
            return {"status": "error", "message": f"{url} doesn't seem a valid url."}

        _password = sha256(password.encode()).hexdigest() if password else password

        self._parse_links_recursively(content_id, _password)

        # Probably the link is broken so the content dir wasn't even created
        if not self._content_dir:
            return {"status": "error", "message": f"No content directory created for url: {url}, nothing done."}

        # Removes the root content directory if there's no file or subdirectory
        if not os.listdir(self._content_dir) and not self._files_info:
            os.rmdir(self._content_dir)
            return {"status": "error", "message": f"Empty directory for url: {url}, nothing done."}

        self._threaded_downloads()
        
        # Return successful result with downloaded files
        result = {
            "status": "success", 
            "content_dir": self._content_dir,
            "files": list(self._files_info.values())
        }
        
        return result

# Add GoFile downloader command handler
async def gofile_download(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """
    Handle GoFile downloads via the /gofile command.
    Expected format: /gofile URL [PASSWORD]
    """
    if not context.args:
        await update.message.reply_text("Please provide a GoFile URL (and optionally a password).")
        return
    
    url = context.args[0]
    password = context.args[1] if len(context.args) > 1 else None
    
    # Send initial message
    progress_message = await update.message.reply_text(f"Starting download from GoFile: {url}")
    
    # Run the GoFile downloader in a separate thread to avoid blocking the bot
    try:
        # Create a new executor for this task
        with ThreadPoolExecutor() as executor:
            # Run the download in a separate thread
            download_future = executor.submit(
                lambda: GoFileDownloader(url=None, output_dir=OUTPUT_DIR).download(url, password)
            )
            
            # Check progress and update message periodically
            while not download_future.done():
                await asyncio.sleep(5)  # Check every 5 seconds
                
                # You could add more detailed progress updates here
                await progress_message.edit_text(f"Downloading from GoFile: {url}...\nThis may take a while.")
            
            # Get the result
            result = download_future.result()
            
            if result["status"] == "success":
                downloaded_files = len(result["files"])
                content_dir = result["content_dir"]
                
                await progress_message.edit_text(
                    f"Download complete!\nDownloaded {downloaded_files} files\nLocation: {content_dir}"
                )
            else:
                await progress_message.edit_text(f"Failed to download: {result['message']}")
                
    except Exception as e:
        await progress_message.edit_text(f"Error downloading from GoFile: {str(e)}")

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
    
    # Add the new GoFile downloader command
    application.add_handler(CommandHandler("gofile", gofile_download))
    
    # Message handlers
    application.add_handler(MessageHandler(filters.Document.ALL, downloader))

    application.run_polling()

if __name__ == "__main__":
    main()