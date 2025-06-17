"""
Configuration settings for the AI Search Tool server.
"""

import os
from pathlib import Path

# Base directory for the server
SERVER_DIR = Path(__file__).parent
PROJECT_ROOT = SERVER_DIR.parent

# Storage paths
STORAGE_DIR = SERVER_DIR / "storage"
DATABASE_PATH = STORAGE_DIR / "documents.db"
CHROMA_DB_DIR = STORAGE_DIR / "chroma_db"
DOCUMENTS_DIR = STORAGE_DIR / "documents"
PDFS_DIR = STORAGE_DIR / "pdfs"
PDF_THUMBNAILS_DIR = STORAGE_DIR / "pdf_thumbnails"
DOCUMENT_IDS_PATH = STORAGE_DIR / "document_ids.json"

# Log file
LOG_FILE = SERVER_DIR / "api_server.log"

# Server settings
DEFAULT_API_PORT = int(os.getenv("API_PORT", "8010"))
DEFAULT_WEB_PORT = int(os.getenv("WEB_PORT", "8080"))

# Model settings
MODEL_NAME = os.getenv("SENTENCE_TRANSFORMER_MODEL", "all-MiniLM-L6-v2")
EMBEDDING_DIM = 384

# Create directories if they don't exist
for directory in [STORAGE_DIR, DOCUMENTS_DIR, PDFS_DIR, PDF_THUMBNAILS_DIR]:
    directory.mkdir(parents=True, exist_ok=True)

# Database URL
DATABASE_URL = f"sqlite:///{DATABASE_PATH}"

# Claude API settings (optional)
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")

# Offline mode
HF_HUB_OFFLINE = os.getenv("HF_HUB_OFFLINE", "0") == "1"