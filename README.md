# Jamf Nation-Roadshow London 2018
## Lab Nauseum - Dawn Of The DEP

Resources from my presentation at the Jamf Nation Roadshow (17th May 2018, The Mermaid, London) - leveraging DEPNotify in lab environments. This is an adaptation and simplification of the methods used in my university's environment to provision Macs in computer labs using installation and DEP based workflows. Imaging is dead!

### Background stuff ###

If you aren‘t getting Apple push notifications - https://support.apple.com/en-gb/HT203609

2017: A Push Odyssey — Journey to the Center of APNS - https://www.youtube.com/watch?v=nXjEevMtwa4

Use Device Enrollment - https://support.apple.com/en-gb/HT204142

Apple Device Enrollment Program Guide - https://www.apple.com/education/docs/DEP_Guide.pdf

macOS Installation: Strange New World - AWESOME blog post by Armin Briegel released on the same day I did my talk. This will get you where you need to be when it comes to getting macOS on your fleet via an installation based workflow - https://scriptingosx.com/2018/05/macos-installation-strange-new-world/

### DEPNotify ###

Grab DEPNotify here: https://gitlab.com/Mactroll/DEPNotify.

Frederico Deis has done some amazing work and added user input functionality which has been merged into the latest 1.1.0 update by Clayton Burlison and Joel Rennich. Huge hat tip to all of you!

Grab the 1.1.0 binary here: https://gitlab.com/Mactroll/DEPNotify/tags/1.1.0. Package it up with Composer or your packaging tool of choice, then you're off to the races!

Join the MacAdmins Slack: https://macadmins.herokuapp.com/ - check out the __#depnotify__ channel, hang out with the developers and users, get involved with testing, ask questions, discuss and enjoy.

### DEP - Provision - Example.sh ###

In my example, this script is intended to be ran via a Policy that's triggered on "Enrolment Complete" (you could be fancy and trigger it via a self-destructing Launch Daemon etc to ensure it will re-run incase provisioning is interrupted and the Mac is restarted).

The policy should also install DEPNotify along with your branding image - in this script, the image is assumed to be in `/Library/Application Support/UEL/ux/UEL.png` (rename/replace or don't use so you get the default, as per your organisation).

The script makes use of Jamf's parameter functionality: https://www.jamf.com/jamf-nation/articles/146/script-parameters

- `$4` = Jamf Pro Server URL (excluding the port number - 8443 is assumed, edit the script if you use something else)
- `$5` = Username for the Jamf Pro Server account doing the API reads/writes (must have permission to read and update Computer objects)
- `$6` = Password for the Jamf Pro Server account doing the API reads/writes

In order to automatically skip asking for user input if the computer record already exists with a name and role, the script reads from and populates these Extension Attributes to the Computer Record via the Jamf API (modify as appropriate for your org, or don't use them if you don't want this little bit of automation):

- Hostname (string)
- Computer Role (string)

We write the computer's hostname to our own `Hostname` Extension Attribute via the Jamf API during provisioning so it will persist when a Mac is erases with a clean install of macOS (because the actual Computer Name in the Jamf Computer Record changes to the default "iMac" etc value when the freshly re-provisioned Mac re-enrolls).

In my environment, the hostname determines which lab a Mac belongs in. So for a hostname of `DLEB285-12345`:

The first part of the hostname denotes the computer lab, `DLEB285` and can be broken down/decoded as follows:

- `DL`: Campus code (Docklands)
- `EB`: Building code (East Building)
- `2`: Floor code (2nd Floor)
- `85`: Room code (Room Number 85)

The second part of the hostname `12345` is an asset number, used for inventory purposes.

Lab Smart Groups are populated based on the computer hostname and role, so for Macs in lab `DLEB285` we would use:

#### Smart Group: Lab DLEB285 ####

And/Or | Criteria | Operator | Value
--- | --- | --- | ---
--- | Computer Name | like | DLEB285
and | Computer Role | is | Student

This is specific to my environment but does give some insight into how we can easily create differnt Smart Groups for Macs by campus, building, floor and room.

For each software title, separate Smart Groups are populated based on whether said application (or sometimes package receipt) is present and whether the Macs are in the specific Lab Smart Groups where the software is needed:

#### Smart Group: Deploy Mozilla Firefox ####

And/Or | Criteria | Operator | Value
--- | --- | --- | ---
--- | Application Title | is not | Firefox.app
and ( | Computer Group | member of | Lab DLEB285
or | Computer Group | member of | Lab DLWB123 )

In this example, we would get Macs without Firefox that are in labs DLEB285 or DLWB123. Once a Mac in either of those labs has Firefox, it will leave this Smart Group.

For each software title, a separate Policy is created to install it. Each Policy is scoped to its corresponding Smart Group (above). These Policies must have an `Update Inventory` step included to ensure that Macs leave the scoped Smart Group as soon as they have the application installed.

The Policies all have the same custom trigger: `Deploy`. This means that you can deploy all the software a specific lab needs with a single command in the provisioning script: `jamf policy -event Deploy`.

It is possible to go further with version detection and/or using Jamf's patch management policies but that is beyond the scope of my presentation.
