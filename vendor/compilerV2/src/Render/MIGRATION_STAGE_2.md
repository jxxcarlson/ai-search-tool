# Render Module - Stage 2 Migration Plan

## Overview

Stage 1 migration created a compatibility layer allowing the new architecture to coexist with the old one. Stage 2 involves directly migrating the codebase to use the new modules, gradually replacing the compatibility layer.

## Migration Steps

### 1. Update Main Entry Points (High Priority)

The first step is to update the primary points where rendering is initiated:

- [ ] Update `ScriptaV2/Compiler.elm` to use `Render.Tree2` directly
- [ ] Replace compatibility layer usage with direct imports
- [ ] Verify main document rendering still works

### 2. Replace OrdinaryBlock Usage (Medium Priority)

- [ ] Identify all imports of `Render.OrdinaryBlock`
- [ ] Replace them with `Render.OrdinaryBlock2`
- [ ] Update function calls if signatures have changed

### 3. Replace Tree Usage (Medium Priority)

- [ ] Identify all imports of `Render.Tree`
- [ ] Replace them with `Render.Tree2`
- [ ] Update function calls if signatures have changed

### 4. Replace With Final Modules (Low Priority)

- [ ] Rename `Tree2.elm` to `Tree.elm` (after all references are updated)
- [ ] Rename `OrdinaryBlock2.elm` to `OrdinaryBlock.elm`
- [ ] Remove "2" from any other module names
- [ ] Remove compatibility modules when no longer needed

### 5. Documentation (Low Priority)

- [ ] Document new architecture in a README file
- [ ] Create module documentation for each new component
- [ ] Provide examples of how to extend with new block types

## Fallback Plan

If problems occur during migration:
- Use compatibility layer longer for problematic components
- Roll back specific changes that cause issues
- Maintain dual implementation if necessary

## Testing Strategy

After each step:
- Compile the codebase to verify no errors
- Test document rendering with various block types
- Verify output stays consistent during migration

## Timeline

- High priority items: Immediate focus
- Medium priority items: After high priority items are stable
- Low priority items: Final cleanup phase