# AI Search Tool

A semantic document search system that runs locally with a web interface built in Elm and a Python backend using sentence transformers and ChromaDB.

This an experimental project built mostly with Claude. There is more work to do:

- Completely redesigned user interface
- Work on the clustering and cluster-naming algorithms
- _Improve the documentation and get rid of unnecess ary stuff._
- Whatever

## Features

- Add documents manually to the a local document database (sqlite): paste them into editor
- Edit documents
- Render documents written in plain text, markdown, scripta, or minilatex
- Group document semantically
- Claude AI integration: ask Claude something, save reply if you like it  Requires Claude API key.
- Create and manage new databases
- Export and import databaes

# To do

- _Documentation!_
- File upload
- Batch file upload
- Add integration with other AI's

# Installation

## Clone and setup
git clone <repo-url> search-tool
cd search-tool

## Install Python dependencies
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

## Build Elm frontend
cd elm-app
elm make src/Main.elm --output=main.js
cd ..

#3 Start the app
./start.sh

The app opens automatically at http://localhost:8080

