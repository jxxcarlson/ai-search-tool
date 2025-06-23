#!/usr/bin/env python3
"""
Move a document between databases

Usage:
    python move_document.py <doc_id> <target_database_id>
    python move_document.py --list-databases
"""

import sys
import requests
import json
from tabulate import tabulate

API_URL = "http://localhost:8010"

def list_databases():
    """List all available databases"""
    try:
        response = requests.get(f"{API_URL}/databases")
        response.raise_for_status()
        databases = response.json()
        
        if not databases:
            print("No databases found.")
            return
        
        # Prepare data for table
        table_data = []
        for db in databases:
            table_data.append([
                db['id'],
                db['name'],
                db.get('description', ''),
                db.get('document_count', 0)
            ])
        
        print("\nAvailable Databases:")
        print("-" * 60)
        for db in databases:
            print(f"ID: {db['id']}")
            print(f"Name: {db['name']}")
            print(f"Documents: {db.get('document_count', 0)}")
            if db.get('description'):
                # Truncate long descriptions
                desc = db['description']
                if len(desc) > 60:
                    desc = desc[:57] + "..."
                print(f"Description: {desc}")
            print("-" * 60)
        
    except requests.exceptions.RequestException as e:
        print(f"Error fetching databases: {e}")
        sys.exit(1)

def get_current_database():
    """Get current database info"""
    try:
        response = requests.get(f"{API_URL}/current-database")
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error fetching current database: {e}")
        sys.exit(1)

def move_document(doc_id, target_db_id):
    """Move a document to another database"""
    try:
        # Get current database
        current_db = get_current_database()
        print(f"\nMoving document {doc_id}")
        print(f"From: {current_db['name']} ({current_db['id']})")
        
        # Get target database info
        response = requests.get(f"{API_URL}/databases")
        databases = response.json()
        target_db = next((db for db in databases if db['id'] == target_db_id), None)
        
        if not target_db:
            print(f"Error: Target database '{target_db_id}' not found")
            return
        
        print(f"To: {target_db['name']} ({target_db['id']})")
        
        # Confirm
        confirm = input("\nProceed with move? (y/n): ")
        if confirm.lower() != 'y':
            print("Move cancelled.")
            return
        
        # Move the document
        response = requests.post(
            f"{API_URL}/documents/{doc_id}/move",
            json={"target_database_id": target_db_id}
        )
        response.raise_for_status()
        
        moved_doc = response.json()
        print(f"\nSuccess! Document moved.")
        print(f"New ID: {moved_doc['id']}")
        print(f"Title: {moved_doc['title']}")
        
    except requests.exceptions.HTTPError as e:
        try:
            error_detail = e.response.json().get('detail', str(e))
        except:
            # If response isn't JSON, show status code and text
            error_detail = f"HTTP {e.response.status_code}: {e.response.text[:200]}"
        print(f"Error: {error_detail}")
    except requests.exceptions.RequestException as e:
        print(f"Error: {e}")

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    if sys.argv[1] == "--list-databases":
        list_databases()
    elif len(sys.argv) == 3:
        doc_id = sys.argv[1]
        target_db_id = sys.argv[2]
        move_document(doc_id, target_db_id)
    else:
        print(__doc__)
        sys.exit(1)

if __name__ == "__main__":
    main()