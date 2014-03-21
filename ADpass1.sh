#!/bin/bash

########################################################################
# Created By: Macsupport@Macmillanusa.com
# Creation Date: March 2014
# Last modified: March 21st, 2014
# Brief Description: Prompt to update the AD password and the keychain
########################################################################

#################################################
#### Set Password length of expiration 
#################################################
pwPolicy=60

#################################################
#### Determine the current signed in user 
#################################################
user=`/usr/bin/who | /usr/bin/awk '/console/{ print $1 }'`

#################################################
#### Evaluate days remaining until Password Expires
#################################################
lastpwdMS=`dscl localhost read /Local/Default/Users/$user | grep SMBPasswordLastSet | cut -d' ' -f 2`
todayUnix=`date "+%s"`
lastpwdUnix=`expr $lastpwdMS / 10000000 - 11644473600`
diffUnix=`expr $todayUnix - $lastpwdUnix`
diffdays=`expr $diffUnix / 86400`
daysremaining=`expr $pwPolicy - $diffdays`

#################################################
#### Cocoa Dialog Path
#################################################
CD="/Applications/Utilities/CocoaDialog.app/Contents/MacOS/CocoaDialog"

rv=`$CD msgbox --no-newline \
--text "Your login password will expire in less than $daysremaining days!!" \
--informative-text "Click the appropriate button to change your password." \
--button1 "Update Password now" --button2 "Remind me Later" --button3 "Cancel"`
if [ "$rv" == "1" ]; then
rv=($($CD secure-standard-inputbox --title "Enter your Current Password" --no-newline --informative-text "Please enter your CURRENT password you use to login to your Mac"))
OLDPASSWORD=${rv[1]}
exit 0
echo "User chose OnSite"
elif [ "$rv" == "2" ]; then
osascript -e 'tell application "Finder"
activate
open file "Network Connect.app" of folder "Applications" of startup disk
end tell'
exit 0
echo "User chose OffSite"
elif [ "$rv" == "3" ]; then
echo "Cancelling"
exit 0
fi