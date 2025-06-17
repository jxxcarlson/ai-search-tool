#!/usr/bin/env python3
"""
Initialize the AI Search Tool database with proper structure.
This creates all necessary tables and directories for a fresh installation.
"""

import os
import sys
from pathlib import Path

# Add server directory to path
sys.path.append(str(Path(__file__).parent / "server"))

from server.models import Base, get_engine
from server import config


def init_database():
    """Initialize the database with all required tables."""
    
    print("Initializing AI Search Tool database...")
    
    # Create all directories
    directories = [
        config.STORAGE_DIR,
        config.DOCUMENTS_DIR,
        config.PDFS_DIR,
        config.PDF_THUMBNAILS_DIR,
        config.CHROMA_DB_DIR
    ]
    
    for directory in directories:
        directory.mkdir(parents=True, exist_ok=True)
        print(f"  ✓ Created directory: {directory}")
    
    # Create database tables
    engine = get_engine(str(config.DATABASE_PATH))
    Base.metadata.create_all(bind=engine)
    print(f"  ✓ Created database: {config.DATABASE_PATH}")
    
    # Initialize document_ids.json
    if not config.DOCUMENT_IDS_PATH.exists():
        with open(config.DOCUMENT_IDS_PATH, "w") as f:
            f.write("[]")
        print(f"  ✓ Created: {config.DOCUMENT_IDS_PATH}")
    
    print("\n✓ Database initialization complete!")
    print(f"Database location: {config.DATABASE_PATH}")
    print("\nYou can now start the server with: ./start.sh")


def main():
    """Main entry point."""
    try:
        init_database()
        return 0
    except Exception as e:
        print(f"\n❌ Initialization failed: {e}")
        return 1


if __name__ == "__main__":
    exit(main())