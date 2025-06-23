#!/bin/bash
cd elm-app
elm make src/Main.elm --output=main.js
echo "Compilation finished with exit code: $?"