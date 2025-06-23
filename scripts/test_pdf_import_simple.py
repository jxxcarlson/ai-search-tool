#!/usr/bin/env python3
"""Simple test for PDF import from URL"""

import requests

# Test URL - a simple PDF
url = "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf"

print(f"Testing import from: {url}")

response = requests.post(
    "http://localhost:8010/import-pdf-url",
    json={"url": url}
)

print(f"Status: {response.status_code}")
if response.status_code == 200:
    doc = response.json()
    print(f"Success! Document ID: {doc['id']}")
    print(f"Title: {doc['title']}")
    print(f"Source: {doc.get('source', 'NOT SET')}")
else:
    print(f"Error: {response.text}")