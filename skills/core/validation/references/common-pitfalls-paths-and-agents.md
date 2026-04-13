# Common Pitfalls — Paths And Agents

This reference expands the common validation failures around path safety, portability, display metadata, and command collision handling.

## Pitfall 5: Parent Directory Traversal

### Problem

Plugin paths use `../` to reference files outside the plugin directory.

### Detection

Any plugin path field containing `../` fails validation.

### Fix

Keep paths rooted inside the plugin with an explicit `./` prefix.
Copy or symlink shared content into the plugin instead of traversing upward.

## Pitfall 6: Absolute Paths

### Problem

Hardcoded absolute filesystem paths break portability across machines and users.

### Detection

Flag hook commands, plugin paths, or markdown references that start with `/`.

### Fix

Use the plugin-root variable for hook commands and `./...` for plugin-local paths.

### Common Sources

| Source | Detection Pattern | Fix |
|---|---|---|
| Hook script paths | Starts with `/` in the hook `command` field | Use the plugin-root variable plus `scripts/...` |
| Plugin manifest paths | Starts with `/` in manifest path fields | Use `./...` |
| Markdown references | Starts with `/Users/` or `/home/` | Convert to a relative or repo-root reference |

## Pitfall 7: Missing Agent `color`

### Problem

Agent frontmatter omits `color`, which is required for terminal display.

### Detection

Look for agent frontmatter with `name`, `description`, and `model`, but no `color`.

### Fix

Add one of the supported colors such as `blue`, `cyan`, `green`, `yellow`, `magenta`, or `red`.

## Pitfall 8: Built-In Command Name Collision

### Problem

A command would collide with a built-in Claude Code command if it relied on a bare filename instead of namespacing.

### Detection

Commands like `plan`, `review`, or `init` are only safe when their declared `name` is namespaced.

### Fix

Set the required path-derived namespaced `name` on every command file.
That makes `/dev:plan` safe where `/plan` would collide.

### Prevention Strategy

1. Always derive command names from the file path.
2. Use `name: {module}` only for top-level router commands.
3. Treat the built-in command list as a verification aid rather than a branching rule.
4. Reject legacy prefixes such as `ouroboros:` during validation.
