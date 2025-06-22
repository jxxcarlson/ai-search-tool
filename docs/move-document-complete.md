# Move Document Feature - Complete Implementation

## ✅ Backend Implementation

**API Endpoint**: `POST /documents/{doc_id}/move`
- Request body: `{"target_database_id": "database-id"}`
- Returns: Moved document with new ID
- Handles errors and rollback

## ✅ Frontend Implementation

### Added to Elm App:
1. **Model fields**:
   - `showMoveDocumentModal: Bool`
   - `moveDocumentId: Maybe String`
   - `moveTargetDatabaseId: Maybe String`

2. **Messages**:
   - `ShowMoveDocumentModal String`
   - `CancelMoveDocument`
   - `SelectTargetDatabase String`
   - `ConfirmMoveDocument`
   - `DocumentMoved (Result Http.Error Document)`

3. **UI Changes**:
   - Added "Move" button in document actions (between Edit and Delete)
   - Modal dialog for selecting target database
   - Shows list of available databases with document counts
   - Disabled state when no other databases exist

### How it Works:
1. Click "Move" button on any document
2. Modal shows list of other databases
3. Click to select target database
4. Click "Move Document" to confirm
5. Document is moved and view returns to document list

## ✅ CLI Tool

`move_document.py` - Command line interface for moving documents

```bash
# List all databases
python move_document.py --list-databases

# Move a document
python move_document.py <doc_id> <target_database_id>
```

## Testing

1. Compile and run:
   ```bash
   cd elm-app
   elm make src/Main.elm --output=main.js
   cd ..
   ./start.sh
   ```

2. Open http://localhost:8080

3. Test the feature:
   - Select a document
   - Click "Move" button
   - Choose target database
   - Confirm move

## Features

- ✅ Single document move with UI
- ✅ Shows only other databases (not current)
- ✅ Updates document counts automatically
- ✅ Returns to list view after move
- ✅ Error handling with messages
- ✅ Loading states during move
- ✅ CLI tool for scripting

## Future Enhancements

1. **Batch move**: Select multiple documents to move
2. **Drag and drop**: Drag documents to database in sidebar
3. **Undo**: Keep move history for undo functionality
4. **Copy instead of move**: Option to duplicate to another database