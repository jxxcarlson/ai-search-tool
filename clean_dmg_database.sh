#!/bin/bash

# Quick script to clean the database in an existing DMG build

set -e

DMG_PATH="dist/AI-Search-Tool-1.0.0.dmg"
CLEAN_DMG_PATH="dist/AI-Search-Tool-1.0.0-clean.dmg"

echo "Creating clean database DMG from existing DMG..."

# Check if original DMG exists
if [ ! -f "$DMG_PATH" ]; then
    echo "Error: $DMG_PATH not found. Run ./build_dmg.sh first."
    exit 1
fi

# Create a temporary mount point
MOUNT_POINT="/tmp/ai-search-tool-dmg"
mkdir -p "$MOUNT_POINT"

# Mount the DMG
echo "Mounting DMG..."
hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_POINT" -nobrowse

# Create a temporary directory for the clean version
TEMP_DIR="/tmp/ai-search-tool-clean"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Copy the app bundle
echo "Copying app bundle..."
cp -R "$MOUNT_POINT/AI Search Tool.app" "$TEMP_DIR/"

# Unmount the original DMG
hdiutil detach "$MOUNT_POINT"

# Clean the database in the copied app
APP_STORAGE="$TEMP_DIR/AI Search Tool.app/Contents/Resources/app/server/storage"

echo "Cleaning database..."
# Remove existing storage
rm -rf "$APP_STORAGE"

# Create empty storage structure
mkdir -p "$APP_STORAGE/default"
mkdir -p "$APP_STORAGE/default/chroma_db"
mkdir -p "$APP_STORAGE/default/documents"
mkdir -p "$APP_STORAGE/default/pdfs"
mkdir -p "$APP_STORAGE/default/pdf_thumbnails"

# Create empty database registry
cat > "$APP_STORAGE/database_registry.json" << 'EOF'
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
echo "Initializing empty SQLite database..."
python3 << EOF
import sqlite3
import os

db_path = "$APP_STORAGE/default/documents.db"
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

# Create a symbolic link to Applications
ln -s /Applications "$TEMP_DIR/Applications"

# Create the clean DMG
echo "Creating clean DMG..."
hdiutil create -volname "AI Search Tool" \
    -srcfolder "$TEMP_DIR" \
    -ov -format UDZO \
    "$CLEAN_DMG_PATH"

# Clean up
rm -rf "$TEMP_DIR"

echo "Clean DMG created at: $CLEAN_DMG_PATH"
echo "This DMG contains an empty database - perfect for new installations!"