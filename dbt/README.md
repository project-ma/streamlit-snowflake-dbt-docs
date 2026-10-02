# dbt/ — your dbt project goes here

Copy your existing dbt project into this folder so that `dbt_project.yml`
sits directly in `dbt/`:

```
dbt/
  dbt_project.yml        <- required, at this level
  profiles.yml           <- provided; edit to match your project
  packages.yml           (if you use packages)
  models/
  macros/
  seeds/
  snapshots/
  tests/
  analyses/
```

Checklist:

1. **Profile name** — the top-level key in `profiles.yml` (`my_project`) must
   equal `profile:` in your `dbt_project.yml`.
2. **Profile target** — `prod` must exist in `profiles.yml`; it's what the
   docs procedure runs with (`--target prod`).
3. **Role / warehouse / database / schema** in `profiles.yml` — use the
   same values as your current production profile.
4. **Don't copy** `target/`, `dbt_packages/`, `logs/` — they're gitignored and
   Snowflake rebuilds them.
5. **Packages** — if you have `packages.yml`, keep the external access
   integration in `sql/03_dbt_project.sql`; otherwise remove it there.
