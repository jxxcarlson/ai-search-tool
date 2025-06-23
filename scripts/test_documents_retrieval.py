#!/usr/bin/env python3
"""Test document retrieval after migration"""

import requests
import json

BASE_URL = "http://localhost:8010"

print("Testing document retrieval...")

# Test 1: Get stats
try:
    response = requests.get(f"{BASE_URL}/stats")
    print(f"\n1. Stats endpoint: {response.status_code}")
    if response.status_code == 200:
        stats = response.json()
        print(f"   Total documents: {stats['total_documents']}")
except Exception as e:
    print(f"   Error: {e}")

# Test 2: Get documents
try:
    response = requests.get(f"{BASE_URL}/documents")
    print(f"\n2. Documents endpoint: {response.status_code}")
    if response.status_code == 200:
        documents = response.json()
        print(f"   Retrieved {len(documents)} documents")
        if documents:
            doc = documents[0]
            print(f"   First document:")
            print(f"     - ID: {doc['id']}")
            print(f"     - Title: {doc['title']}")
            print(f"     - Source: {doc.get('source', 'Not set')}")
    else:
        print(f"   Error: {response.text}")
except Exception as e:
    print(f"   Error: {e}")

# Test 3: Get current database
try:
    response = requests.get(f"{BASE_URL}/current-database")
    print(f"\n3. Current database: {response.status_code}")
    if response.status_code == 200:
        db = response.json()
        print(f"   Database: {db['name']}")
        print(f"   Document count: {db['document_count']}")
except Exception as e:
    print(f"   Error: {e}")

# Test 4: Get all databases
try:
    response = requests.get(f"{BASE_URL}/databases")
    print(f"\n4. All databases: {response.status_code}")
    if response.status_code == 200:
        databases = response.json()
        print(f"   Found {len(databases)} databases:")
        for db in databases:
            print(f"     - {db['name']}: {db['document_count']} documents")
except Exception as e:
    print(f"   Error: {e}")