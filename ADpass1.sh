#!/bin/bash

########################################################################
# Created By: Macsupport@Macmillanusa.com
# Creation Date: March 2014
# Last modified: March 21st, 2014
# Brief Description: Prompt to update the AD password and the keychain
# 6/16/14 Retzer: edited days remaining string
# 6/16/14 Retzer: added networkStatus var to verify user is on the network, on the internet, or all alone by themselves:(
# 6/16/14 Retzer: adding adding bind check, local-only user check. 
# 6/16/14 Retzer: adding check current user password against dscl; 
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
#### Check network status, bind status, confirm user is in AD
#################################################
adPath='/Active Directory/NEWYORK/newyork.hbpub.net'
bindStatus=1									#(set to False (unbound) by default)

if ping -o hbpub.net &> /dev/null; then
	networkStatus=0  							#on thedomain
     	if id macsupport &> /dev/null; then 
        	bindStatus=0						#bound
        	if ! `dscl "$adPath" -read /Users/$user &>/dev/null` ; then
        		networkUser=1					#false, local only account
        		echo "Canceling: local-only account"
        		exit 0							#then bail on script
        	fi		  	
     	fi
elif ping -o google.com &> /dev/null; then
	networkStatus=1  							#off domain, on the internet
else
	networkStatus=2								#not able to reach the internet
	echo "Cancelling: mac offline"
	exit 0										#exit, right?  if they're not on the internet why bother?
fi

#################################################
#### Evaluate days remaining until Password Expires & customize string
#################################################
lastpwdMS=`dscl localhost read /Local/Default/Users/$user | grep SMBPasswordLastSet | cut -d' ' -f 2`
todayUnix=`date "+%s"`
lastpwdUnix=`expr $lastpwdMS / 10000000 - 11644473600`
diffUnix=`expr $todayUnix - $lastpwdUnix`
diffdays=`expr $diffUnix / 86400`
daysremaining=`expr $pwPolicy - $diffdays`
daysString="in $daysremaining days"
if [ $daysremaining -eq 1 ]; then
	daysString="in less than 1 day"
elif [ $daysremaining -eq 0 ]; then
	daysString="TODAY"
fi

#################################################
#### Cocoa Dialog window 1 & 2 :  (change your password? what is current password?)
#################################################
CD="/Applications/Utilities/CocoaDialog.app/Contents/MacOS/CocoaDialog"

firstPrompt=`$CD msgbox --no-newline \
--text "Your login password will expire $daysString!!" \
--button1 "Change Password now" --button2 "Remind me Later" --button3 "Cancel"`
#--informative-text "Click the appropriate button to change your password." \

if [ "$firstPrompt" == "1" ]; then
	oldPass_A=($($CD secure-standard-inputbox --title "Enter your Current Password" --no-newline --informative-text "Please enter your CURRENT password you use to login to your Mac"))
	if [ "$oldPass_A" == "1" ]; then
		oldPassword=${oldPass_A[1]}
		if ! `dscl "$adPath" -auth $user $oldPassword &> /dev/null` ; then
			oldPass_B=($($CD secure-standard-inputbox --title "Enter your Current Password" --no-newline --informative-text "Please enter your CURRENT password you use to login to your Mac"))
			if [ "$oldPass_B" == "1" ]; then
				oldPassword=${oldPass_B[1]}
				if ! `dscl "$adPath" -auth $user $oldPassword &> /dev/null` ; then
					$CD ok-msgbox --title "Closing PasswordChange" --text "Still unable to authenticate with password." --informative-text "Please contact MacSupport at x6111" --no-cancel &> /dev/null
					echo "Canceling3 : cannot "
					exit 0
				fi
			else 
				echo "Canceling2"
				exit 0		
			fi		
		fi	
	else 
		echo "Canceling1"
		exit 0		
	fi	
elif [ "$firstPrompt" == "2" ]; then
#	osascript -e 'tell application "Finder"
#		activate
#		open file "Network Connect.app" of folder "Applications" of startup disk
#	end tell'
	exit 0
#	echo "User chose OffSite"
elif [ "$firstPrompt" == "3" ]; then
	echo "Canceling0"
	exit 0
fi

#################################################
#### Cocoa Dialog window 3 - test new password, and new password confirmation:
#################################################

passwordMatch=1			#False
j=1
npString="Please enter a NEW password. (complexity requirements etc)"
npTitle="Enter your New Password"
while (( passwordMatch != 0 && $j <= 3 )) ; do

####### Receive & Test suggested new password
	okPass=1		#False
	i=1
	#complexity requirements as informative text?
	
	while (( okPass != 0 && $i <= 3 )) ; do
		newPass_A=($($CD secure-standard-inputbox --title "$npTitle" --no-newline --informative-text "$npString"))
		if [ "$newPass_A" == "1" ]; then
			newPassword=${newPass_A[1]}
		else 
			echo "Canceling5"
			exit 0		
		fi
		digitChar='[[:digit:]]'
		lowerChar='[[:lower:]]'
		punctChar='[[:punct:]]'
		upperChar='[[:upper:]]'
		score=0
		for char in "$digitChar" "$lowerChar" "$punctChar" "$upperChar"; do
	    	[[ $newPassword =~ $char ]] && let score++
		done
		if (( `echo ${#newPassword}` > 6 && score > 2 )) && [ "$newPassword" != "$oldPassword" ] ; then
			okPass=0
		fi
		npString="That password does not meet complexity requirements. Please try again"
		npTitle="Re-try New Password"
		((i++))
		###right now it just quits out after 3 tries
	done
	
	if (( i == 4 )) ; then
		$CD ok-msgbox --title "Closing PasswordChange" --text "Quitting PasswordChange Application" --informative-text "Please contact MacSupport at x6111" --no-cancel &> /dev/null
		echo "Cancelling6 : cannot match complexity"
		exit 0	
	fi

####### Receive & Test second entry of new password	
	npString="Please RE-TYPE your NEW password to confirm"
	npTitle="Confirm New Password"
	newPass_B=($($CD secure-standard-inputbox --title "$npTitle" --no-newline --informative-text "$npString"))
	if [ "$newPass_B" == "1" ]; then
		newPasswordConfirm=${newPass_B[1]}
	else 
		echo "Canceling7"
		exit 0		
	fi
	if [ "$newPassword" == "$newPasswordConfirm" ] ; then
		passwordMatch=0
	fi
	npString="New passwords did not match. Please Re-enter NEW password."
	npTitle="Re-Enter New Password"
	((j++))
done

if (( j == 4 )) ; then
	$CD ok-msgbox --title "Closing PasswordChange" --text "Quitting PasswordChange Application" --informative-text "Please contact MacSupport at x6111" --no-cancel &> /dev/null
	echo "Cancelling7: cannot match passwords"
	exit 0	
fi


echo "You made it! To the end of the script!"



