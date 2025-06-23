#!/usr/bin/env python3
"""
Fix documents with 'fm.dvi' as title - re-extract proper titles from PDFs
"""

import sys
import os
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

from server.document_store_v2_optimized import DocumentStoreV2Optimized
from server.pdf_extractor_v2 import PDFExtractorV2
from server.database_manager import get_database_manager
import server.config as config

def fix_fm_dvi_titles():
    """Find and fix documents with fm.dvi as title"""
    # Initialize document store
    document_store = DocumentStoreV2Optimized(load_model=False)
    pdf_extractor = PDFExtractorV2()
    
    # Get all documents
    documents = document_store.get_all_documents()
    
    fixed_count = 0
    
    for doc in documents:
        if doc['title'] == 'fm.dvi':
            print(f"\nFound document with fm.dvi title:")
            print(f"  ID: {doc['id']}")
            print(f"  Source: {doc.get('source', 'No source')}")
            
            # Check if it's a PDF
            if doc.get('doc_type') == 'pdf' and '[PDF_FILE:' in doc['content']:
                # Extract PDF filename
                pdf_start = doc['content'].find('[PDF_FILE:') + 10
                pdf_end = doc['content'].find(']', pdf_start)
                pdf_filename = doc['content'][pdf_start:pdf_end]
                
                pdf_path = config.PDFS_DIR / pdf_filename
                print(f"  PDF file: {pdf_filename}")
                
                if pdf_path.exists():
                    # Read PDF and re-extract title
                    with open(pdf_path, 'rb') as f:
                        pdf_content = f.read()
                    
                    # Extract with updated extractor
                    text_content, pdf_title, pdf_abstract = pdf_extractor.extract_text_and_metadata(pdf_content)
                    
                    # If no title from metadata, try to extract from content
                    if not pdf_title or pdf_title == 'fm.dvi':
                        print("  Metadata title invalid, extracting from content...")
                        # Try to extract from the actual text content
                        lines = text_content.split('\n')[:50]  # First 50 lines
                        
                        # Look for "Introduction to Relativity" pattern
                        for line in lines:
                            if 'introduction' in line.lower() and 'relativity' in line.lower():
                                pdf_title = line.strip()
                                # Clean up the title
                                pdf_title = ' '.join(pdf_title.split())  # Normalize whitespace
                                if 10 < len(pdf_title) < 200:
                                    break
                        
                        # If still no title, use a better default
                        if not pdf_title or pdf_title == 'fm.dvi':
                            if doc.get('source') and 'Relativity' in doc['source']:
                                pdf_title = "An Introduction to Relativity"
                            else:
                                pdf_title = "Untitled Document"
                    
                    print(f"  New title: {pdf_title}")
                    
                    # Update the document
                    if pdf_title and pdf_title != 'fm.dvi':
                        success = document_store.update_document(doc['id'], title=pdf_title)
                        if success:
                            print("  ✓ Title updated successfully")
                            fixed_count += 1
                        else:
                            print("  ✗ Failed to update title")
                else:
                    print(f"  ✗ PDF file not found: {pdf_path}")
    
    print(f"\nFixed {fixed_count} documents with fm.dvi titles")

if __name__ == "__main__":
    fix_fm_dvi_titles()