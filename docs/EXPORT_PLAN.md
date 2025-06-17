# Data Export Plan for Search Tool App

## 1. **Core Database Export**
- Export SQLite database: `storage/documents.db`
- Export ChromaDB vector database: entire `storage/chroma_db/` directory
- Export document JSON files: entire `storage/documents/` directory
- Export document ID tracker: `storage/document_ids.json`

## 2. **File Storage Export**
- Export PDF files: entire `storage/pdfs/` directory
- Export PDF thumbnails: entire `storage/pdf_thumbnails/` directory

## 3. **Initial/Sample Data**
- Include `sample_documents.json`
- Include entire `inbox/` directory with sample documents

## 4. **Configuration & Dependencies**
- Export `requirements.txt` for Python dependencies
- Document required environment variables (ANTHROPIC_API_KEY)
- Note the sentence transformer model: `all-MiniLM-L6-v2`

## 5. **Export Script Structure**
Create an export script that:
1. Creates a timestamped export directory
2. Copies all databases and storage directories
3. Creates a manifest file listing all exported components
4. Optionally creates a compressed archive (.tar.gz)
5. Includes instructions for importing/restoring

## 6. **Import/Restore Process**
Document how to:
1. Install Python dependencies from requirements.txt
2. Restore database files to correct locations
3. Set up environment variables
4. Download/cache the ML model
5. Verify data integrity after restore

## 7. **Data Validation**
Include checksums or counts of:
- Number of documents in SQLite
- Number of vectors in ChromaDB
- Number of PDF files
- Total size of export

This plan ensures complete portability of the application data while maintaining all relationships and functionality.