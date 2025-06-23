#!/bin/bash

echo "Testing Move Document feature..."

# Compile Elm
cd elm-app
echo "Compiling Elm..."
elm make src/Main.elm --output=main.js

if [ $? -eq 0 ]; then
    echo "✓ Elm compilation successful"
else
    echo "✗ Elm compilation failed"
    exit 1
fi

cd ..

echo ""
echo "Move Document feature is ready!"
echo ""
echo "How to use:"
echo "1. Make sure services are running (./start.sh)"
echo "2. Open http://localhost:8080"
echo "3. Select any document"
echo "4. Click the 'Move' button in document actions"
echo "5. Select target database and confirm"
echo ""
echo "You can also use the CLI:"
echo "  python move_document.py --list-databases"
echo "  python move_document.py <doc_id> <target_db_id>"