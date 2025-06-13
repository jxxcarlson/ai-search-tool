# Render Module Restructuring Migration Guide

This document outlines the changes made to restructure the Render module to improve code organization, maintainability, and extensibility.

## Overview of Changes

The restructuring focused on several key improvements:

1. **Better Type Safety**: Replaced string-based block type identification with proper ADTs
2. **Modular Architecture**: Split monolithic OrdinaryBlock.elm into category-specific modules
3. **Registration Pattern**: Created a registry system for block renderers
4. **Unified Attribute Handling**: Consolidated attribute logic into a single module
5. **Reduced Duplication**: Eliminated redundant code and standardized common operations

## New Structure

```
src/Render/
├── BlockType.elm                    # ADTs for block types
├── Attributes.elm                   # Consolidated attribute handling
├── BlockRegistry.elm                # Registry for block renderers
├── Indentation.elm                  # Unified indentation utilities
├── Blocks/
│   ├── Text.elm                     # Text-focused blocks (indent, center, etc.)
│   ├── Container.elm                # Container blocks (box, comment, etc.)
│   ├── Document.elm                 # Document structure blocks (section, title, etc.)
│   └── Interactive.elm              # Interactive elements (question, answer, etc.)
├── OrdinaryBlock2.elm               # New implementation using registry
└── Tree2.elm                        # Refactored tree renderer
```

## Migration Steps

### 1. Module Imports

Update your imports to use the new modules:

```elm
-- Old imports
import Render.OrdinaryBlock as OrdinaryBlock
import Render.Tree as Tree

-- New imports
import Render.OrdinaryBlock2 as OrdinaryBlock
import Render.Tree2 as Tree
```

### 2. Using the Block Registry

If you were directly accessing functions from `OrdinaryBlock`, you should now use the registry pattern:

```elm
-- Old approach
import Render.OrdinaryBlock exposing (box, indented)

-- New approach
import Render.BlockRegistry as BlockRegistry
import Render.OrdinaryBlock2 as OrdinaryBlock

-- Get the registry
let
    registry = OrdinaryBlock.initRegistry

    -- Look up a renderer
    boxRenderer = 
        BlockRegistry.lookup "box" registry
            |> Maybe.withDefault (\_ _ _ _ _ -> Element.none)
in
boxRenderer count acc settings attrs block
```

### 3. Using the New Type System

If you were comparing strings to determine block types, use the new type system:

```elm
-- Old approach
if blockName == "box" then
    -- Handle box block

-- New approach
import Render.BlockType as BlockType

case BlockType.fromString blockName of
    BlockType.ContainerBlock BlockType.Box ->
        -- Handle box block
    _ ->
        -- Handle other blocks
```

### 4. Attribute Handling

Use the consolidated attribute system:

```elm
-- Old approach
if List.member blockName italicBlockNames then
    [ Font.italic ]
else
    []

-- New approach
import Render.Attributes as Attributes

Attributes.getBlockAttributes block settings
```

### 5. Indentation Helpers

Use the unified indentation helpers:

```elm
-- Old approach
indentOrdinaryBlock block.indent id settings x

-- New approach
import Render.Indentation as Indentation

Indentation.indentOrdinaryBlock block.indent id settings x
```

## Benefits of the New Architecture

- **Maintainability**: Smaller modules with clear responsibilities
- **Extensibility**: Easy to add new block types without modifying core code
- **Performance**: Better organization enables future performance optimizations
- **Code Size**: Reduced duplication means smaller overall code footprint
- **Type Safety**: Better type definitions catch errors at compile time

## Incremental Adoption Strategy

You can adopt the new architecture incrementally:

1. Start by using the new modules alongside the old ones
2. Replace one component at a time (e.g., start with Tree2.elm)
3. Gradually migrate to the new OrdinaryBlock2.elm
4. Once fully migrated, remove the `2` suffix from filenames

## Known Issues

- Some duplicated code still exists in the attribute and style handling
- The tree renderer could be further simplified
- Need to update tests to use the new modules