# Cleanup After Migration

Now that the migration is complete, the following files can be safely removed:

## Temporary and Backup Files
- `OrdinaryBlock_new.elm` - Temporary file from migration
- `Tree_new.elm` - Temporary file from migration
- Any `*_backup.elm` files that may be created during the migration

## Compatibility Layer
Now that all modules use the new architecture directly, the compatibility layer can be removed:
- `Compatibility/OrdinaryBlock.elm`
- `Compatibility/Tree.elm`
- The entire `Compatibility/` directory

## Test Files
These test files were created just for the migration and are no longer needed:
- `TestCompile.elm`
- `TestCompiler.elm`
- `TestMigration.elm`
- `TestRender.elm`
- `SimpleTest.elm` (if present)

## Scripts
These scripts were used to automate parts of the migration:
- `rename_modules.sh`
- `fix_imports.sh`

## Documentation
Once you've reviewed and integrated the information, these migration-specific documentation files can be removed:
- `MIGRATION.md`
- `MIGRATION_STAGE_2.md`
- `CLEANUP.md` (this file)

Consider keeping:
- `README.md` - Contains useful documentation about the architecture

## Cleanup Command

```bash
# Run this to clean up the migration files
rm OrdinaryBlock_new.elm Tree_new.elm
rm -rf Compatibility/
rm TestCompile.elm TestCompiler.elm TestMigration.elm TestRender.elm SimpleTest.elm
rm rename_modules.sh fix_imports.sh
rm MIGRATION.md MIGRATION_STAGE_2.md
# Keep README.md and MIGRATION_COMPLETE.md for documentation
```

Note: Before removing any files, ensure that the application compiles and works correctly to verify the migration was successful.