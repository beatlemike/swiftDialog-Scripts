#!/bin/zsh

####################################################################################################
#
# Adobe RUM via swiftDialog
#
####################################################################################################
#
# HISTORY
#
#   Version 1.0.0, 07.17.2023 (Happy 68th Birthday Disneyland!), Mike Fredette (@beatlemike)
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
scriptFunctionalName="Adobe Remote Update Manager"


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Various Feature Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

### Computer Variables ###
macOSVersion=$(system_profiler SPSoftwareDataType | awk '/System Version/ {print $4}')
computerName=$(scutil --get ComputerName)

### Dialog Message Variables ###
notification_message="New updates are available for your Adobe applications\n\nAll Adobe applications need to be quit before updating."
downloadinstall_message="We need to Download and Install the Adobe Application Updates on your Computer\n\nThis may take some time, depending on your internet connection..."
updatecomplete_message="Update installation complete."
adobe_icon="/Applications/Utilities/Adobe Creative Cloud/ACC/Creative Cloud.app"

### Paths & Logs ###
dialogPath="/usr/local/bin/dialog"
logPath="/Library/Application Support/CustomAdobeUpdater/"
rumlog="$logPath/AdobeRUMUpdatesLog.log" # mmmmmm, rum log
rum="/usr/local/bin/RemoteUpdateManager"
jamf_bin="/usr/local/bin/jamf"
installRUM="${4}" #set RUM install trigger
rumupdate="/usr/local/bin/RemoteUpdateManager --action=install"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# PreFlight Checks
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogCheck() {
    # Check if Dialog is installed
    if ! command -v dialog > /dev/null 2>&1; then
    echo "Dialog is not installed. Installing..."
    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
    # Download the latest release of Dialog
    curl -L "$dialogURL" -o /tmp/dialog.pkg
    # Install Dialog
    sudo installer -pkg /tmp/dialog.pkg -target /
    # Clean up the downloaded package
    rm /tmp/dialog.pkg
    fi
}

configureLog () {
    # function to set up the log file
    if [[ ! -d "$logPath" ]]; then
        mkdir -p "$logPath"
    else
        # if the dir exists, let's append to the existing log file
        if [[ -f "$rumlog" ]] ; then
            echo "Appending to existing log file: $rumlog"
        fi
    fi
    # create a timestamp for the log entry
    timestamp=$(date +"%Y-%m-%d %T")
    # log the function call
    echo "$timestamp - Configuring log file: $rumlog" >> "$rumlog"
}

rumCheck() {
    # RUM installed? Let's install if not.
    if [[ ! -f $rum ]]; then
        echo "Installing RUM from JSS"
        $jamf_bin policy -event "$installRUM"
        if [[ ! -f $rum ]]; then
            echo "Couldn't install RUM! Exiting."
            exit 1
        fi
        # Installation successful
        echo "RUM installation successful."
    else
        # RUM is already installed
        echo "RUM is already installed."
    fi
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for Updates
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

checkForUpdates(){
    $rum --action=list > "$rumlog"
    # super-echo!  Echo pretty-ish output to user. Replaces Adobes channel IDs with actual app names
    # Adobe channel ID list: https://helpx.adobe.com/enterprise/package/help/apps-deployed-without-their-base-versions.html
    secho=$(sed -n '/Following.*/,/\*/p' "$rumlog" \
        | sed 's/Following/The Following/g' \
        | sed 's/ACR/Camera Raw/g' \
        | sed 's/AEFT/After Effects/g' \
        | sed 's/AME/Media Encoder/g' \
        | sed 's/AUDT/Audition/g' \
        | sed 's/FLPR/Animate/g' \
        | sed 's/ILST/Illustrator/g' \
        | sed 's/MUSE/Muse/g' \
        | sed 's/PHSP/Photoshop/g' \
        | sed 's/PRLD/Prelude/g' \
        | sed 's/SPRK/XD/g' \
        | sed 's/KBRG/Bridge/g' \
        | sed 's/AICY/InCopy/g' \
        | sed 's/ANMLBETA/Character Animator Beta/g' \
        | sed 's/DRWV/Dreamweaver/g' \
        | sed 's/IDSN/InDesign/g' \
        | sed 's/PPRO/Premiere Pro/g' \
        | sed 's/LTRM/Lightroom Classic/g' \
        | sed 's/LRCC/Lightroom/g' \
        | sed 's/CHAR/Character Animator/g' \
        | sed 's/SBSTA/Substance Alchemist/g' \
        | sed 's/SBSTD/Substance Designer/g' \
        | sed 's/SBSTP/Substance Painter/g' \
        | sed 's/ESHR/Dimension/g' \
        | sed 's/RUSH/Premiere Rush/g' \
        | sed 's/\\/\\\\/g' \
        | sed 's/[\(\)\.\*\[\]]/\\&/g' \
        | tr '\n' ' ')

    if grep -i "updates are applicable on the system" "$rumlog"; then
        # Display dialog.app notification
        dialogContent+=(
            --title "Adobe Update Manager"
            --moveable
            --height "450"
            --width "650"
            --titlefont "size=18"
            --position "bottomright"
            --messagealignment "centre"
            --messagefont "size=11"
            --message "$notification_message\n\n\"$secho\""
            --button1text "Update"
            --button2text "Dismiss"
            --icon "$adobe_icon"
            --infobox "#### Computer Name: #### \n\n $computerName \n\n #### macOS Version: #### \n\n $macOSVersion"
            --infotext "${scriptFunctionalName}: Version $scriptVersion"
        )

        # Define function to show an alert that updates are done
updatesComplete() {

        # Show an alert that updates are done
        "$dialogPath" \
            --mini \
            --button1text "Close" \
            --moveable \
            --title "Adobe Update Manager" \
            --messagealignment left \
            --icon "$adobe_icon" \
            --message "$updatecomplete_message"
}

    # Launch dialog
    $dialogPath "${dialogContent[@]}"; returncode=$?

        case ${returncode} in
            0)  ## Process exit code 0 scenario here
                echo "${button1text}"
                installUpdates
                updatesComplete
                ;;
            2)  ## Process exit code 2 scenario here
                echo "${button2text}"
                exit 0
                ;;
            3) ## User clicked "More Info"
                echo "User clicked More Info"
                ;;
            4)  ## Process exit code 4 scenario here
                echo "timeout"
                ;;
            *)  ## Catch all processing
                echo "${returncode}"
                ;;
esac

        else
            echo "No Updates."
            exit 0
fi

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Install Updates
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

installUpdates() {
    # Let's caffinate the mac because this can take long
    caffeinate -d -i -m -u &
    caffeinatepid=$!

    # Displaying swiftDialog update "progress"
    "$dialogPath" \
        --height 450 \
        --width 650 \
        --quitkey x \
        --position "bottomright" \
        --moveable \
        --button1disabled \
        --progress \
        --progresstext "Updates in progress......" \
        --title "Adobe Update Manager" \
        --titlefont "size=18" \
        --messagealignment "left" \
        --icon "$adobe_icon" \
        --overlayicon "SF=arrow.down" \
        --infobox "#### Computer Name: #### \n\n $computerName \n\n #### macOS Version: #### \n\n $macOSVersion" \
        --infotext "${scriptFunctionalName}: Version $scriptVersion" \
        --message "$downloadinstall_message" &

    # do all of your work here
    $rum --action=install 

    # Take away the caffeine since we're done & Dialog Notification
    kill "$caffeinatepid"
    pkill -f Dialog
}

{
    # log the dialog update progress
    timestamp=$(date +"%Y-%m-%d %T")
    echo "$timestamp - Dialog update progress: $downloadinstall_message" >> "$rumlog"

    # log the result of the RUM installation
    rum_result=$("$rumupdate" > /dev/null 2>&1; echo $?)
    if [ "$rum_result" -eq 0 ]; then
        result="success"
    else
        result="failure"
    fi
    timestamp=$(date +"%Y-%m-%d %T")
    echo "$timestamp - RUM installation result: $result" >> "$rumlog"

    # Wait for updates to complete
    while [ "$(pgrep "$rumlog")" ]; do
        sleep 5
    done
    # If we get here, tell the user the updates are complete
    #updatesComplete
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Script Order
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

configureLog
dialogCheck
rumCheck
checkForUpdates