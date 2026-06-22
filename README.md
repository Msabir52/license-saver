# license saver

alrightyy so the goal here is to save on microsoft licenses

Mayer wants me to do this assignment. I know this is something they've already implemented, so there's definitely a right answer haha! In any case, for the uninitiated, the CS team here at Tech-Keys has used a combination of processes to monitor our clients users, and look for licenses being used by inactive users. This PowerShell mega scrip attempts to accomplish that again, but this time its me (and my little buddies in some data center) trying to build it from scratch(ish).

The Goal:
-remove unused licenses assigned to inactive or disabled users
-analyze underutilized licenses assigned to active users who are not using their license to the full potential, and adjust their licenses to reflext what they need

All to save the client money in the long run :)

The process (high-level):
-Pull data from Microsoft Graph
-Analyze the output
-(Look to) Unlicense inactive users, and make recommendations for underutilized licenses
-Generate a quick neat report of the findings, and how much money was saved over how many licenses



The process (in detail):
-adding as I go through all the requirements and vision board this out~

1. Initial Tenant Setup
1a. Create a Dev Tenant
- created test tennant - 1ad2a9eb-7be3-410e-82e2-a3e576f592ed // moiz.sabir@tech-keys.com - 
- created admin account, moizadmin@rfgd4w.onmicrosoft.com // <saved pwd in tk ms edge pwd mgr>
- kept same password for all dummy users

1b. Create an Entra App
- created an app registration, a6553e25-cf51-4c35-9d2b-ff0dd26f08bd "license saver"
- directory selected
- added graph perms in API, user.read.all to get all the user info, auditlog.read.all for sign in activity, organization.read.all to get all the licensing info, and reports.read.all to get the usage info for license downgrade

1c. Authentication Secret for the script
- key stored in my downloads in a notepad file
- created env for storing the secret
- created config.json


2. Get the base functions set for grabbing the data from MS Graph
2a. formulate the token URL and body 
2b. ask for a graph token with the above
2c. query the information
2d. take the 302 redir and use it to get the CSV of data
ISSUE - usage reports seem to not exist for the sandbox tenant, so going to continue forward on just the core requirement of disabled licensed accounts.

3. Licensed Disabled Acounts
3a. Pull the data from graph of the accounts

4. REPORT GENERATION
4a. add in param at top to output to .\Output
4b. helper function
4c. report made, html export save
4d. license sku to readable name lookup
4e. edit report to incorporate readable name

5. Inactive Users
5a. Add helper function to map License SKU to name
5b. add parameter for function so i can pass through any number of days to determine as inactive for testing (then set the 30 60 90 default report)
5c. Create list for inactive users, along with PS Object with (what chat says) are best practice parts like recommendation etc. for the basic purpose this'll just be to manually review but when usage data comes into play this will be helpful for downgrading licenses.
5d. Replace / Update report function to have both tables. 
5e. update function calls
5f. default 30 60 90 reoprt - adjust parameter to be an array and take in the report. Adjust the function to not loop days anymore and just for each user look and see if it meets any threshold

