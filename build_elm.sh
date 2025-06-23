#!/bin/bash
# Build script for Elm app

cd elm-app
echo "Building Elm app..."
elm make src/Main.elm --output=main.js

if [ $? -eq 0 ]; then
    echo "✓ Build successful!"
    echo "Open elm-app/index.html in your browser to view the app"
else
    echo "✗ Build failed"
    exit 1
fi