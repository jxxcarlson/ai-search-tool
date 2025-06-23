#!/usr/bin/env python3
"""
Debug script to test PDF URL download
"""

import requests
from urllib.parse import urlparse

def test_pdf_url(url):
    """Test downloading a PDF URL to see what's happening"""
    print(f"Testing URL: {url}")
    
    # Parse URL
    parsed_url = urlparse(url)
    print(f"Parsed URL scheme: {parsed_url.scheme}")
    
    # Try to download with headers
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    
    print("\nAttempting download...")
    try:
        # Try with SSL verification
        response = requests.get(url, headers=headers, timeout=30, stream=True)
        print(f"Response status code: {response.status_code}")
        print(f"Response headers:")
        for key, value in response.headers.items():
            print(f"  {key}: {value}")
        
        # Check content type
        content_type = response.headers.get('content-type', '').lower()
        print(f"\nContent-Type: {content_type}")
        print(f"URL ends with .pdf: {url.lower().endswith('.pdf')}")
        print(f"Content-Type contains 'application/pdf': {'application/pdf' in content_type}")
        
        # Check if we got an HTML error page
        if response.status_code == 200:
            # Read first 1000 bytes to check content
            first_chunk = next(response.iter_content(chunk_size=1000))
            print(f"\nFirst 100 bytes of content: {first_chunk[:100]}")
            
            # Check if it's actually PDF
            if first_chunk.startswith(b'%PDF'):
                print("\n✓ This is a valid PDF file")
            else:
                print("\n✗ This is NOT a PDF file")
                # Try to decode as text to see what it is
                try:
                    text_preview = first_chunk.decode('utf-8', errors='ignore')[:500]
                    print(f"Content preview:\n{text_preview}")
                except:
                    pass
        
    except requests.exceptions.SSLError as e:
        print(f"\nSSL Error: {e}")
        print("Retrying without SSL verification...")
        
        try:
            response = requests.get(url, headers=headers, timeout=30, stream=True, verify=False)
            print(f"Response status code (no SSL): {response.status_code}")
        except Exception as e2:
            print(f"Failed even without SSL: {e2}")
            
    except requests.exceptions.RequestException as e:
        print(f"\nRequest failed: {type(e).__name__}: {e}")
    except Exception as e:
        print(f"\nUnexpected error: {type(e).__name__}: {e}")


if __name__ == "__main__":
    # Test the problematic URL
    url = "https://scholar.harvard.edu/files/noahmiller/files/statistical_mechanics.pdf"
    test_pdf_url(url)
    
    print("\n" + "="*60 + "\n")
    
    # Test a known working PDF URL
    print("Testing a known working PDF URL for comparison:")
    test_pdf_url("https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf")