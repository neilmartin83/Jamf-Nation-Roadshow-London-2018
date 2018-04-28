# Jamf Nation-Roadshow London 2018
## Lab Nauseum - Dawn Of The DEP

Resources from my presentation at the Jamf Nation Roadshow - leveraging DEPNotify in lab environments.

Grab DEPNotify here: https://gitlab.com/Mactroll/DEPNotify

I am using @fgd's User Input Fork: (link to be provided)

Join the MacAdmins Slack: https://macadmins.herokuapp.com/ - check out the __#depnotify__ channel.

### DEP - Provision - Example.sh ###

This script is intended to be ran via a Policy that's triggered on "Enrolment Complete". The policy should also install DEPNotify along with your branding image - in this script, the image is assumed to be in `/Library/Application Support/UEL/ux/UEL.png` (rename/replace as per your organisation).

In order to automatically skip asking for user input if the computer record already exists with a name and role, the script reads from and populates these Extension Attributes in the JSS (modify as appropriate for your org, or don't use them if you don't want this little bit of automation):

- Computer Name (string)
- Computer Role (string)

In my environment, Lab Smart Groups are populated based on the computer hostname and role, so for a hostname of DLEB285-12345:

And/Or | Criteria | Operator | Value
--- | --- | --- | ---
--- | Computer Name | like | DLEB285
and | Computer Role | is | Student

The first part of the hostname `DLEB285` can be broken down/decoded as follows:

- `DL`: Campus code (Docklands)
- `EB`: Building code (East Building)
- `2`: Floor code (2nd Floor)
- `85`: Room code (Room Number 85)

This is specific to my environment but does give some insight into how we can easily create differnt Smart Groups for Macs by campus, building, floor and room.

For each software title, separate Smart Groups are populated based on whether said application (you could also look for package receipt) is present and whether the Macs are in the specific Lab Smart Groups where the software is needed:

And/Or | Criteria | Operator | Value
--- | --- | --- | ---
--- | Application Title | is not | Firefox.app
and ( | Computer Group | is | Lab DLEB85
or | Computer Group | is | Lab DLWB123 )

In this example, we would get Macs without Firefox that are in labs DLEB285 or DLWB123. Once a Mac in either of those labs has Firefox, it will leave this Smart Group.

For each software title, a separate Policy is created to install it. These Policies are scoped to their corresponding Smart Group (above).

The Policies all have the same custom trigger: `Deploy`. This means that you can deploy all the software a specific lab needs with a single command in the provisioning script: `jamf policy -event Deploy`.

It is possible to go further with version detection and/or using Jamf's patch management policies but that is beyond the scope of my presentation.
