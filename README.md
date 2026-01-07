# onlydiff

Wraps formatters to only format lines you actually changed, keeping untouched code unformatted.

## Usage

```bash
onlydiff <command> [args...]

# Examples
onlydiff black myfile.py
onlydiff prettier --write src/
onlydiff gofmt -w .
```

## How It Works

1. Captures which lines you modified (via `git diff`)
2. Runs your formatter command
3. Filters formatter output to only keep changes overlapping your modifications
4. Applies the filtered patch

## Requirements

- [Babashka](https://github.com/babashka/babashka)
- Git repository with unstaged changes
