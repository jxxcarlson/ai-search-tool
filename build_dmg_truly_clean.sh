#!/bin/bash

# AI Search Tool DMG Builder - Truly Clean Version
# Creates a DMG without any storage directory in the app bundle

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

print_status() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# First, build the regular DMG if it doesn't exist
if [ ! -f "dist/AI-Search-Tool-1.0.0.dmg" ]; then
    print_status "Building base DMG first..."
    ./build_dmg.sh
fi

print_status "Creating truly clean DMG..."

# Create temporary directories
MOUNT_POINT="/tmp/ai-search-tool-dmg-$$"
TEMP_DIR="/tmp/ai-search-tool-clean-$$"
mkdir -p "$MOUNT_POINT"
mkdir -p "$TEMP_DIR"

# Mount the existing DMG
print_status "Mounting existing DMG..."
hdiutil attach "dist/AI-Search-Tool-1.0.0.dmg" -mountpoint "$MOUNT_POINT" -nobrowse -quiet

# Copy the app bundle
print_status "Copying app bundle..."
cp -R "$MOUNT_POINT/AI Search Tool.app" "$TEMP_DIR/"

# Unmount the original DMG
hdiutil detach "$MOUNT_POINT" -quiet

# Remove ALL storage from the app bundle
APP_DIR="$TEMP_DIR/AI Search Tool.app/Contents/Resources/app"
print_status "Removing storage directory from app bundle..."
rm -rf "$APP_DIR/server/storage"

# Create a modified launch script that initializes empty database on first run
print_status "Creating modified launch script..."
cat > "$TEMP_DIR/AI Search Tool.app/Contents/MacOS/ai-search-tool" << 'EOF'
#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RESOURCES_DIR="${SCRIPT_DIR}/../Resources"
APP_DIR="${RESOURCES_DIR}/app"

# Set up environment
export PATH="${RESOURCES_DIR}/venv/bin:$PATH"
export PYTHONPATH="${APP_DIR}:$PYTHONPATH"

# Create user data directory if it doesn't exist
USER_DATA_DIR="${HOME}/Library/Application Support/AI Search Tool"
mkdir -p "${USER_DATA_DIR}"

# Check if this is first run (no storage directory exists)
if [ ! -d "${USER_DATA_DIR}/storage" ]; then
    echo "First run detected. Creating empty database..."
    
    # Create storage structure
    mkdir -p "${USER_DATA_DIR}/storage/default"
    mkdir -p "${USER_DATA_DIR}/storage/default/chroma_db"
    mkdir -p "${USER_DATA_DIR}/storage/default/documents"
    mkdir -p "${USER_DATA_DIR}/storage/default/pdfs"
    mkdir -p "${USER_DATA_DIR}/storage/default/pdf_thumbnails"
    
    # Create empty database registry
    cat > "${USER_DATA_DIR}/storage/database_registry.json" << 'REGISTRY'
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
REGISTRY
    
    # Initialize empty SQLite database
    cd "${APP_DIR}"
    "${RESOURCES_DIR}/venv/bin/python" << 'INITDB'
import sqlite3
import os

db_path = os.path.expanduser("~/Library/Application Support/AI Search Tool/storage/default/documents.db")
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
INITDB
    
    # Mark as initialized
    touch "${USER_DATA_DIR}/.initialized"
fi

# Create symbolic link to user data in app directory
rm -rf "${APP_DIR}/server/storage"
ln -sf "${USER_DATA_DIR}/storage" "${APP_DIR}/server/storage"

# Log file location
LOG_DIR="${USER_DATA_DIR}/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/ai-search-tool.log"

# Function to cleanup on exit
cleanup() {
    # Kill the API server
    if [ ! -z "$API_PID" ]; then
        kill $API_PID 2>/dev/null
    fi
    # Kill the web server  
    if [ ! -z "$WEB_PID" ]; then
        kill $WEB_PID 2>/dev/null
    fi
    exit 0
}

# Set trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Start the servers
cd "${APP_DIR}"

# Activate virtual environment
source "${RESOURCES_DIR}/venv/bin/activate"

# Start API server
echo "Starting API server..." >> "${LOG_FILE}"
cd server && python server.py 8010 >> "${LOG_FILE}" 2>&1 &
API_PID=$!
cd ..

# Wait for API server to start
sleep 3

# Start web server
echo "Starting web server..." >> "${LOG_FILE}"
cd elm-app && python -m http.server 8080 >> "${LOG_FILE}" 2>&1 &
WEB_PID=$!
cd ..

# Wait a moment for servers to start
sleep 2

# Open browser
open "http://localhost:8080"

# Keep the script running
while true; do
    # Check if processes are still running
    if ! kill -0 $API_PID 2>/dev/null; then
        echo "API server stopped unexpectedly" >> "${LOG_FILE}"
        break
    fi
    if ! kill -0 $WEB_PID 2>/dev/null; then
        echo "Web server stopped unexpectedly" >> "${LOG_FILE}"
        break
    fi
    sleep 5
done
EOF

# Make launch script executable
chmod +x "$TEMP_DIR/AI Search Tool.app/Contents/MacOS/ai-search-tool"

# Create a symbolic link to Applications
ln -s /Applications "$TEMP_DIR/Applications"

# Create the clean DMG
print_status "Creating clean DMG..."
mkdir -p dist
hdiutil create -volname "AI Search Tool" \
    -srcfolder "$TEMP_DIR" \
    -ov -format UDZO \
    "dist/${DMG_NAME}.dmg"

# Clean up
rm -rf "$TEMP_DIR"
rmdir "$MOUNT_POINT" 2>/dev/null || true

print_success "Clean DMG created at: dist/${DMG_NAME}.dmg"
echo
echo "This DMG will:"
echo "- Create an empty database on first run"
echo "- Preserve existing data for users who already have the app installed"
echo "- Not include any pre-existing documents or data"