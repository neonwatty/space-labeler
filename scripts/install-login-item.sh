#!/bin/bash
# Install SpaceLabeler as a login item via LaunchAgent.
# Ad-hoc signed apps can't use SMAppService.mainApp.register() — it returns
# .enabled with no error but the BackgroundTaskManagement daemon silently
# refuses to persist the record. A LaunchAgent plist is the supported
# workaround for unsigned / ad-hoc signed bundles.

set -euo pipefail

LABEL="com.jeremywatt.SpaceLabeler"
APP_PATH="${HOME}/Applications/SpaceLabeler.app"
EXEC_PATH="${APP_PATH}/Contents/MacOS/SpaceLabeler"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"

if [ ! -x "${EXEC_PATH}" ]; then
  echo "error: ${EXEC_PATH} not found or not executable" >&2
  echo "run 'make install' first" >&2
  exit 1
fi

mkdir -p "${HOME}/Library/LaunchAgents"

cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${EXEC_PATH}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
EOF

# Kill any unmanaged instance started by `open` during `make install`
# so we don't end up with one launchd-managed process alongside an orphan.
pkill -x SpaceLabeler 2>/dev/null || true

# Unload if already loaded, then load fresh.
launchctl unload "${PLIST_PATH}" 2>/dev/null || true
launchctl load "${PLIST_PATH}"

echo "installed LaunchAgent: ${PLIST_PATH}"
echo "SpaceLabeler will launch at login."
echo "to uninstall: launchctl unload \"${PLIST_PATH}\" && rm \"${PLIST_PATH}\""
