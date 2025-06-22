# Move Document Implementation

## Backend Implementation ✅

Added a new API endpoint to move documents between databases:

**Endpoint**: `POST /documents/{doc_id}/move`

**Request Body**:
```json
{
  "target_database_id": "database-id"
}
```

**How it works**:
1. Gets the document from current database
2. Switches to target database and adds document (gets new ID)
3. Deletes document from source database
4. Returns the new document info

**Error Handling**:
- 404 if document or target database not found
- 400 if source and target are the same
- 500 with rollback on any error

## CLI Tool ✅

Created `move_document.py` for command-line moving:

```bash
# List all databases
python move_document.py --list-databases

# Move a document
python move_document.py <doc_id> <target_database_id>
```

Features:
- Shows source and target database names
- Confirmation prompt before moving
- Clear success/error messages

## Testing

1. Start the services:
   ```bash
   ./start.sh
   ```

2. List databases to get IDs:
   ```bash
   source venv/bin/activate
   python move_document.py --list-databases
   ```

3. Move a document:
   ```bash
   python move_document.py doc_123_456789 another-database-id
   ```

## Frontend Options (Not Yet Implemented)

### Option 1: Add Move Button in Document View
- Add "Move to Database" button next to Edit/Delete
- Show modal with database selector
- Refresh view after move

### Option 2: Drag and Drop
- Show databases in sidebar
- Make documents draggable
- Drop on target database to move

### Option 3: Batch Operations
- Checkboxes in document list
- "Move Selected" action
- Select target database in modal

## Next Steps

1. **Test the backend implementation** with the CLI tool
2. **Choose a frontend approach** based on your preference
3. **Add undo functionality** (optional - save move history)
4. **Add move confirmation** in the UI

The backend is ready to use. You can test moving documents between databases using the CLI tool or by making direct API calls.