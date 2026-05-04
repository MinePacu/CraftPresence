# Safety Rules

These rules are mandatory for the CraftPresence migration tooling.

## Source repositories

- Do not modify source repositories.
- Do not push to source repositories.
- Do not delete source repositories.
- Do not rename source repositories.
- Do not archive source repositories.
- Do not change source repository visibility.
- Clone and rewrite only local copies under `../CraftPresence-migration-workspace`.

## Target repository

- Create branches and pull requests only in `MinePacu/CraftPresence-Test`.
- Do not force-push unless explicitly requested later.
- Do not import issues or comments unless explicitly requested later.
- Do not push rewritten history unless explicitly requested later.

## Excluded work

- Do not create, migrate, or edit GitHub Releases.
- Do not create, migrate, or edit GitHub Actions or CI workflows.
- Do not commit tokens, secrets, local credentials, source clones, issue exports, rewritten repositories, temporary merge repositories, or generated issue maps.

## Workspace boundary

Repository-owned files are limited to scripts, docs, and examples.

Generated migration data belongs in:

```text
../CraftPresence-migration-workspace/
```

The environment variable `CRAFTPRESENCE_MIGRATION_WORKSPACE` can point to a different external workspace if needed.

