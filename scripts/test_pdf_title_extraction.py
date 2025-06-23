#!/usr/bin/env python3
"""
Test PDF title extraction functionality
"""

import requests
import os
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter
from reportlab.pdfbase.pdfdoc import PDFInfo

def create_test_pdf_with_metadata(filename, title, author=None):
    """Create a PDF with metadata"""
    c = canvas.Canvas(filename, pagesize=letter)
    
    # Set metadata
    c.setTitle(title)
    if author:
        c.setAuthor(author)
    
    # Add content
    c.drawString(100, 700, title)
    c.drawString(100, 650, "This is a test PDF document with metadata")
    c.drawString(100, 600, f"The title in metadata is: {title}")
    c.showPage()
    c.save()
    print(f"Created PDF with metadata title: {title}")

def create_test_pdf_without_metadata(filename, first_line):
    """Create a PDF without metadata but with title-like first line"""
    c = canvas.Canvas(filename, pagesize=letter)
    
    # Add content with title-like first line
    c.drawString(100, 700, first_line)
    c.drawString(100, 650, "")
    c.drawString(100, 600, "This is the body of the document")
    c.drawString(100, 550, "without any metadata set")
    c.showPage()
    c.save()
    print(f"Created PDF without metadata, first line: {first_line}")

def upload_and_check_pdf(filepath, expected_title):
    """Upload PDF and check the extracted title"""
    with open(filepath, 'rb') as f:
        files = {'file': (os.path.basename(filepath), f, 'application/pdf')}
        response = requests.post('http://localhost:8010/upload-pdf', files=files)
    
    if response.status_code == 200:
        doc = response.json()
        actual_title = doc['title']
        print(f"  Uploaded successfully!")
        print(f"  Expected title: {expected_title}")
        print(f"  Actual title: {actual_title}")
        print(f"  Match: {'✓' if actual_title == expected_title else '✗'}")
        return actual_title == expected_title
    else:
        print(f"  Upload failed: {response.status_code}")
        print(f"  {response.text}")
        return False

def main():
    print("Testing PDF title extraction...\n")
    
    # Test 1: PDF with metadata title
    print("Test 1: PDF with metadata title")
    pdf1 = "test_with_metadata.pdf"
    create_test_pdf_with_metadata(pdf1, "Machine Learning Fundamentals", "Test Author")
    upload_and_check_pdf(pdf1, "Machine Learning Fundamentals")
    os.remove(pdf1)
    print()
    
    # Test 2: PDF without metadata but with clear first line
    print("Test 2: PDF without metadata, title from first line")
    pdf2 = "test_without_metadata.pdf"
    create_test_pdf_without_metadata(pdf2, "Introduction to Neural Networks")
    upload_and_check_pdf(pdf2, "Introduction to Neural Networks")
    os.remove(pdf2)
    print()
    
    # Test 3: PDF with no metadata and no clear title
    print("Test 3: PDF with no metadata and generic first line")
    pdf3 = "research_paper_2024.pdf"
    c = canvas.Canvas(pdf3, pagesize=letter)
    c.drawString(100, 700, "Page 1")
    c.drawString(100, 650, "Some content here")
    c.showPage()
    c.save()
    print(f"Created PDF with generic content")
    upload_and_check_pdf(pdf3, "research_paper_2024")  # Should fall back to filename
    os.remove(pdf3)
    print()
    
    print("Testing complete!")

if __name__ == "__main__":
    main()