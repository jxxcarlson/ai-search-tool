# Document Move Between Databases - Implementation Plan

## Overview
Add functionality to move documents from one database to another, preserving all metadata and content.

## Backend Changes

### 1. API Endpoint
Create a new endpoint in `server/server.py`:
```python
@app.post("/documents/{doc_id}/move")
async def move_document(doc_id: str, target_database_id: str):
    """Move a document to a different database"""
```

### 2. Implementation Steps
1. Get document from current database
2. Switch to target database
3. Add document to target database (with new ID)
4. Delete from source database
5. Return new document info

### 3. Considerations
- Preserve original creation date
- Generate new embeddings in target database
- Handle tags and metadata
- Ensure atomic operation (rollback on failure)

## Frontend Changes

### 1. UI Options

**Option A: Quick Action Button**
- Add "Move" button in document view
- Show database selector modal
- One-click move

**Option B: Batch Operations**
- Checkbox selection in document list
- "Move Selected" button
- Move multiple documents at once

**Option C: Drag and Drop**
- Show databases in sidebar
- Drag documents to target database
- Visual feedback during drag

### 2. Elm Model Updates
```elm
type Msg
    = ...
    | MoveDocument String String  -- doc_id, target_db_id
    | ShowMoveModal String
    | DocumentMoved Document
```

## Implementation Priority

1. **Phase 1**: Single document move
   - API endpoint
   - Simple UI in document view
   - Basic error handling

2. **Phase 2**: Batch operations
   - Multi-select in list view
   - Bulk move endpoint
   - Progress indicator

3. **Phase 3**: Enhanced UX
   - Drag and drop
   - Undo functionality
   - Move history

## Alternative Approaches

### Copy Instead of Move
- Keep original document
- Create duplicate in target database
- User chooses to delete original

### Export/Import
- Export document to JSON
- Import to target database
- More manual but safer

### Database Merge
- Merge entire databases
- Deduplicate documents
- Advanced feature