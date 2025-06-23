#!/usr/bin/env python3
"""
Test PDF extraction to debug issues
"""

import sys
import PyPDF2
import io

def test_pdf_extraction(pdf_path):
    """Test PDF extraction and show what we're getting"""
    print(f"Testing PDF: {pdf_path}\n")
    
    with open(pdf_path, 'rb') as f:
        pdf_content = f.read()
    
    pdf_reader = PyPDF2.PdfReader(io.BytesIO(pdf_content))
    
    # Check metadata
    print("=== METADATA ===")
    if pdf_reader.metadata:
        for key, value in pdf_reader.metadata.items():
            print(f"{key}: {value}")
    else:
        print("No metadata found")
    
    print("\n=== FIRST PAGE RAW TEXT (first 1000 chars) ===")
    if len(pdf_reader.pages) > 0:
        first_page = pdf_reader.pages[0].extract_text()
        print(first_page[:1000])
        print("\n[... truncated ...]")
        
        print("\n=== FIRST 30 LINES ===")
        lines = first_page.split('\n')
        for i, line in enumerate(lines[:30]):
            print(f"{i:2d}: {repr(line)}")
    
    print("\n=== LOOKING FOR ABSTRACT ===")
    # Try to find abstract in first 3 pages
    full_text = ""
    for i in range(min(3, len(pdf_reader.pages))):
        full_text += pdf_reader.pages[i].extract_text() + "\n"
    
    # Look for Abstract
    import re
    abstract_match = re.search(r'Abstract(.*?)(Introduction|Keywords|1\s*Introduction)', full_text, re.IGNORECASE | re.DOTALL)
    if abstract_match:
        abstract_text = abstract_match.group(1).strip()
        print(f"Found abstract ({len(abstract_text)} chars):")
        print(abstract_text[:500])
        print("\n[... truncated ...]")
    else:
        print("No abstract pattern found")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python test_pdf_extraction.py <pdf_file>")
        sys.exit(1)
    
    test_pdf_extraction(sys.argv[1])