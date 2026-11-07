# claude-mod-task-notify

Claude Code plugin: desktop notification when a session **finishes** or **needs permission / input**.
Clicking the banner focuses your terminal (macOS with `terminal-notifier`).

## Install (any device)

```
/plugin marketplace add Vihat-Software/claude-mod-task-notify
/plugin install task-notify@claude-mod-task-notify
```

macOS click-to-focus: `brew install terminal-notifier` (falls back to `osascript`, no click action).
Linux: needs `notify-send`. Windows: Git Bash / WSL with `powershell.exe`.

## Toggle per repo

Off for one repo (`<repo>/.claude/settings.local.json`, or `settings.json` to share with the team):

```json
{ "enabledPlugins": { "task-notify@claude-mod-task-notify": false } }
```

Or keep it installed and silence a repo with an empty file: `touch <repo>/.claude/no-notify`.

## Options

- `TASK_NOTIFY_SOUND=0` — no sound
- `TASK_NOTIFY_BUNDLE_ID=<bundle id>` — macOS app to focus on click (auto-detected from `$TERM_PROGRAM`)

## Icon

On macOS the banner shows the logo of the app you're running in (VS Code, iTerm, Ghostty, …) via `terminal-notifier -sender`.

Custom image per repo: put `<repo>/.claude/notify-icon.png` in the repo (shown as the banner image), or set `TASK_NOTIFY_ICON=/path/to/image.png`.
Note: on recent macOS the small app icon can't be replaced, so a custom image appears as the attachment on the right.
