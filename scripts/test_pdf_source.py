#!/usr/bin/env python3
"""Test that PDF import from URL sets the source field correctly"""

import requests
import json
import time

# API base URL
BASE_URL = "http://localhost:8010"

def test_pdf_import_source():
    """Test importing a PDF from URL and verify source field is set"""
    
    # Test PDF URL (using a publicly available PDF)
    test_url = "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf"
    
    print(f"Testing PDF import from URL: {test_url}")
    
    # Import PDF from URL
    response = requests.post(
        f"{BASE_URL}/import-pdf-url",
        json={"url": test_url, "title": "Test PDF Import"}
    )
    
    if response.status_code != 200:
        print(f"Failed to import PDF: {response.status_code}")
        print(response.text)
        return False
    
    document = response.json()
    doc_id = document.get("id")
    print(f"PDF imported successfully. Document ID: {doc_id}")
    
    # Check if source field is set
    if document.get("source") == test_url:
        print(f"✓ Source field correctly set to: {document['source']}")
        return True
    else:
        print(f"✗ Source field not set correctly. Expected: {test_url}, Got: {document.get('source')}")
        return False

if __name__ == "__main__":
    # Wait a moment to ensure server is ready
    time.sleep(1)
    
    try:
        # Check if server is running
        response = requests.get(f"{BASE_URL}/stats")
        if response.status_code != 200:
            print("Server is not running. Please start the server first.")
            exit(1)
        
        # Run the test
        success = test_pdf_import_source()
        
        if success:
            print("\n✅ Test passed! PDF import correctly sets the source field.")
        else:
            print("\n❌ Test failed!")
            
    except requests.exceptions.ConnectionError:
        print("Could not connect to server. Please ensure it's running on http://localhost:8010")
    except Exception as e:
        print(f"Error: {e}")