#!/bin/zsh

cat > /Library/LaunchDaemons/com.beatlemike.test.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.beatlemike.test</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-c</string>
    <string>/usr/local/jamf/bin/jamf policy -trigger rumdeferral</string>
  </array>
  <key>StartInterval</key>
  <integer>60</integer>
</dict>
</plist>
EOF

# Set correct permissions for the plist file
chown root:wheel /Library/LaunchDaemons/com.beatlemike.test.plist
chmod 644 /Library/LaunchDaemons/com.beatlemike.test.plist

# Wait for 2 seconds
sleep 2

# Load the Launch Daemon.
launchctl load -w /Library/LaunchDaemons/com.beatlemike.test.plist
launchctl start com.beatlemike.test