# Jamf Nation-Roadshow London 2018
## Dawn of the DEP

Resources from my presentation at the Jamf Nation Roadshow - leveraging DEPNotify in lab environments.

Grab DEPNotify here: https://gitlab.com/Mactroll/DEPNotify

I am using @fgd's User Input Fork: (link to be provided)

Join the MacAdmins Slack: https://macadmins.herokuapp.com/ - check out the __#depnotify__ channel.

### DEP - Provision - Example.sh ###

This script is intended to be ran via a Policy that's triggered on "Enrolment Complete". The policy should also install DEPNotify along with your branding image - in this script, the image is assumed to be in `/Library/Application Support/UEL/ux/UEL.png` (rename/replace as per your organisation).

In order to automatically skip asking for user input if the computer record already exists with a name and role, the script reads from and populates these Extension Attributes in the JSS (modify as appropriate for your org, or don't use them if you don't want this little bit of automation):

- Computer Name (string)
- Computer Role (string)
