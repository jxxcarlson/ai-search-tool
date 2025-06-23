#!/usr/bin/env python3
"""
Import PDF documents from URLs

Usage:
    python import_pdf_url.py <url> [title]
    python import_pdf_url.py --batch <file>
    
Examples:
    python import_pdf_url.py https://example.com/paper.pdf
    python import_pdf_url.py https://example.com/paper.pdf "My Research Paper"
    python import_pdf_url.py --batch urls.txt
"""

import sys
import requests
import json

API_URL = "http://localhost:8010"

def import_single_pdf(url, title=None):
    """Import a single PDF from URL"""
    print(f"Importing PDF from: {url}")
    
    try:
        payload = {"url": url}
        if title:
            payload["title"] = title
            
        response = requests.post(
            f"{API_URL}/import-pdf-url",
            json=payload
        )
        response.raise_for_status()
        
        doc = response.json()
        print(f"✓ Successfully imported: {doc['title']}")
        print(f"  Document ID: {doc['id']}")
        if doc.get('abstract'):
            print(f"  Abstract: {doc['abstract'][:100]}...")
        return True
        
    except requests.exceptions.HTTPError as e:
        try:
            error_detail = e.response.json().get('detail', str(e))
        except:
            error_detail = f"HTTP {e.response.status_code}: {e.response.text[:200]}"
        print(f"✗ Error: {error_detail}")
        return False
    except requests.exceptions.RequestException as e:
        print(f"✗ Error: {e}")
        return False

def import_batch(filename):
    """Import multiple PDFs from a file"""
    try:
        with open(filename, 'r') as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"✗ File not found: {filename}")
        return
    
    total = 0
    success = 0
    
    print(f"Importing {len(lines)} PDFs from {filename}\n")
    
    for line in lines:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
            
        # Support format: URL [Title]
        parts = line.split(' ', 1)
        url = parts[0]
        title = parts[1] if len(parts) > 1 else None
        
        total += 1
        if import_single_pdf(url, title):
            success += 1
        print()
    
    print(f"\nSummary: {success}/{total} PDFs imported successfully")

def main():
    if len(sys.argv) < 2 or "--help" in sys.argv:
        print(__doc__)
        sys.exit(1)
    
    if sys.argv[1] == "--batch":
        if len(sys.argv) < 3:
            print("Error: --batch requires a filename")
            print(__doc__)
            sys.exit(1)
        import_batch(sys.argv[2])
    else:
        url = sys.argv[1]
        title = sys.argv[2] if len(sys.argv) > 2 else None
        import_single_pdf(url, title)

if __name__ == "__main__":
    main()