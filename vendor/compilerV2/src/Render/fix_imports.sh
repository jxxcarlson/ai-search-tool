#!/bin/bash
# Script to fix remaining imports and references after renaming

echo "Fixing references to OrdinaryBlock2 in Block.elm..."
sed -i '' 's/OrdinaryBlock2\.getAttributes/OrdinaryBlock.getAttributes/g' Block.elm
sed -i '' 's/OrdinaryBlock2\.render/OrdinaryBlock.render/g' Block.elm

echo "Renaming Tree2 module to Tree..."
mv Tree2.elm Tree_new.elm
mv Tree_backup.elm Tree.elm 
cp Tree_new.elm Tree.elm

echo "Renaming OrdinaryBlock2 module to OrdinaryBlock..."
mv OrdinaryBlock2.elm OrdinaryBlock_new.elm
mv OrdinaryBlock_backup.elm OrdinaryBlock.elm
cp OrdinaryBlock_new.elm OrdinaryBlock.elm

echo "Updating module declarations..."
sed -i '' 's/module Render\.Tree2/module Render.Tree/g' Tree.elm
sed -i '' 's/module Render\.OrdinaryBlock2/module Render.OrdinaryBlock/g' OrdinaryBlock.elm

echo "Updating tests to use the correct modules..."
sed -i '' 's/Render\.Tree2/Render.Tree/g' TestCompiler.elm

echo "Done fixing imports and references!"