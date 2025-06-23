#!/usr/bin/env python3
"""Debug PDF import from URL to see exact error"""

import requests
import json

# API base URL
BASE_URL = "http://localhost:8010"

def test_pdf_import():
    """Test importing a PDF from URL and see the error"""
    
    # Test with a simple PDF URL
    test_url = "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf"
    
    print(f"Testing PDF import from URL: {test_url}")
    
    try:
        # Import PDF from URL
        response = requests.post(
            f"{BASE_URL}/import-pdf-url",
            json={"url": test_url}
        )
        
        print(f"Status Code: {response.status_code}")
        print(f"Response Headers: {dict(response.headers)}")
        
        if response.status_code != 200:
            print(f"\nError Response:")
            try:
                error_data = response.json()
                print(json.dumps(error_data, indent=2))
            except:
                print(response.text)
        else:
            print(f"\nSuccess! Document created:")
            print(json.dumps(response.json(), indent=2))
            
    except Exception as e:
        print(f"Request failed: {e}")

if __name__ == "__main__":
    test_pdf_import()