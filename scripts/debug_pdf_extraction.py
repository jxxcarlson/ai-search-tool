#!/usr/bin/env python3
"""
Debug PDF extraction to see what PyPDF2 is actually extracting
"""

import sys
import os
import PyPDF2
import io

# Add the server directory to the path
sys.path.append(os.path.join(os.path.dirname(__file__), 'server'))

from pdf_extractor import PDFExtractor

def debug_extraction(pdf_path):
    """Debug PDF extraction and show intermediate results"""
    print(f"Testing PDF: {pdf_path}\n")
    
    with open(pdf_path, 'rb') as f:
        pdf_content = f.read()
    
    # First, let's see what PyPDF2 gives us raw
    pdf_reader = PyPDF2.PdfReader(io.BytesIO(pdf_content))
    
    print("=== RAW FIRST PAGE TEXT (first 2000 chars) ===")
    if len(pdf_reader.pages) > 0:
        raw_text = pdf_reader.pages[0].extract_text()
        print(raw_text[:2000])
        print("\n[... truncated ...]\n")
        
        # Show character codes for the first line to debug encoding
        first_line = raw_text.split('\n')[0] if '\n' in raw_text else raw_text[:100]
        print("=== FIRST LINE CHARACTER ANALYSIS ===")
        print(f"Text: {repr(first_line)}")
        print("Character codes:")
        for i, char in enumerate(first_line[:50]):  # First 50 chars
            print(f"  {i}: '{char}' (ord={ord(char)})")
    
    print("\n=== USING PDFExtractor ===")
    extractor = PDFExtractor()
    full_text, title, abstract = extractor.extract_text_and_metadata(pdf_content)
    
    print(f"\nExtracted Title: {repr(title)}")
    print(f"\nExtracted Abstract: {repr(abstract[:200] if abstract else None)}")
    
    print("\n=== CHECKING FOR LIGATURES ===")
    # Check for common ligatures in the raw text
    ligatures = ['ﬁ', 'ﬂ', 'ﬀ', 'ﬃ', 'ﬄ']
    for lig in ligatures:
        count = raw_text.count(lig)
        if count > 0:
            print(f"Found ligature '{lig}' {count} times")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python debug_pdf_extraction.py <pdf_file>")
        sys.exit(1)
    
    debug_extraction(sys.argv[1])