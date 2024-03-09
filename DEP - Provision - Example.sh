#!/bin/bash

# $4 = JSS URL including port number, if applicable
# $5 = JSS account username for API access
# $6 = JSS account password for API access

# Set basic variables
osversion=$(sw_vers -productVersion)
serial=$(ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformSerialNumber/{print $4}')
jamfUrl="$4"
apiUserName="$5"
apiPassword="$6"

# Let's not go to sleep 
caffeinate -d -i -m -s -u &
caffeinatepid=$!

# Disable Software Updates during imaging
softwareupdate --schedule off

dockStatus=$(pgrep -x Dock)
while [[ "$dockStatus" == "" ]]; do
	sleep 5
	dockStatus=$(pgrep -x Dock)
done

# Get the currently logged in user's username
loggedInUser=$(python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

# Get API Bearer Token
response=$(curl -s -u "$apiUserName":"$apiPassword" "$jamfUrl"/api/v1/auth/token -X POST)
bearerToken=$(echo "$response" | plutil -extract token raw -)

# Check for existing Hostname extension attribute in JSS - if it's not there, we'll ask for the name and role, otherwise, automation baby!

eaxml=$(curl -s "$jamfUrl"/JSSResource/computers/serialnumber/"$serial"/subset/extension_attributes -H "Authorization: Bearer ${bearerToken}" -H "Accept: text/xml")
jssHostName=$(echo "$eaxml" | xpath '//extension_attribute[name="Hostname"' | awk -F'<value>|</value>' '{print $2}')
jssUserRole=$(echo "$eaxml" | xpath '//extension_attribute[name="Mac User Role"' | awk -F'<value>|</value>' '{print $2}')

# Destroy API Bearer Token as it may be some time before we need another
curl "$jamfUrl"/api/v1/auth/invalidate-token -H "Authorization: Bearer ${bearerToken}" -X POST -s -o /dev/null

if [[ "$jssHostName" == "" ]] || [[ "$jssUserRole" == "" ]]; then
	sudo -u "$loggedInUser" defaults write menu.nomad.DEPNotify PathToPlistFile /var/tmp/
	sudo -u "$loggedInUser" defaults write menu.nomad.DEPNotify RegisterMainTitle "Let's get started..."
	sudo -u "$loggedInUser" defaults write menu.nomad.DEPNotify RegistrationButtonLabel OK
 	sudo -u "$loggedInUser" defaults write menu.nomad.DEPNotify UITextFieldUpperPlaceholder "DLEB123-12345"
	sudo -u "$loggedInUser" defaults write menu.nomad.DEPNotify UITextFieldUpperLabel "Computer Name"
	sudo -u "$loggedInUser" defaults write menu.nomad.DEPNotify UIPopUpMenuUpper -array Student "Staff" "Staff Loan"
	sudo -u "$loggedInUser" defaults write menu.nomad.DEPNotify UIPopUpMenuUpperLabel "Computer Role"
	echo "Command: ContinueButtonRegister: Continue" >> /var/tmp/depnotify.log
	echo "Command: Image: "/Library/Application Support/UEL/ux/UEL.png"" >> /var/tmp/depnotify.log
	echo 'Command: MainTitle: Hi there!'  >> /var/tmp/depnotify.log
	echo "Command: MainText: It's time to set up this Mac with the software and settings it needs. Before we continue, please make sure it is plugged into a wired network connection on campus. \n \n If you need any assistance, please contact the UEL IT Service Desk. \n \n Telephone: xxx xxxx xxx \n Email: xxxxxxxxxx@xxx.xxx.xx"  >> /var/tmp/depnotify.log
	echo "Status: Please set the computer name and role to continue..." >> /var/tmp/depnotify.log
	sudo -u "$loggedInUser" /Applications/Utilities/DEPNotify.app/Contents/MacOS/DEPNotify -jamf -fullScreen &
	sleep 1

	# Wait for the user data to be submitted...
	while [ ! -f /var/tmp/DEPNotify.plist ]; do
		echo "Status: Please set the computer name and role to continue..." >> /var/tmp/depnotify.log
		sleep 5
	done

	# Let's read the user data into some variables...
	computerName=$(/usr/libexec/plistbuddy /var/tmp/DEPNotify.plist -c "print 'Computer Name'")
	computerRole=$(/usr/libexec/plistbuddy /var/tmp/DEPNotify.plist -c "print 'Computer Role'")

	# Update Hostname and Computer Role in JSS

	# Get API Bearer Token
	response=$(curl -s -u "$apiUserName":"$apiPassword" "$jamfUrl"/api/v1/auth/token -X POST)
	bearerToken=$(echo "$response" | plutil -extract token raw -)
 
	# Create xml
	cat << EOF > /var/tmp/name.xml
<computer>
    <extension_attributes>
        <extension_attribute>
            <name>Hostname</name>
            <value>$computerName</value>
        </extension_attribute>
    </extension_attributes>
</computer>
EOF
	## Upload the xml file
	/usr/bin/curl -s "$jamfUrl"/JSSResource/computers/serialnumber/"$serial" -H "Authorization: Bearer ${bearerToken}" -H "Content-type: text/xml" -T /var/tmp/name.xml -X PUT
	
 	# Create xml
	cat << EOF > /var/tmp/role.xml
<computer>
    <extension_attributes>
        <extension_attribute>
            <name>Mac User Role</name>
            <value>$computerRole</value>
        </extension_attribute>
    </extension_attributes>
</computer>
EOF
	## Upload the xml file
	/usr/bin/curl -s "$jamfUrl"/JSSResource/computers/serialnumber/"$serial" -H "Authorization: Bearer ${bearerToken}" -H "Content-type: text/xml" -T /var/tmp/role.xml -X PUT

	# Destroy API Bearer Token
	curl "$jamfUrl"/api/v1/auth/invalidate-token -H "Authorization: Bearer ${bearerToken}" -X POST -s -o /dev/null

else
	# Set variables for Computer Name and Role to those from the JSS
	computerName="$jssHostName"
	computerRole="$jssUserRole"
	# Launch DEPNotify
	echo "Command: Image: "/Library/Application Support/UEL/ux/UEL.png"" >> /var/tmp/depnotify.log
	echo "Command: MainTitle: Setting things up..."  >> /var/tmp/depnotify.log
	if [[ $computerRole == "Student" ]]; then
		echo "Command: MainText: Please wait while we set this Mac up with the software and settings it needs. This may take a few hours. We'll restart automatically when we're finished. \n \n Role: "$computerRole" Mac \n Computer Name: "$computerName" \n macOS Version: "$osversion""  >> /var/tmp/depnotify.log
	else
		echo "Command: MainText: Please wait while we set this Mac up with the software and settings it needs. This may take up to 20 minutes. We'll restart automatically when we're finished. \n \n Role: "$computerRole" Mac \n Computer Name: "$computerName" \n macOS Version: "$osversion""  >> /var/tmp/depnotify.log
	fi
	echo "Status: Please wait..." >> /var/tmp/depnotify.log
	sudo -u "$loggedInUser" /Applications/Utilities/DEPNotify.app/Contents/MacOS/DEPNotify -jamf -fullScreen &	
fi

# Carry on with the setup...

# Change DEPNotify title and text...
echo "Command: MainTitle: Setting things up..."  >> /var/tmp/depnotify.log
if [[ $computerRole == "Student" ]]; then
	echo "Command: MainText: Please wait while we set this Mac up with the software and settings it needs. This may take a few hours. We'll restart automatically when we're finished. \n \n Role: "$computerRole" Mac \n Computer Name: "$computerName" \n macOS Version: "$osversion""  >> /var/tmp/depnotify.log
else
	echo "Command: MainText: Please wait while we set this Mac up with the software and settings it needs. This may take up to 20 minutes. We'll restart automatically when we're finished. \n \n Role: "$computerRole" Mac \n Computer Name: "$computerName" \n macOS Version: "$osversion""  >> /var/tmp/depnotify.log
fi
echo "Status: Please wait..." >> /var/tmp/depnotify.log

# Time to set the hostname...
echo "Status: Setting computer name" >> /var/tmp/depnotify.log
jamf setComputerName -name "${computerName}"

# Bind to AD
jamf policy -event BindAD

# Run software deployment policies based on smart group membership
jamf policy -event Deploy

# Run a software update

echo "Status: Installing Apple Software Updates" >> /var/tmp/depnotify.log
/usr/sbin/softwareupdate -ia

# Finishing up
echo "Command: MainTitle: All done!"  >> /var/tmp/depnotify.log
echo "Command: MainText: This Mac will restart shortly and you'll be able to log in. \n \n If you need any assistance, please contact the UEL IT Service Desk. \n \n Telephone: xxx xxxx xxxx \n Email: xxxxxxxxxxx@xxx.xxx.xx"  >> /var/tmp/depnotify.log
echo "Status: Restarting, please wait..." >> /var/tmp/depnotify.log

jamf recon
kill "$caffeinatepid"
/sbin/shutdown -r +2 &
