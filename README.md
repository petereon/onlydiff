# onlydiff

_"The dream of PR reviewers everywhere"_

— Vogue

## Elevator pitch

Stop creating massive formatting diffs. Format only the lines you actually changed, keep your diffs clean, and your code reviewers happy.

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
