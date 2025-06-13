#!/bin/bash
# Script to rename modules for final migration

echo "Creating backups of original files..."
cp Tree.elm Tree_backup.elm
cp OrdinaryBlock.elm OrdinaryBlock_backup.elm

echo "Copying new implementations to replace the old ones..."
cp Tree2.elm Tree.elm
cp OrdinaryBlock2.elm OrdinaryBlock.elm

echo "Updating imports in all files from Tree2 to Tree..."
grep -l "import Render.Tree2" *.elm | xargs sed -i '' 's/import Render\.Tree2/import Render\.Tree/g'

echo "Updating imports in all files from OrdinaryBlock2 to OrdinaryBlock..."
grep -l "import Render.OrdinaryBlock2" *.elm | xargs sed -i '' 's/import Render\.OrdinaryBlock2/import Render\.OrdinaryBlock/g'

echo "Done!"