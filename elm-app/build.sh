#!/bin/bash

echo "Building Elm application..."
elm make src/Main.elm --output=main.js --optimize

if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo "To run the app:"
    echo "1. Start the AI search tool server: python server.py"
    echo "2. Open index.html in a browser or serve it with: python -m http.server 8080"
else
    echo "Build failed!"
    exit 1
fi