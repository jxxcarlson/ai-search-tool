#!/usr/bin/env python3
import requests
import os

# First, let's create a simple PDF for testing
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter

# Create a test PDF
pdf_file = "test_thumbnails.pdf"
c = canvas.Canvas(pdf_file, pagesize=letter)

# Add multiple pages to test thumbnail generation
for i in range(5):
    c.drawString(100, 700, f"Test Page {i+1}")
    c.drawString(100, 650, f"This is page {i+1} of a test PDF document")
    c.drawString(100, 600, f"Generated to test thumbnail functionality")
    c.showPage()

c.save()
print(f"Created test PDF: {pdf_file}")

# Upload the PDF
with open(pdf_file, 'rb') as f:
    files = {'file': (pdf_file, f, 'application/pdf')}
    response = requests.post('http://localhost:8010/upload-pdf', files=files)
    
if response.status_code == 200:
    doc = response.json()
    print(f"PDF uploaded successfully!")
    print(f"Document ID: {doc['id']}")
    print(f"Title: {doc['title']}")
    
    # Extract the PDF filename from the content
    content = doc['content']
    if '[PDF_FILE:' in content:
        start = content.find('[PDF_FILE:') + 10
        end = content.find(']', start)
        pdf_filename = content[start:end]
        print(f"PDF filename: {pdf_filename}")
        
        # Check if thumbnails were generated
        thumbnails_dir = f"storage/thumbnails/{pdf_filename}"
        if os.path.exists(thumbnails_dir):
            print(f"\nThumbnails generated in: {thumbnails_dir}")
            thumbnails = os.listdir(thumbnails_dir)
            print(f"Number of thumbnails: {len(thumbnails)}")
            for thumb in sorted(thumbnails):
                print(f"  - {thumb}")
        else:
            print(f"\nNo thumbnails directory found at: {thumbnails_dir}")
else:
    print(f"Upload failed: {response.status_code}")
    print(response.text)

# Clean up
os.remove(pdf_file)
print(f"\nCleaned up test file: {pdf_file}")