#!/bin/zsh

####################################################################################################
#
#   swiftDialog Choose Jamf Site (Jamf API)
#   https://github.com/beatlemike/swiftDialog-Scripts
#
#   Purpose: Choose or change a Site in Jamf
#
####################################################################################################
#
# HISTORY
#
# Version 0.0.1, 06.16.2023, Mike Fredette (@beatlemike)
# - Original version
# Version 0.0.2, 06.21.2023, Mike Fredette (@beatlemike)
# - Added Jamf Variables
# Version 0.0.3, 06.22.2023, Mike Fredette (@beatlemike)
# - Fixed Jamf Variables
# - Cleaned xml output
# - Added $8 and $9 variables dor swiftDialog (--blurscreen, --quitkey x, etc)
# Version 1.0.0, 04.02.2024, Mike Fredette (@beatlemike)
# - Changed to zsh
# - Added Jamf API Bearer Token
# - Removed launchdaemon commands
#
####################################################################################################


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Global Variables
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Jamf Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

JSS_URL="$4"                                # Parameter 4: Jamf URL (eg: https://ORG.jamfcloud.com)
apiUsername="$5"					        # Parameter 5: Jamf api username (eg: USERNAME)
apiPassword="$6"                            # Parameter 6: Jamf api password (eg: PASSWORD)

sites="$7" 									#List of Sites (Comma-Delimited)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Get Bearer Token
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

authToken=$(curl -s -u "$apiUsername:$apiPassword" "$JSS_URL/api/v1/auth/token" -X POST)
api_token=$(echo "$authToken" | plutil -extract token raw - -o -)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Get the computer serial number
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

SerialNumber=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Serial Number (system)" | awk '{print $4}')

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# List sites (values comma-delimited) for selection and save as xml
# $8 and $9 variables dor swiftDialog (--blurscreen, --quitkey x, etc)
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

Site=$(dialog $8 $9 --button1text "Choose Site" --button2text "Cancel" --selecttitle "Jamf Pro Site:" --selectvalues "$sites" | grep "SelectedOption" | awk -F " : " '{print $NF}' | tr -d '"')

## Create xml
cat << EOF > /tmp/Set_Site.xml
<computer>
  <general>
    <site>
     <name>$Site</name>
    </site>
  </general>
</computer>
EOF

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Update/change the Site for the computer
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

curl -s -H "accept: text/xml" -H "Authorization: Bearer $api_token" "$JSS_URL/JSSResource/computers/serialnumber/${SerialNumber}/subset/general" -T /tmp/Set_Site.xml -X PUT
sleep 5