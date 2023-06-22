﻿#!/bin/bash

####################################################################################################
#
#   swiftDialog Choose Jamf Site
#   https://github.com/beatlemike/swiftDialog-Scripts
#
#   Purpose: Choose or change a Site in Jamf
#
####################################################################################################
#
# HISTORY
#
# Version 0.0.1, 16-June-2023, Mike Fredette (@beatlemike)
#   Original version
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Pre-flight Check: Turn off `jamf` binary check-in
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

launchctl unload /Library/LaunchDaemons/com.jamfsoftware.task.1.plist


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Pre-flight Check: Validate / install swiftDialog (Thanks big bunches, @acodega!)
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogCheck() {

    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

    # Expected Team ID of the downloaded PKG
    expectedDialogTeamID="PWA5E9TQ59"

    # Check for Dialog and install if not found
    if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then

        # Create temporary working directory
        workDirectory=$( /usr/bin/basename "$0" )
        tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )

        # Download the installer package
        /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"

        # Verify the download
        teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')

        # Install the package if Team ID validates
        if [[ "$expectedDialogTeamID" == "$teamID" ]]; then

            /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
            sleep 2
            dialogVersion=$( /usr/local/bin/dialog --version )

        else

            # Display a so-called "simple" dialog if Team ID fails to validate
            osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "Setup Your Mac: Error" buttons {"Close"} with icon caution'
            completionActionOption="Quit"
            exitCode="1"
            quitScript

        fi

        # Remove the temporary working directory when done
        /bin/rm -Rf "$tempDirectory"

    fi

}

if [[ ! -e "/Library/Application Support/Dialog/Dialog.app" ]]; then
    dialogCheck
fi


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# API information
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

apiURL="$5"
apiUser="$6"
apiPass="$7"


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# List sites (values comma-delimited)
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

## Get a list of all sites and their IDs (values comma-delimited)
Site=$(dialog --blurscreen --selecttitle "Jamf Pro Site:" --selectvalues "$8" | grep "SelectedOption" | awk -F " : " '{print $NF}' | tr -d '"')

## Create xml
cat << EOF > /tmp/Set_Site.xml
<computer>
  <general>
    <site>
     <id>$ID</id>
     <name>$Site</name>
    </site>
  </general>
</computer>
EOF

## Get the computer serial number
SerialNumber=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Serial Number (system)" | awk '{print $4}')

## Update/change the Site for the computer
curl -sfku "$6":"$7" "$5/JSSResource/computers/serialnumber/${SerialNumber}/subset/general" -T /tmp/Set_Site.xml -X PUT
sleep 5

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Post-flight Check: Turn on `jamf` binary check-in
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

launchctl load /Library/LaunchDaemons/com.jamfsoftware.task.1.plist