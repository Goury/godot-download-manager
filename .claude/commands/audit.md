## GDScript Style Audit & Docs Sync

Perform a two-part audit of the download manager plugin:

### Part 1: Strict Typing Audit

Scan ALL `.gd` files under `addons/download_manager/` for violations of the project's strict typing rules:

1. **Untyped variables** — Every `var` must have an explicit type: `var x: Type = value`. Flag any `var x = ...` or `var x := ...` (`:=` inference is banned).
2. **Untyped constants** — Every `const` must have an explicit type: `const X: Type = value`. Flag any `const X = ...` or `const X := ...`.
3. **Untyped loop variables** — Every `for` loop must type its variable: `for item: Type in collection:`. Flag any `for item in collection:`.
4. **Missing return types** — Every function must declare a return type: `func name() -> ReturnType:`. Flag any `func name():` without `-> ...`. This includes `-> void`.
5. **Untyped function parameters** — Every parameter must have a type: `func name(x: Type)`. Flag any `func name(x)` without `: Type`.

For each violation found:
- Print the file path, line number, and the offending line.
- Fix it in place with the correct explicit type.

If no violations are found, confirm that all files pass.

### Part 2: README Docs Sync

Read the current state of ALL source files under `addons/download_manager/` and compare against `addons/download_manager/README.md`. Update the README to accurately reflect the current code:

1. **Features table** — Add/remove/update features to match current capabilities (e.g., retry support, redirect following, hash verification, partial file cleanup).
2. **API reference** — Ensure all public methods, signals, properties, and their signatures match the actual code. Check DownloadProgress, DownloadGroup, DLClient, and any other public classes.
3. **JSON Manifest Format** — Ensure all supported fields are documented (including `path` if supported).
4. **Error Handling** — Update error table and recovery instructions to match current behavior.
5. **Timeout Configuration** — Verify timeout constants and their locations match the code.
6. **Limitations** — Remove limitations that have been fixed. Add any new limitations.
7. **Workflow Diagrams** — Update if the flow has changed.
8. **Constants & config** — Document any new constants (MAX_RETRIES, MAX_REDIRECTS, etc.).

Do NOT rewrite sections that are already accurate. Only update what has actually changed.
Also update the root `README.md` if its feature list or descriptions are now outdated.
