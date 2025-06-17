"""
Configuration settings for the AI Search Tool server.
"""

import os
from pathlib import Path

# Base directory for the server
SERVER_DIR = Path(__file__).parent
PROJECT_ROOT = SERVER_DIR.parent

# Storage paths - Base directory
STORAGE_DIR = SERVER_DIR / "storage"

# These will be set dynamically based on current database
DATABASE_PATH = None
CHROMA_DB_DIR = None
DOCUMENTS_DIR = None
PDFS_DIR = None
PDF_THUMBNAILS_DIR = None
DOCUMENT_IDS_PATH = None

def set_database_paths(database_id: str):
    """Set paths for a specific database."""
    global DATABASE_PATH, CHROMA_DB_DIR, DOCUMENTS_DIR, PDFS_DIR, PDF_THUMBNAILS_DIR, DOCUMENT_IDS_PATH
    
    db_dir = STORAGE_DIR / database_id
    DATABASE_PATH = db_dir / "documents.db"
    CHROMA_DB_DIR = db_dir / "chroma_db"
    DOCUMENTS_DIR = db_dir / "documents"
    PDFS_DIR = db_dir / "pdfs"
    PDF_THUMBNAILS_DIR = db_dir / "pdf_thumbnails"
    DOCUMENT_IDS_PATH = db_dir / "document_ids.json"
    
    # Create directories if they don't exist
    for directory in [db_dir, DOCUMENTS_DIR, PDFS_DIR, PDF_THUMBNAILS_DIR]:
        directory.mkdir(parents=True, exist_ok=True)

# Log file
LOG_FILE = SERVER_DIR / "api_server.log"

# Server settings
DEFAULT_API_PORT = int(os.getenv("API_PORT", "8010"))
DEFAULT_WEB_PORT = int(os.getenv("WEB_PORT", "8080"))

# Model settings
MODEL_NAME = os.getenv("SENTENCE_TRANSFORMER_MODEL", "all-MiniLM-L6-v2")
EMBEDDING_DIM = 384

# Create base storage directory
STORAGE_DIR.mkdir(parents=True, exist_ok=True)

# Claude API settings (optional)
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")

# Offline mode
HF_HUB_OFFLINE = os.getenv("HF_HUB_OFFLINE", "0") == "1"