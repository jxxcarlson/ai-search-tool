#!/usr/bin/env python3
"""
Test the enhanced PDF extraction to verify improvements
"""

import sys
import os

# Add the server directory to the path
sys.path.append(os.path.join(os.path.dirname(__file__), 'server'))

from pdf_extractor import PDFExtractor
from pdf_extractor_v2 import PDFExtractorV2

def compare_extractors(pdf_path):
    """Compare old and new extractors"""
    print(f"Testing PDF: {pdf_path}\n")
    
    with open(pdf_path, 'rb') as f:
        pdf_content = f.read()
    
    print("=== ORIGINAL PDFExtractor ===")
    old_extractor = PDFExtractor()
    old_text, old_title, old_abstract = old_extractor.extract_text_and_metadata(pdf_content)
    
    print(f"Title: {repr(old_title)}")
    if old_abstract:
        print(f"Abstract (first 200 chars): {repr(old_abstract[:200])}")
    else:
        print("Abstract: None")
    
    print("\n=== ENHANCED PDFExtractorV2 ===")
    new_extractor = PDFExtractorV2()
    new_text, new_title, new_abstract = new_extractor.extract_text_and_metadata(pdf_content)
    
    print(f"Title: {repr(new_title)}")
    if new_abstract:
        print(f"Abstract (first 200 chars): {repr(new_abstract[:200])}")
    else:
        print("Abstract: None")
    
    # Show improvements
    print("\n=== COMPARISON ===")
    if old_title != new_title:
        print(f"Title improved: {old_title and 'arXiv' in old_title} -> {new_title and 'arXiv' not in new_title}")
    else:
        print("Title: No change")
    
    if old_abstract != new_abstract:
        if old_abstract and new_abstract:
            # Check for spacing improvements
            old_spaces = old_abstract.count(' ')
            new_spaces = new_abstract.count(' ')
            print(f"Abstract spacing improved: {old_spaces} -> {new_spaces} spaces")
        else:
            print(f"Abstract extraction: {old_abstract is not None} -> {new_abstract is not None}")
    else:
        print("Abstract: No change")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        # Default to testing an arXiv PDF if it exists
        default_pdf = "../server/storage/db_1e8d4245/pdfs/20250621_072035_1409.3215v3.pdf"
        if os.path.exists(default_pdf):
            compare_extractors(default_pdf)
        else:
            print("Usage: python test_enhanced_extraction.py <pdf_file>")
            sys.exit(1)
    else:
        compare_extractors(sys.argv[1])