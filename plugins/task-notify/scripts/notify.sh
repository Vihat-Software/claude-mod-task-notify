#!/usr/bin/env bash
# task-notify: desktop notification for Claude Code hooks (Notification, Stop).
# Usage: notify.sh <finished|needs-input>
# Skip per repo: create <repo>/.claude/no-notify  (or disable the plugin via enabledPlugins).
# Env: TASK_NOTIFY_SOUND=0 disables sound; TASK_NOTIFY_BUNDLE_ID overrides the macOS app to focus.

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

case "$(uname -s)" in
  Darwin)
    if command -v terminal-notifier >/dev/null 2>&1; then
      args=(-title "$title" -message "$msg" -group "claude-$repo" -activate "$(mac_bundle_id)")
      [ -n "$sound" ] && args+=(-sound "$sound")
      terminal-notifier "${args[@]}" >/dev/null 2>&1
    else
      s=""; [ -n "$sound" ] && s=" sound name \"$sound\""
      osascript -e "display notification \"$msg\" with title \"$title\"$s" >/dev/null 2>&1
    fi
    ;;
  Linux)
    if command -v notify-send >/dev/null 2>&1; then
      notify-send "$title" "$msg" >/dev/null 2>&1
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
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
