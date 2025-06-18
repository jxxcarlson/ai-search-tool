#!/bin/bash

# AI Search Tool DMG Builder - Clean Database Version
# Creates a DMG with an empty database

set -e  # Exit on error

# Configuration
APP_NAME="AI Search Tool"
APP_VERSION="1.0.0"
BUNDLE_ID="com.aisearchtool.app"
DMG_NAME="AI-Search-Tool-${APP_VERSION}-clean"
BUILD_DIR="build"
DIST_DIR="dist"
APP_BUNDLE="${APP_NAME}.app"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Source the main build functions
source "$(dirname "$0")/build_dmg.sh" --source-only 2>/dev/null || {
    print_error "Could not source build_dmg.sh. Make sure it exists."
    exit 1
}

# Override copy_app_files to ensure clean database
copy_app_files_clean() {
    print_status "Copying application files (with clean database)..."
    
    # Create app directory in Resources
    APP_RESOURCES="${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources/app"
    mkdir -p "${APP_RESOURCES}"
    
    # Copy server files
    print_status "Copying server files..."
    cp -r server "${APP_RESOURCES}/"
    
    # Copy elm-app files
    print_status "Copying frontend files..."
    cp -r elm-app "${APP_RESOURCES}/"
    
    # Copy other necessary files
    cp requirements.txt "${APP_RESOURCES}/"
    cp -r inbox "${APP_RESOURCES}/" 2>/dev/null || true
    cp sample_documents.json "${APP_RESOURCES}/" 2>/dev/null || true
    
    # Remove any existing storage directory to ensure clean state
    rm -rf "${APP_RESOURCES}/server/storage"
    
    # Create empty storage structure
    print_status "Creating empty database structure..."
    mkdir -p "${APP_RESOURCES}/server/storage/default"
    mkdir -p "${APP_RESOURCES}/server/storage/default/chroma_db"
    mkdir -p "${APP_RESOURCES}/server/storage/default/documents"
    mkdir -p "${APP_RESOURCES}/server/storage/default/pdfs"
    mkdir -p "${APP_RESOURCES}/server/storage/default/pdf_thumbnails"
    
    # Create empty database registry
    cat > "${APP_RESOURCES}/server/storage/database_registry.json" << 'EOF'
{
    "databases": {
        "default": {
            "id": "default",
            "name": "Default Database",
            "description": "Default database",
            "created_at": "2024-01-01T00:00:00",
            "document_count": 0
        }
    },
    "current_database": "default"
}
EOF
    
    # Initialize empty SQLite database
    print_status "Initializing empty SQLite database..."
    python3 << 'EOF'
import sqlite3
import os

db_path = "build/AI Search Tool.app/Contents/Resources/app/server/storage/default/documents.db"
os.makedirs(os.path.dirname(db_path), exist_ok=True)

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Create documents table
cursor.execute('''
    CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        doc_type TEXT NOT NULL,
        category TEXT,
        tags TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
''')

# Create embeddings table
cursor.execute('''
    CREATE TABLE IF NOT EXISTS embeddings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id TEXT NOT NULL,
        chunk_index INTEGER NOT NULL,
        chunk_text TEXT NOT NULL,
        embedding BLOB NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
    )
''')

# Create indices
cursor.execute('CREATE INDEX IF NOT EXISTS idx_embeddings_document_id ON embeddings(document_id)')
cursor.execute('CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents(created_at)')

conn.commit()
conn.close()

print("Empty database initialized successfully")
EOF
    
    # Remove development files
    find "${APP_RESOURCES}" -name "*.pyc" -delete
    find "${APP_RESOURCES}" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find "${APP_RESOURCES}" -name ".DS_Store" -delete
    
    print_success "Application files copied with clean database"
}

# Main build process for clean DMG
main_clean() {
    echo -e "${BLUE}Building ${APP_NAME} DMG Installer (Clean Database)${NC}"
    echo "=================================================="
    
    check_prerequisites
    clean_build
    build_elm
    create_bundle_structure
    create_info_plist
    create_launch_script
    copy_app_files_clean  # Use our clean version
    create_virtualenv
    create_icon
    create_dmg
    
    # Rename the DMG to indicate it's clean
    if [ -f "${DIST_DIR}/AI-Search-Tool-${APP_VERSION}.dmg" ]; then
        mv "${DIST_DIR}/AI-Search-Tool-${APP_VERSION}.dmg" "${DIST_DIR}/${DMG_NAME}.dmg"
    fi
    
    echo
    echo -e "${GREEN}Build complete!${NC}"
    echo -e "${GREEN}Clean DMG installer created at: ${DIST_DIR}/${DMG_NAME}.dmg${NC}"
    echo
    echo "This DMG contains an empty database - perfect for new installations!"
    echo
    echo "To install:"
    echo "1. Open the DMG file"
    echo "2. Drag 'AI Search Tool' to the Applications folder"
    echo "3. Launch from Applications"
}

# Run main function
main_clean