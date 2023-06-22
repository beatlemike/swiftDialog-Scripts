#!/bin/bash

####################################################################################################
#
#   swiftDialog Choose Jamf Site Mini
#   https://github.com/beatlemike/swiftDialog-Scripts
#
#   Purpose: Choose or change a Site in Jamf w/o installing swiftDialog or Pausing Jamf Check-in
#
####################################################################################################
#
# HISTORY
#
# Version 0.0.1, 22-June-2023, Mike Fredette (@beatlemike)
# - Original version
#
####################################################################################################


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# API information
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

apiURL="$4"
apiUser="$5"
apiPass="$6"


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# List sites (values comma-delimited) and save as xml
# - $8 and $9 can be used as dialog variables (--blurscreen, --quitkey x, etc)
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

Site=$(dialog $8 $9 --button1text "Choose Site" --button2text "Cancel" --selecttitle "Jamf Pro Site:" --selectvalues "$7" | grep "SelectedOption" | awk -F " : " '{print $NF}' | tr -d '"')

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
# Get the computer serial number
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

SerialNumber=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Serial Number (system)" | awk '{print $4}')

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Update/change the Site for the computer
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

curl -sfku "$5":"$6" "$4/JSSResource/computers/serialnumber/${SerialNumber}/subset/general" -T /tmp/Set_Site.xml -X PUT
sleep 5