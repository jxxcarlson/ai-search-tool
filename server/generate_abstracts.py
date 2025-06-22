#!/usr/bin/env python3
"""
Batch process existing documents to generate abstracts
"""

import sys
import time
from pathlib import Path
from database_manager import get_database_manager
from document_store_v2_optimized import DocumentStoreV2Optimized as DocumentStoreV2
from abstract_extractor import AbstractExtractor
from anthropic import Anthropic
import config


def process_database(db_id: str, db_name: str, abstract_extractor: AbstractExtractor, 
                    use_ai: bool = True, dry_run: bool = False):
    """Process all documents in a database to add abstracts"""
    print(f"\nProcessing database: {db_name} (ID: {db_id})")
    
    # Initialize document store for this database
    document_store = DocumentStoreV2(database_id=db_id, load_model=False)
    
    # Get all documents
    documents = document_store.get_all_documents()
    print(f"Found {len(documents)} documents")
    
    # Filter documents without abstracts
    docs_without_abstracts = [doc for doc in documents if not doc.get('abstract')]
    print(f"{len(docs_without_abstracts)} documents need abstracts")
    
    if dry_run:
        print("DRY RUN - No changes will be made")
    
    processed = 0
    skipped = 0
    errors = 0
    
    for i, doc in enumerate(docs_without_abstracts, 1):
        doc_id = doc['id']
        title = doc['title']
        content = doc['content']
        doc_type = doc.get('doc_type', 'txt')
        
        print(f"\n[{i}/{len(docs_without_abstracts)}] Processing: {title[:50]}...")
        
        try:
            # For PDFs, check if content has PDF metadata
            if doc_type == 'pdf' and '[PDF_FILE:' in content:
                # Extract clean text content (remove metadata)
                clean_content = content
                if '[PDF_META:' in content:
                    meta_end = content.find(']\n\n', content.find('[PDF_META:'))
                    if meta_end > 0:
                        clean_content = content[meta_end + 3:]
                else:
                    file_end = content.find(']\n\n', content.find('[PDF_FILE:'))
                    if file_end > 0:
                        clean_content = content[file_end + 3:]
                content_for_abstract = clean_content
            else:
                content_for_abstract = content
            
            # Extract abstract
            abstract, abstract_source = abstract_extractor.extract_abstract(
                content_for_abstract, 
                doc_type, 
                title
            )
            
            if not abstract:
                print(f"  ⚠ Could not generate abstract")
                skipped += 1
                continue
            
            print(f"  ✓ Generated abstract ({abstract_source}): {abstract[:100]}...")
            
            if not dry_run:
                # Update document with abstract
                success = document_store.update_document(
                    doc_id,
                    abstract=abstract,
                    abstract_source=abstract_source
                )
                
                if success:
                    processed += 1
                else:
                    print(f"  ✗ Failed to update document")
                    errors += 1
            else:
                processed += 1
            
            # Rate limiting for AI generation
            if abstract_source == "ai_generated" and use_ai:
                time.sleep(0.5)  # Be nice to the API
                
        except Exception as e:
            print(f"  ✗ Error: {e}")
            errors += 1
    
    print(f"\n{db_name} Summary:")
    print(f"  Processed: {processed}")
    print(f"  Skipped: {skipped}")
    print(f"  Errors: {errors}")
    
    return processed, skipped, errors


def main():
    """Main entry point"""
    # Parse arguments
    use_ai = "--use-ai" in sys.argv
    dry_run = "--dry-run" in sys.argv
    
    if "--help" in sys.argv:
        print("""
Usage: python generate_abstracts.py [OPTIONS]

Options:
    --use-ai     Use Claude API for abstract generation (requires API key)
    --dry-run    Show what would be done without making changes
    --help       Show this help message

By default, abstracts are extracted from document structure or first paragraph.
With --use-ai, Claude will generate abstracts when extraction fails.
""")
        return
    
    print("Abstract Generation Tool")
    print("=" * 50)
    
    # Initialize abstract extractor
    anthropic_client = None
    if use_ai:
        if config.ANTHROPIC_API_KEY:
            anthropic_client = Anthropic(api_key=config.ANTHROPIC_API_KEY)
            print("✓ Claude API enabled for abstract generation")
        else:
            print("✗ No API key found. Falling back to extraction only.")
            use_ai = False
    else:
        print("ℹ Running in extraction-only mode (no AI generation)")
    
    abstract_extractor = AbstractExtractor(anthropic_client)
    
    # Get all databases
    db_manager = get_database_manager()
    databases = db_manager.list_databases()
    
    if not databases:
        print("No databases found.")
        return
    
    print(f"\nFound {len(databases)} database(s)")
    
    # Process each database
    total_processed = 0
    total_skipped = 0
    total_errors = 0
    
    for db_info in databases:
        processed, skipped, errors = process_database(
            db_info.id, 
            db_info.name,
            abstract_extractor,
            use_ai,
            dry_run
        )
        total_processed += processed
        total_skipped += skipped
        total_errors += errors
    
    print("\n" + "=" * 50)
    print("Overall Summary:")
    print(f"  Total processed: {total_processed}")
    print(f"  Total skipped: {total_skipped}")
    print(f"  Total errors: {total_errors}")
    
    if dry_run:
        print("\nThis was a DRY RUN - no changes were made.")
        print("Run without --dry-run to apply changes.")


if __name__ == "__main__":
    main()