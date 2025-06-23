#!/usr/bin/env python3
"""Test importing the Carroll PDF to see the exact error"""

import requests
import json

BASE_URL = "http://localhost:8010"
PDF_URL = "https://fma.if.usp.br/~mlima/teaching/PGF5292_2021/Carroll_SG.pdf"

print(f"Testing import of: {PDF_URL}")

# First, try to download the PDF directly to see if it's accessible
try:
    print("\n1. Testing direct download...")
    response = requests.get(PDF_URL, timeout=10)
    print(f"   Status: {response.status_code}")
    print(f"   Content-Type: {response.headers.get('content-type', 'Not specified')}")
    print(f"   Content-Length: {response.headers.get('content-length', 'Not specified')}")
    
    if response.status_code == 200:
        print(f"   PDF size: {len(response.content)} bytes")
except Exception as e:
    print(f"   Error downloading: {e}")

# Now try the import endpoint
print("\n2. Testing import via API...")
try:
    response = requests.post(
        f"{BASE_URL}/import-pdf-url",
        json={"url": PDF_URL},
        timeout=60  # Longer timeout for processing
    )
    
    print(f"   Status: {response.status_code}")
    
    if response.status_code != 200:
        print(f"\n   Error response:")
        try:
            error_data = response.json()
            print(f"   {json.dumps(error_data, indent=2)}")
        except:
            print(f"   {response.text}")
    else:
        doc = response.json()
        print(f"\n   Success!")
        print(f"   Document ID: {doc['id']}")
        print(f"   Title: {doc['title']}")
        print(f"   Source: {doc.get('source', 'Not set')}")
        
except requests.exceptions.Timeout:
    print("   Request timed out")
except Exception as e:
    print(f"   Error: {e}")