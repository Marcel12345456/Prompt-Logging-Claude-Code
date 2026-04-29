# Claude Code Prompt Logger

Automatic logging of all Claude Code interactions per project. Each prompt and the files changed are recorded in a daily Markdown log.

## What gets logged

| Field | Example |
|-------|---------|
| Timestamp | `### 14:32:07` |
| Prompt text | `**Prompt:** Fix the login bug` |
| Project path | `**Project:** /Users/you/myapp` |
| Changed files | `- \`src/auth.ts\`` |

Logs are written to `.ai-logs/` in the project root. Each conversation session gets its own file:

```
.ai-logs/2026-04-16_a8f3k2d1.md
```

The filename contains the date and first 8 characters of the Claude session ID.

## Files

```
.claude/
  settings.json       # Hook configuration (points to log.sh)
  hooks/
    log.sh            # All logging logic (prompt, tool tracking, stop)
```

## Setup for a new project

### Step 1 — Copy the files

Copy the `.claude` folder into the root of the target project:

```bash
cp -r /path/to/source/.claude /path/to/your-project/.claude
```

Or copy only the two required files:

```bash
mkdir -p /path/to/your-project/.claude/hooks
cp .claude/settings.json /path/to/your-project/.claude/settings.json
cp .claude/hooks/log.sh  /path/to/your-project/.claude/hooks/log.sh
chmod +x /path/to/your-project/.claude/hooks/log.sh
```

### Step 2 — Verify

Open Claude Code in the project and send any prompt. Check that a file appeared in `.ai-logs/`.

## How it works

The logger uses three Claude Code hook events, all handled by a single script:

| Hook | Trigger | What it does |
|------|---------|-------------|
| `UserPromptSubmit` | User sends a prompt | Creates log entry with timestamp and prompt text |
| `PostToolUse` | Claude edits/writes a file | Records the file path |
| `Stop` | Claude finishes responding | Flushes file changes into the log entry and closes it |

All three are required. Removing one will break the logging flow.

## Customization

### Change the log directory - not recommended in shared projects

In [.claude/hooks/log.sh](.claude/hooks/log.sh), find `log_dir="$cwd/.ai-logs"` and change `.ai-logs` to your preferred directory name.

> **Shared projects:** keep `.ai-logs/` as-is. When multiple people work in the same checkout, every teammate's hook must write to the same folder so logs land in one place and `.gitignore` keeps them all out of version control. Renaming the folder for one person breaks that contract.

---

## Add the logger to CLAUDE.md

If you want Claude to append a one-line summary after code changes, add this to your project's `CLAUDE.md`:

```markdown
## Prompt-Logging

After completing code changes, append exactly one line to the open entry
in today's log file in `.ai-logs/`:

**Summary:** [One sentence describing what was done]
```

---

## Uninstall

Remove the hook entries from `.claude/settings.json` (or delete the entire `.claude` folder) and optionally delete `.ai-logs/`.
