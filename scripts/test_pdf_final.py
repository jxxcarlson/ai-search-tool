#!/usr/bin/env python3
"""Final test for PDF import functionality"""

import requests
import json

BASE_URL = "http://localhost:8010"

# First, check server status
try:
    stats = requests.get(f"{BASE_URL}/stats")
    print(f"Server status: {stats.status_code}")
    if stats.status_code == 200:
        print(f"Database has {stats.json()['total_documents']} documents")
except Exception as e:
    print(f"Cannot connect to server: {e}")
    exit(1)

# Test PDF import
test_url = "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf"
print(f"\nImporting PDF from: {test_url}")

response = requests.post(
    f"{BASE_URL}/import-pdf-url",
    json={"url": test_url, "title": "Test PDF with Source"}
)

print(f"Response status: {response.status_code}")

if response.status_code == 200:
    doc = response.json()
    print("\nSuccess! Document created:")
    print(f"  ID: {doc['id']}")
    print(f"  Title: {doc['title']}")
    print(f"  Type: {doc.get('doc_type')}")
    print(f"  Source: {doc.get('source', 'NOT SET')}")
    print(f"  Content length: {len(doc.get('content', ''))}")
    
    if doc.get('source') == test_url:
        print("\n✅ Source field correctly set!")
    else:
        print(f"\n❌ Source field not set correctly. Expected: {test_url}, Got: {doc.get('source')}")
else:
    print("\nError response:")
    try:
        error = response.json()
        print(json.dumps(error, indent=2))
    except:
        print(response.text)