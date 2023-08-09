#!/bin/zsh

####################################################################################################
#
# Deferral via swiftDialog
#
####################################################################################################
#
# HISTORY
#
#   Version 1.0.0, 08.03.2023, Mike Fredette (@beatlemike)
#   Version 1.0.1, 08.04.2023, Mike Fredette (@beatlemike)
#	- Added Validation and Install for swiftDialog Installation.
#
####################################################################################################

####################################################################################################
#
# Global Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Script Version and Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

scriptVersion="1.0.0"
deferredAction="${4:-"trigger"}"							                       	        # Parameter 4: Deferred Action [This is the Jamf trigger you want to eventually run. (i.e. rumgui)]
deferralDuration="${5:-"3600"}"                                           	        		# Parameter 5: Deferral Duration [How long until a deferral expires? Value in seconds. 3600 (default)]
deferralMaximum="${6:-"3"}"                                           		        		# Parameter 6: Deferral Maximum [How many deferrals until you no longer offer them?]
deferralDate="${7:-""}"                                           		        			# Parameter 7: Deferral Date [This is a unix epoch time value (https://www.epochconverter.com/) Can be empty.]
deferralicon="${8:-"aa63d5813d6ed4846b623ed82acdd1562779bf3716f2d432a8ee533bba8950ee"}"    	# Parameter 8: Icon Hash [This is the Jamf hash for the icon you would like to show in your deferral message (i.e. be01fb84c02c4427d7a530b0404b4b80824743467c2b97bbaf6f362a63fdaf2d)]
deferralTitle="${9:-"Title"}"                              						        	# Parameter 9: Deferral Window Title [This is what the Deferral is for. (i.e. Adobe Updates Need To Be Run)]
deferralPrompt="${10:-"Message"}"                                                          	# Parameter 10: Deferral Prompt Message [This is the Deferral message. (i.e. Adobe Creative Cloud needs to update your computer. You will be given seven deferrals.)]
deferralName="${11:-"deferral"}"             											    # Parameter 11: Deferral Name [This will be used by the launchdaemon file for it's name as well as the deferral trigger name (i.e. rumdeferral)]

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Paths
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Specify the destination path for swiftDialog
dialogPath="/usr/local/bin/dialog"
# Specify the destination path for PlistBuddy
pBuddy="/usr/libexec/PlistBuddy"
# Specify the destination path for the launch daemon
plist_path="/Library/LaunchDaemons/com.beatlemike.$deferralName.plist"
# Specify the destination path for the deferral configuration
deferralPlist="/Library/Application Support/Jamf/com.beatlemike.$deferralName.plist"
# Specify the destination path for the deferral icon hash from famf
deferralIconPrefixUrl="https://ics.services.jamfcloud.com/icon/hash_"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate/install swiftDialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogCheck() {

    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
    
    # Expected Team ID of the downloaded PKG
    expectedDialogTeamID="PWA5E9TQ59"
    
    # Check for Dialog and install if not found
    if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then
        
        echo "PRE-FLIGHT CHECK: Dialog not found. Installing..."
        
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
            echo "PRE-FLIGHT CHECK: swiftDialog version ${dialogVersion} installed; proceeding..."
            
        else
            
            # Display a so-called "simple" dialog if Team ID fails to validate
            osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "'${scriptFunctionalName}': Error" buttons {"Close"} with icon caution'
            exitCode="1"
            quitScript
            
        fi
        
        # Remove the temporary working directory when done
        /bin/rm -Rf "$tempDirectory"
        
    else
        
        echo "PRE-FLIGHT CHECK: swiftDialog version $(/usr/local/bin/dialog --version) found; proceeding..."
        
    fi
    
}

if [[ ! -e "/Library/Application Support/Dialog/Dialog.app" ]]; then
    if [ ${interactiveMode} -gt 0 ]; then
        dialogCheck
    fi
else
    echo "PRE-FLIGHT CHECK: swiftDialog version $(/usr/local/bin/dialog --version) found; proceeding..."
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# User Configuration Functions
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function check_the_things()
{
    # If "check the things" exits true, then the script continues on. If it exits false (non-zero exit/return code) then
    # the thing doesn't need to happen and the script exits.
    if true; then
        log_message "Conditions met. Script will continue"
    else
        cleanup_and_exit 0 "Script is not needed. Exiting"
    fi
}

function do_the_things()
{
    # This is executed when the user consents by clicking "OK" on the Dialog window.
    jamf policy -trigger $deferredAction

    # If True, set the deferral count back to 0.
    $pBuddy -c "Set DeferralCount 0" $deferralPlist
}

function dialog_prompt_with_deferral()
{
    "$dialogPath" \
    --title "$deferralTitle" \
    --message "$deferralPrompt" \
    --icon "$deferralIconPrefixUrl$deferralicon" \
    --button2text "Defer" \
}

function dialog_prompt_no_deferral()
{
    "$dialogPath" \
    --title "$deferralTitle" \
    --message "$deferralPrompt" \
    --icon "$deferralIconPrefixUrl$deferralicon" \
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Core Functions
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Log
function log_message()
{
    echo "$(date): $@"
}

# Argument 1 is the exit code 
# Argument 2 is an optional log message
function cleanup_and_exit()
{
    log_message "${2}"
    exit "${1}"
}

function verify_config_file()
{
    if $pBuddy -c "Add Verification string Success" "$deferralPlist"  > /dev/null 2>&1; then
        $pBuddy -c "Delete Verification string Success" "$deferralPlist" > /dev/null 2>&1
    else
        cleanup_and_exit 1 "ERROR: Cannot write to the deferral file: $deferralPlist"
    fi

    verify_deferral_value "ActiveDeferral"
    verify_deferral_value "DeferralCount"

}

function verify_deferral_value()
{
    if ! $pBuddy -c "Print :$1" "$deferralPlist"  > /dev/null 2>&1; then
        $pBuddy -c "Add :$1 integer 0" "$deferralPlist"  > /dev/null 2>&1
    fi

}

function check_for_active_deferral()
{
    # This function checks if there is an active deferral present. If there is, then it exits quietly.

    # Get the current deferral value. This will be 0 if there is no active deferral
    currentDeferral=$($pBuddy -c "Print :ActiveDeferral" "$deferralPlist")

    if [ "$unixEpochTime" -lt "$currentDeferral" ]; then
        cleanup_and_exit 0 "Active deferral found. Exiting"
    else
        log_message "No active deferral."
        # We'll delete the "human readable" deferral date value, if it exists.
        $pBuddy -c "Delete :HumanReadableDeferralDate" "$deferralPlist"  > /dev/null 2>&1
    fi
}


function execute_deferral()
{
    # This is where we define what happens when the user chooses to defer

    # Setting deferral variables
    deferralDateSeconds=$((unixEpochTime + deferralDuration ))
    deferralDateReadable=$(date -j -f %s $deferralDateSeconds)
    deferralCount=$(( deferralCount + 1 ))

    # Writing deferral values to the plist
    $pBuddy -c "Set ActiveDeferral $deferralDateSeconds" $deferralPlist
    $pBuddy -c "Set DeferralCount $deferralCount" $deferralPlist
    $pBuddy -c "Add :HumanReadableDeferralDate string $deferralDateReadable" "$deferralPlist"  > /dev/null 2>&1
    
    # Deferral has been processed. Exit cleanly.
    cleanup_and_exit 0 "User chose deferral $deferralCount of $deferralMaximum. Deferral date is $deferralDateReadable"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Script Starts Here
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

verify_config_file

# Get the current date in seconds (unix epoc time)
unixEpochTime=$(date +%s)

check_for_active_deferral

check_the_things

# Get the current deferral count
deferralCount=$($pBuddy -c "Print :DeferralCount" $deferralPlist)


# Check if Deadline has been set, and if we are now past it
if [ ! -z "$deadlineDate" ] && [ "$deadlineDate" -lt "$unixEpochTime" ]; then
    # Deadline has been configured, and we're past it.
    allowDeferral="false"
# Check if the number of deferrals used is greater than the maximum allowed
elif [ "$deferralCount" -ge "$deferralMaximum" ]; then
    allowDeferral="false"
else
    # Deadline isn't past and the deferral count hasn't been exceeded, so we'll allow deferrals.
    allowDeferral="true"
fi

# If we're allowing deferrals, then
if [ "$allowDeferral" = "true" ]; then
    # Prompt the user to ask for consent. If it exits 0, they clicked OK and we'll do the things
    if dialog_prompt_with_deferral; then
        # Here is where the actual things we want to do get executed
        do_the_things
        # Capture the exit code of our things, so we can exit the script with the same exit code
        thingsExitCode=$?
        cleanup_and_exit $thingsExitCode "Things were done. Exit code: $thingsExitCode"
    else
        execute_deferral
    fi
else
    # We are NOT allowing deferrals, so we'll continue with or without user consent
    dialog_prompt_no_deferral
    do_the_things
    # Capture the exit code of our things, so we can exit the script with the same exit code
    thingsExitCode=$?
    cleanup_and_exit $thingsExitCode "Things were done. Exit code: $thingsExitCode"
fi