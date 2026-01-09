# onlydiff

_"The dream of PR reviewers everywhere"_

— PR reviewers everywhere

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

> [!NOTE]
> The tool defaults to applying the entire hunk from formatter output if any line in that hunk intersects user-modified lines. This might result in some lines you didn't directly touch being changed. While imperfect, it's surefire - using heuristics to select only the lines you directly touched would be error-prone.

<details>

<summary>Details for the curious</summary>

### High-level workflow
1. Determine which files are changed:
   - Runs `git diff --name-only HEAD` to list changed files.
2. Capture which lines the user changed:
   - For each file, runs `git diff -U0 HEAD -- <file>` and parses the diff hunks to get the set of "user-touched" line numbers (the `+new,cnt` ranges).
3. Run the transformer:
   - Runs the given transformer command (e.g. `black`, `prettier`) over the repo/files.
4. Generate a patch between original and transformed file:
   - Writes original and transformed content to temporary files and runs `diff -U0 old new` to produce a unified diff with zero context.
5. Parse the formatter diff and filter hunks:
   - The script parses each hunk header `@@ -old,cnt +new,cnt @@` and constructs a `range` set for the `+new` side (the lines in the transformed file).
   - For each hunk it collects the hunk `content` (the lines starting with `+`, `-`, or ` `).
   - It checks whether the hunk's `range` intersects the set of `allowed-lines` (the user-touched lines).
   - If the intersection is non-empty, the hunk is selected and a replacement record is built using the hunk's added lines (filtering `+` lines and stripping the leading `+`).
6. Apply selected hunks back into the original file:
   - Replacements are sorted in descending order by `start` to avoid index shifting.
   - Each replacement is applied to the original file's lines by slicing `before` and `after` subvecs and concatenating `before + lines + after`.
   - Index math: insertion uses `idx = start`; modification uses `idx = start - 1`. Indices are clamped to valid bounds.
7. Write the final file:
   - The resulting lines are joined with `\n` and the file is overwritten (with a trailing newline appended).

### Important implementation details that affect behaviour
- `-U0` is used both when capturing the user-touched lines (via `git diff -U0`) and when generating the formatter diff (`diff -U0`). This removes surrounding context from the diffs, which keeps hunks tight.
- Hunk selection is coarse: the script selects an entire hunk if any line in that hunk's `+new` range intersects `allowed-lines`. It does not pick individual changed lines within a hunk — it applies the whole hunk's replacement (i.e., all added lines from that hunk).
- The added lines used for the replacement are taken from the hunk's `+` lines (lines beginning with `+`) after stripping the leading `+`.
- Because whole hunks are applied when intersecting, context or adjacent lines included in the same hunk (even with `-U0` hunks can still be multi-line) will be changed if they happen to be in the same hunk as a touched line.
- Replacements are applied from highest start to lowest to avoid index shifting mistakes.
- There are safety clamps on indices to avoid out-of-bounds slicing.

### Net effect (what you see in diffs)
- `onlydiff` will generally limit changes to local regions where the formatter actually changed content, and it avoids applying formatter edits to files you didn't touch at all.
- However, when a formatter produces a multi-line hunk that overlaps your touched lines, `onlydiff` applies the entire hunk. That means some lines you didn't directly touch (but which are part of the same formatter hunk) may still be edited.
- The use of `-U0` minimizes but does not eliminate this — the script's unit of application is a hunk, not an individual changed line.

</details>


## Requirements

- [Babashka](https://github.com/babashka/babashka)
- Git repository with unstaged changes
