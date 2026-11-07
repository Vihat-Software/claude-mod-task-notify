#!/usr/bin/env bash
# task-notify: desktop notification for Claude Code hooks (Notification, Stop).
# Usage: notify.sh <finished|needs-input>
# Skip per repo: create <repo>/.claude/no-notify  (or disable the plugin via enabledPlugins).
# Skips when the source app is already frontmost; TASK_NOTIFY_ALWAYS=1 disables that.
# Env: TASK_NOTIFY_SOUND=0 disables sound; TASK_NOTIFY_BUNDLE_ID overrides the macOS app to focus.
# Icon: banner shows the source app's logo (macOS, via -sender). Per-repo custom image:
#   <repo>/.claude/notify-icon.png  (or TASK_NOTIFY_ICON=/path/to/image.png)

kind="${1:-finished}"
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"

cat >/dev/null 2>&1 <&0 || true   # drain hook JSON from stdin

[ -e "$project_dir/.claude/no-notify" ] && exit 0

repo="$(basename "$project_dir")"
title="Claude Code · $repo"
case "$kind" in
  needs-input) msg="Needs your input"; sound="Glass" ;;
  *)           msg="Task finished";    sound="Hero" ;;
esac
[ "${TASK_NOTIFY_SOUND:-1}" = "0" ] && sound=""

mac_bundle_id() {
  [ -n "$TASK_NOTIFY_BUNDLE_ID" ] && { echo "$TASK_NOTIFY_BUNDLE_ID"; return; }
  case "$TERM_PROGRAM" in
    Apple_Terminal) echo com.apple.Terminal ;;
    iTerm.app)      echo com.googlecode.iterm2 ;;
    ghostty)        echo com.mitchellh.ghostty ;;
    vscode)         echo com.microsoft.VSCode ;;
    WezTerm)        echo com.github.wez.wezterm ;;
    WarpTerminal)   echo dev.warp.Warp-Stable ;;
    Hyper)          echo co.zeit.hyper ;;
    *)              echo com.apple.Terminal ;;
  esac
}

# Linux (X11 only; Wayland can't be queried -> always notifies): true if the focused
# window's process is an ancestor of this script, i.e. you're looking at the source terminal/app.
linux_source_focused() {
  command -v xdotool >/dev/null 2>&1 || return 1
  local wpid p
  wpid="$(xdotool getactivewindow getwindowpid 2>/dev/null)" || return 1
  [ -n "$wpid" ] || return 1
  p=$$
  while [ -n "$p" ] && [ "$p" -gt 1 ]; do
    [ "$p" = "$wpid" ] && return 0
    p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
  done
  return 1
}

# Windows: true if the foreground window's process is an ancestor of this shell.
win_source_focused() {
  [ "$(powershell.exe -NoProfile -Command "
    Add-Type -Namespace W -Name U -MemberDefinition '[DllImport(\"user32.dll\")] public static extern System.IntPtr GetForegroundWindow(); [DllImport(\"user32.dll\")] public static extern int GetWindowThreadProcessId(System.IntPtr h, out int p);'
    \$fg = 0; [void][W.U]::GetWindowThreadProcessId([W.U]::GetForegroundWindow(), [ref]\$fg)
    \$id = \$PID; \$hit = \$false
    while (\$id -and \$id -gt 0) {
      if (\$id -eq \$fg) { \$hit = \$true; break }
      \$proc = Get-CimInstance Win32_Process -Filter \"ProcessId=\$id\" -ErrorAction SilentlyContinue
      if (-not \$proc) { break }
      \$id = \$proc.ParentProcessId
    }
    if (\$hit) { 'yes' }" 2>/dev/null | tr -d '\r')" = "yes" ]
}

case "$(uname -s)" in
  Darwin)
    if [ "${TASK_NOTIFY_ALWAYS:-0}" != "1" ]; then
      front="$(osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true' 2>/dev/null)"
      [ -n "$front" ] && [ "$front" = "$(mac_bundle_id)" ] && exit 0
    fi
    if command -v terminal-notifier >/dev/null 2>&1; then
      bid="$(mac_bundle_id)"
      args=(-title "$title" -message "$msg" -group "claude-$repo" -activate "$bid")
      # Source app logo (e.g. VS Code). Only if that app is installed.
      [ -n "$(mdfind "kMDItemCFBundleIdentifier == '$bid'" 2>/dev/null | head -1)" ] && args+=(-sender "$bid")
      icon="${TASK_NOTIFY_ICON:-$project_dir/.claude/notify-icon.png}"
      [ -f "$icon" ] && args+=(-contentImage "$icon" -appIcon "$icon")
      [ -n "$sound" ] && args+=(-sound "$sound")
      terminal-notifier "${args[@]}" >/dev/null 2>&1
    else
      s=""; [ -n "$sound" ] && s=" sound name \"$sound\""
      osascript -e "display notification \"$msg\" with title \"$title\"$s" >/dev/null 2>&1
    fi
    ;;
  Linux)
    [ "${TASK_NOTIFY_ALWAYS:-0}" != "1" ] && linux_source_focused && exit 0
    if command -v notify-send >/dev/null 2>&1; then
      notify-send "$title" "$msg" >/dev/null 2>&1
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    [ "${TASK_NOTIFY_ALWAYS:-0}" != "1" ] && win_source_focused && exit 0
    powershell.exe -NoProfile -Command "
      Add-Type -AssemblyName System.Windows.Forms;
      \$n = New-Object System.Windows.Forms.NotifyIcon;
      \$n.Icon = [System.Drawing.SystemIcons]::Information;
      \$n.Visible = \$true;
      \$n.ShowBalloonTip(5000, '$title', '$msg', 'Info');
      Start-Sleep -Seconds 6; \$n.Dispose()" >/dev/null 2>&1 &
    ;;
esac
exit 0
