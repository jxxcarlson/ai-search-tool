# Render Module Architecture

## Overview

The Render module is responsible for rendering expression blocks and trees to create formatted output in the Scripta compiler. The architecture follows a modular design that separates concerns and makes extending the system easier.

## Core Components

### Block Types

- **Render.BlockType**: Defines a type system for different kinds of blocks
  - `TextBlock`: Formatting blocks like indent, center, quotation
  - `ContainerBlock`: Container elements like box, comment, collection
  - `DocumentBlock`: Document structure elements like title, section, subheading
  - `InteractiveBlock`: Interactive elements like questions, answers, reveals

### Rendering System

- **Render.Block**: Core block rendering functions
- **Render.Tree**: Renders tree structures of blocks
- **Render.OrdinaryBlock**: Handles ordinary blocks rendering via registry pattern

### Specialized Renderers

- **Render.Blocks.Text**: Text-focused block renderers
- **Render.Blocks.Container**: Container block renderers
- **Render.Blocks.Document**: Document structure renderers 
- **Render.Blocks.Interactive**: Interactive element renderers

### Supporting Modules

- **Render.Attributes**: Unified attribute handling
- **Render.Settings**: Rendering configuration
- **Render.Indentation**: Indentation utilities
- **Render.Expression**: Expression rendering

## Extending the System

### Adding New Block Types

1. Add a new variant to the appropriate category in `BlockType.elm`
2. Create a renderer function in the appropriate module (Text.elm, Container.elm, etc.)
3. Register the renderer in the module's `registerRenderers` function

Example:

```elm
-- In BlockType.elm, add to TextBlockType
type TextBlockType
    = Indent
    | Center
    | Quotation
    | NewBlockType  -- Add your new block type here

-- In Blocks/Text.elm
newBlockRenderer : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
newBlockRenderer count acc settings attr block =
    -- Your rendering implementation

-- Register the renderer
registerRenderers : BlockRegistry -> BlockRegistry
registerRenderers registry =
    Render.BlockRegistry.registerBatch
        [ ( "indent", indented )
        , ( "center", centered )
        , ( "newBlock", newBlockRenderer )  -- Add your renderer here
        ]
        registry
```

## Registry Pattern

The system uses a registry pattern allowing renderers to be registered and looked up dynamically:

- `BlockRegistry`: A dictionary mapping block names to renderer functions
- Each specialized module registers its renderers
- OrdinaryBlock looks up the appropriate renderer for a given block type

This approach makes it easy to add new block types without modifying the core rendering logic.