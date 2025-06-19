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

- `git clone <repo-url> search-tool && cd search-tool`
- `python3 -m venv venv`
- `source venv/bin/activate`
- `pip install -r requirements.txt`
- `cd elm-app && elm make src/Main.elm --output=main.js && cd ..`
- `./start.sh`
  
The app opens automatically at http://localhost:8080, Use ctrl-C
to stop the app or use `./stop.sh`

