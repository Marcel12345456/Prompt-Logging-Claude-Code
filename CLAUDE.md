# Project Rules for Claude Code

## Prompt Logging

Logging is handled automatically by hooks. The hook writes on each prompt:
- Timestamp, prompt text, project path
- Changed files (paths only)

**Your only task:** After completing code changes, append exactly one line to the open entry in today's log file:

```
**Summary:** [One sentence describing what was done]
```

Write nothing else — no date, no file list, no numbering. The hook handles the rest.

## General

- Always respond in English, regardless of the prompt language.
