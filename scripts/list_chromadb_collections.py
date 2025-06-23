#!/usr/bin/env python3
"""List all collections in ChromaDB"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'server'))

import chromadb
from chromadb.config import Settings

# Connect to ChromaDB
chroma_client = chromadb.PersistentClient(
    path="../server/chroma_db",
    settings=Settings(anonymized_telemetry=False)
)

# List all collections
collections = chroma_client.list_collections()
print(f"Found {len(collections)} collections:")
for collection in collections:
    print(f"  - {collection.name} (count: {collection.count()})")