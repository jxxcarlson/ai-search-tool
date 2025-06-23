#!/usr/bin/env python3
"""Test PDF URL import with a sample PDF"""

import requests

# Test with a public domain PDF
test_url = "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf"

print("Testing PDF URL import...")
print(f"URL: {test_url}\n")

response = requests.post(
    "http://localhost:8010/import-pdf-url",
    json={
        "url": test_url,
        "title": "W3C Test PDF Document"
    }
)

if response.status_code == 200:
    doc = response.json()
    print("✓ Import successful!")
    print(f"Title: {doc['title']}")
    print(f"ID: {doc['id']}")
    print(f"Type: {doc.get('doc_type', 'unknown')}")
    if doc.get('abstract'):
        print(f"Abstract: {doc['abstract'][:200]}...")
else:
    print(f"✗ Import failed: {response.status_code}")
    print(response.text)