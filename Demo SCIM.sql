-- Demo: SCIM
-- Last updated: 06JUN2026

-- This demo shows the SCIM provisioning using curl as the IdP.

-- What SCIM Is –
--   SCIM (System for Cross-domain Identity Management) is an open standard protocol for 
--   automating the exchange of user identity information between systems. 
--   It defines a REST API with endpoints like /Users and /Groups for creating, updating, 
--   and deleting identity objects.

-- Client/Server Relationship –
-- SCIM Client - Sends HTTP requests to create/update/delete users & groups (the IdP)
-- SCIM Server - Receives requests and provisions the users/roles in the account

-- The SCIM client is the "sender" side of automated user provisioning — 
-- it pushes identity changes from your IdP into Snowflake.

-- NOTE: For this demo, here is the SCIM client/server relationship being used:
--   SCIM client: curl
--   SCIM server: Snowflake

-- *** Notes about running this demo: ***
-- 1. Part of the demo will be run in this workspace file, and part of the demo
--    will be run in Powershell.
-- 2. All of the curl commands are to be run by pasting in the code from the Powershell
--    script file "Demo-SCIM-Automated.ps1" directly into Powershell.
--    Run the respective steps one at a time in Powershell
--    (i.e., PART 1, PART 2, etc.)
-- 3. Run the code in the "SETUP" section and all of the other non-curl code directly in
--    this workspace file.
-- 4. After generating the SCIM access token in the "SETUP" section, copy the 
--    token and the base URL for the account you're using for the demo into the two 
--    Powershell variables in the script file "Demo-SCIM-Automated.ps1", 
--    lines 9 & 10, as follows:
--    $BASE_URL = "https://<YOUR_ORG_NAME>-<YOUR_ACCT_NAME>.snowflakecomputing.com/scim/v2"
--    $TOKEN = "<YOUR_SCIM_ACCESS_TOKEN"

-- =====================================================================================
-- SETUP: CREATE SCIM ROLE, SCIM SECURITY INTEGRATION, & SCIM ACCESS TOKEN
-- =====================================================================================
use role accountadmin;
use warehouse instructor1_wh;

-- Create the SCIM provisioner role
-- This is the Snowflake role that owns all of the users and roles created via SCIM. 
-- It's specified in the RUN_AS_ROLE parameter of the SCIM security integration 
-- that you create.
-- Purpose of the SCIM provisioner role
-- 1. Ownership — All IdP-provisioned users and roles are owned by this role, 
--    keeping them separate from manually-created objects
-- 2. Least privilege — It's granted only CREATE USER and CREATE ROLE on account, 
--    limiting what the IdP can do
-- 3. Scoped control — The SCIM integration operates under this role's permissions, 
--    so it can only manage objects it owns (unless granted additional privileges 
--   such as MONITOR USER to see all users)
create role if not exists generic_scim_provisioner_role;
grant create user on account to role generic_scim_provisioner_role;
grant create role on account to role generic_scim_provisioner_role;
grant role generic_scim_provisioner_role to role accountadmin;

-- Create the SCIM security integration
-- NOTE: Without the SCIM security integration, your IdP has no authorized  
-- pathway to automatically manage Snowflake users and roles — 
-- you'd have to provision them manually
-- When you set the SCIM_CLIENT in CREATE SECURITY INTEGRATION, you're telling 
-- Snowflake which IdP will be sending SCIM requests.
-- Here are the available options for SCIM_CLIENT:
--  'OKTA' — The SCIM client is Okta
--  'AZURE' — The SCIM client is Microsoft Entra ID (formerly Azure AD)
--  'GENERIC' — Any other SCIM-compliant IdP
-- Foe this demo, I'm using SCIM_CLIENT=GENERIC, since curl is
-- being used to simulate an IdP.
create or replace security integration klysy_generic_scim_secint
type = scim
scim_client = 'generic'
run_as_role = 'generic_scim_provisioner_role';

show integrations like '%klysy%scim%';

-- Generate a SCIM Access Token.
-- A SCIM access token is a Bearer token that authenticates API requests from your IdP
-- to Snowflake's SCIM endpoints.
-- Why it's needed: Your IdP needs to prove its identity when calling Snowflake's 
-- /scim/v2/ REST API to create/update/delete users and groups. 
-- The token is included in the Authorization: Bearer <token> header of every 
-- SCIM request, allowing Snowflake to verify that the request is coming 
-- from an authorized provisioner.
-- 
-- Without a SCIM access token, Snowflake would reject all incoming SCIM provisioning 
-- requests as unauthenticated.
-- 
-- Note: The SCIM access token (generated via SYSTEM$GENERATE_SCIM_ACCESS_TOKEN()) 
-- is the *legacy method*. 
-- Snowflake now also supports programmatic access tokens (PATs) and External OAuth 
-- as more modern authentication alternatives
--
-- Save the returned token — you'll use it as a Bearer token in API calls.
select system$generate_scim_access_token('KLYSY_GENERIC_SCIM_SECINT');

-- Record the returned value here:
/*
ver:4-hint:199900246041-did:1049-ETMsDgAAAZ6eSj6pABRBRVMvQ0JDL1BLQ1M1UGFkZGluZwEAABAAEJ4uIgTOoM2/Df4z0+hP92oAAADABP4kpRE/KprtGuTi1HiLiygwLTq0A3+p1yNm9LbhTBKj+G9r2AnB1JC6H1q05BdfWPfS5+6dHPsne80Z6jPwM6yV6554HQpBQxI5YrU4TwBOQA7HGlLK43axtp5ztkxBzXM6yZjAvojc9B2obmBRYvK3ZcHGE/DolVFBtUnHKn2xjhhWzTlAjBeR5S4zGa4dFNjBQCdsp6PWkvDRDpiDftpiXw+UmlF+0URyFZB9qiZmMT4fu0rLKyzoi47Ra2H6ABSefo53+RhLR08h4e2Khubkxm3SaA==
*/

-- Get your SCIM endpoint for the account being used for this demo
-- Your base URL is: https://sfedu03-rmb41258.snowflakecomputing.com/scim/v2/

-- Describe the security integration to get the SCIM endpoint UUID 
-- (optional, this would be needed for external OAuth authentication)
desc security integration klysy_generic_scim_secint
->> select "property"
    , "property_value"
    from $1
    where "property" = 'SCIM_ENDPOINT_ID';

-- Grant MONITOR privileges so that the SCIM provisioner role can 
-- see all users & roles
grant monitor user on account to role generic_scim_provisioner_role;
grant monitor role on account to role generic_scim_provisioner_role;


/*
-- =====================================================================================
-- WINDOWS CURL COMMANDS (Run these from PowerShell on your Windows 11 laptop)
-- =====================================================================================
-- 
-- IMPORTANT: 
-- 1. Replace <BASE_URL> with the full URL of the Snowflake account being used for the demo,
--    within double-quotes.
--    For example: "https://sfedu03-rmb41258.snowflakecomputing.com/scim/v2"
-- 2. Replace <TOKEN> with the token returned from the prior step when you ran
--    SYSTEM$GENERATE_SCIM_ACCESS_TOKEN.
--
-- Set these variables in PowerShell first before proceeding with the demo:
--
--   $BASE_URL = "https://sfedu03-rmb41258.snowflakecomputing.com/scim/v2"
--   $TOKEN = ""

# Here's the code that I pasted directly into Powershell:
$BASE_URL = "https://sfedu03-rmb41258.snowflakecomputing.com/scim/v2"
$TOKEN = ""

# Show the variables that are set:
$BASE_URL
$TOKEN
*/

# Be sure to run *all* of the commands in the "CONFIGURATION" section of the shell script file
# named "Demo-SCIM-Automated.ps1" before proceeding with PART 1 of the demo.
# These shell script commands build a set of functions to be used when running curl.

-- ========================================================================================
-- PART 1: CREATE USERS VIA SCIM (Simulates IdP pushing user identities to Snowflake users)
-- ========================================================================================
--
-- Create User: Alice Johnson (Data Analyst)
--
/*
$body = @'
{
  "schemas": ["urn:ietf:params:scim:schemas:core:2.0:User", "urn:ietf:params:scim:schemas:extension:2.0:User"],
  "userName": "alice.johnson",
  "name": {"givenName": "Alice", "familyName": "Johnson"},
  "emails": [{"value": "alice.johnson@example.com", "primary": true}],
  "displayName": "Alice Johnson",
  "active": true,
  "password": "Temp!Pass123",
  "urn:ietf:params:scim:schemas:extension:2.0:User": {
    "defaultRole": "PUBLIC",
    "defaultWarehouse": "INSTRUCTOR1_WH"
  }
}
'@

# Verify that the JSON is valid before sending
$body | ConvertFrom-Json

# If no error, run the actual call
curl.exe -X POST "$BASE_URL/Users" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/scim+json" `
  -H "Accept: application/scim+json" `
  -d $body

*/

-- *** Returned user id: 1049_199900202969_3
-- *** Returned user name: alice.johnson

-- Create User: Bob Smith (Data Engineer)
--
/*
$body = @'
{
  "schemas": ["urn:ietf:params:scim:schemas:core:2.0:User", "urn:ietf:params:scim:schemas:extension:2.0:User"],
  "userName": "bob.smith",
  "name": {"givenName": "Bob", "familyName": "Smith"},
  "emails": [{"value": "bob.smith@example.com", "primary": true}],
  "displayName": "Bob Smith",
  "active": true,
  "password": "Temp!Pass456",
  "urn:ietf:params:scim:schemas:extension:2.0:User": {
    "defaultRole": "PUBLIC",
    "defaultWarehouse": "INSTRUCTOR1_WH"
  }
}
'@
curl.exe -X POST "$BASE_URL/Users" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/scim+json" `
  -H "Accept: application/scim+json" `
  -d $body
*/

-- *** Returned user id: 1049_199900203205_3
-- *** Returned user name: bob.smith

-- Create User: Carol Davis (Security Admin)
--
/*
$body = @'
{
  "schemas": ["urn:ietf:params:scim:schemas:core:2.0:User", "urn:ietf:params:scim:schemas:extension:2.0:User"],
  "userName": "carol.davis",
  "name": {"givenName": "Carol", "familyName": "Davis"},
  "emails": [{"value": "carol.davis@example.com", "primary": true}],
  "displayName": "Carol Davis",
  "active": true,
  "password": "Temp!Pass789",
  "urn:ietf:params:scim:schemas:extension:2.0:User": {
    "defaultRole": "PUBLIC",
    "defaultWarehouse": "INSTRUCTOR1_WH"
  }
}
'@
curl.exe -X POST "$BASE_URL/Users" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/scim+json" `
  -H "Accept: application/scim+json" `
  -d $body
  
*/

-- *** Returned user id: 1049_199900203285_3
-- *** Returned user name: carol.davis

-- Step 4: Verify users were created in Snowflake
show users like '%ALICE%';
show users like '%BOB%';
show users like '%CAROL%';


-- =====================================================================================
-- PART 2: CREATE GROUPS/ROLES VIA SCIM (Simulates IdP pushing groups to SF roles)
-- =====================================================================================

-- Three groups are created: DATA_ANALYSTS, DATA_ENGINEERS, & SECURITY_ADMINS

/*
$body = @'
{
  "schemas": ["urn:ietf:params:scim:schemas:core:2.0:Group"],
  "displayName": "DATA_ANALYSTS"
}
'@
curl.exe -X POST "$BASE_URL/Groups" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/scim+json" `
  -H "Accept: application/scim+json" `
  -d $body

$body = @'
{
  "schemas": ["urn:ietf:params:scim:schemas:core:2.0:Group"],
  "displayName": "DATA_ENGINEERS"
}
'@
curl.exe -X POST "$BASE_URL/Groups" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/scim+json" `
  -H "Accept: application/scim+json" `
  -d $body

$body = @'
{
  "schemas": ["urn:ietf:params:scim:schemas:core:2.0:Group"],
  "displayName": "SECURITY_ADMINS"
}
'@
curl.exe -X POST "$BASE_URL/Groups" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/scim+json" `
  -H "Accept: application/scim+json" `
  -d $body
  
*/

-- Group IDs returned:
--  DATA_ANALYSTS: 1049_199900205049_4
--  DATA_ENGINEERS: 1049_199900205053_4
--  SECURITY_ADMINS: 1049_199900205169_4

-- Verify that the roles have been created in Snowflake
show roles like 'DATA_ANALYSTS';
show roles like 'DATA_ENGINEERS';
show roles like 'SECURITY_ADMINS';

-- =====================================================================================
-- PART 3: ASSIGN USERS TO GROUPS (Simulates IdP group membership sync)
-- =====================================================================================

/*
# First, get the user IDs. Run this to list all SCIM-provisioned users:
curl.exe -X GET "$BASE_URL/Users" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Accept: application/scim+json"
  
# Then, get the group IDs:
curl.exe -X GET "$BASE_URL/Groups" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Accept: application/scim+json"
*/

-- User IDs:
--  Alice Johnson: 1049_199900202969_3
--  Bob Smith: 1049_199900203205_3
--  Carol Davis: 1049_199900203285_3
--
-- Group IDs:
--  DATA_ANALYSTS: 1049_199900205049_4
--  DATA_ENGINEERS: 1049_199900205053_4
--  SECURITY_ADMINS: 1049_199900205169_4
/*

# Add Alice to DATA_ANALYSTS group
$body = @'
{
  "schemas": ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
  "Operations": [{
    "op": "add",
    "path": "members",
    "value": [{"value": "1049_199900202969_3"}]
  }]
}
'@
curl.exe -X PATCH "$BASE_URL/Groups/1049_199900205049_4" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/scim+json" `
  -H "Accept: application/scim+json" `
  -d $body

# Add Bob to DATA_ENGINEERS group
$body = @'
{
  "schemas": ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
  "Operations": [{
    "op": "add",
    "path": "members",
    "value": [{"value": "1049_199900203205_3"}]
  }]
}
'@
curl.exe -X PATCH "$BASE_URL/Groups/1049_199900205053_4" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/scim+json" `
  -H "Accept: application/scim+json" `
  -d $body

# Add Carol to SECURITY_ADMINS group
$body = @'
{
  "schemas": ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
  "Operations": [{
    "op": "add",
    "path": "members",
    "value": [{"value": "1049_199900203285_3"}]
  }]
}
'@
curl.exe -X PATCH "$BASE_URL/Groups/1049_199900205169_4" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/scim+json" `
  -H "Accept: application/scim+json" `
  -d $body

*/

-- Verify the role grants in Snowflake
show grants of role data_analysts;
show grants of role data_engineers;
show grants of role security_admins;

-- =====================================================================================
-- PART 4: UPDATE ATTRIBUTES FOR A USER (Simulates IdP attribute change)
-- =====================================================================================

-- First, view the current attributes for Alice before applying the update.

use warehouse instructor1_wh;

-- Current attributes for Alice Johnson:
--   DISPLAY_NAME: "Alice Johnson"
--   DEFAULT_ROLE: PUBLIC
desc user "ALICE.JOHNSON"
->> select "property"
    , "value"
    from $1
    where "property" in ('DISPLAY_NAME','DEFAULT_ROLE');

/*
# Update Alice's "display_name" and "default_role" attributes
$body = @'
{
  "schemas": ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
  "Operations": [
    {"op": "replace", "value": {"displayName": "Alice Johnson - Senior Analyst"}},
    {"op": "replace", "path": "urn:ietf:params:scim:schemas:extension:2.0:User:defaultRole", "value": "DATA_ANALYSTS"}
  ]
}
'@
curl.exe -X PATCH "$BASE_URL/Users/1049_199900202969_3" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/scim+json" `
  -H "Accept: application/scim+json" `
  -d $body

*/

-- Verify the update to Alice's user attributes in Snowflake
-- Updated attributes for Alice Johnson:
--   DISPLAY_NAME: "Alice Johnson - Senior Analyst"
--   DEFAULT_ROLE: DATA_ANALYSTS
desc user "ALICE.JOHNSON"
->> select "property"
    , "value"
    from $1
    where "property" in ('DISPLAY_NAME','DEFAULT_ROLE');
    
-- =========================================================================
-- PART 5: REMOVE USER FROM GROUP & ADD TO ANOTHER (Simulates role transfer)
-- =========================================================================

/*
# Alice is transferring from the DA team to the DE team, so remove Alice from the 
# DATA_ANALYSTS group, and add her to the DATA_ENGINEERS group.
$body = @'
{
  "schemas": ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
  "Operations": [{
    "op": "remove",
    "path": "members[value eq \"1049_199900202969_3\"]"
  }]
}
'@
curl.exe -X PATCH "$BASE_URL/Groups/1049_199900205049_4" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/scim+json" `
  -H "Accept: application/scim+json" `
  -d $body

$body = @'
{
  "schemas": ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
  "Operations": [{
    "op": "add",
    "path": "members",
    "value": [{"value": "1049_199900202969_3"}]
  }]
}
'@
curl.exe -X PATCH "$BASE_URL/Groups/1049_199900205053_4" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/scim+json" `
  -H "Accept: application/scim+json" `
  -d $body
  
*/

-- Verify role revocation, note that there is now no grantee of the DATA_ANALYSTS role
-- but there are now *two* grantees of the DATA_ENGINEERS role
-- Note that Alice has been granted the role DATA_ANALYSTS
show grants of role data_analysts; -- Alice removed from DATA_ANALYSTS role
show grants of role data_engineers; -- Alice added to DATA_ENGINEERS role

-- =====================================================================================
-- PART 6: DELETE A USER (Simulates IdP full de-provisioning)
-- =====================================================================================

/*
# Delete the user Carol
curl.exe -X DELETE "$BASE_URL/Users/1049_199900203285_3" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Accept: application/scim+json"

*/
  
-- Verify that Carol has been dropped
show users like '%CAROL%';

-- =====================================================================================
-- PART 7: FILTER / SEARCH QUERIES (Simulates IdP querying Snowflake)
-- =====================================================================================

/*
# 
# Search for specific users by userName
# Alice: Found
curl.exe -X GET "$BASE_URL/Users?filter=userName%20eq%20%22alice.johnson%22" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Accept: application/scim+json"

# Bob: Found
curl.exe -X GET "$BASE_URL/Users?filter=userName%20eq%20%22bob.smith%22" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Accept: application/scim+json"

# Carol: Not found
# Note: This will not return any details, since Carol has been previously dropped
curl.exe -X GET "$BASE_URL/Users?filter=userName%20eq%20%22carol.davis%22" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Accept: application/scim+json"

*/

/*
# Search for specific groups by displayName:
curl.exe -X GET "$BASE_URL/Groups?filter=displayName%20eq%20%22DATA_ANALYSTS%22" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Accept: application/scim+json"

curl.exe -X GET "$BASE_URL/Groups?filter=displayName%20eq%20%22DATA_ENGINEERS%22" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Accept: application/scim+json"
  
curl.exe -X GET "$BASE_URL/Groups?filter=displayName%20eq%20%22SECURITY_ADMINS%22" `
  -H "Authorization: Bearer $TOKEN" `
  -H "Accept: application/scim+json"

*/

-- ═══════════════════════════════════════════════════════════════════════════════════════
-- PART 8: AUDIT SCIM REQUESTS (Run in Snowflake to see recent API activity)
-- ═══════════════════════════════════════════════════════════════════════════════════════

-- View SCIM API requests from the last 60 minutes (useful for debugging)
select *
  from table(snowflake.information_schema.rest_event_history(
      rest_service_type => 'SCIM',
      time_range_start => dateadd('minutes', -60, current_timestamp()),
      time_range_end => current_timestamp(),
      result_limit => 200))
  order by event_timestamp desc;

-- Note the returned values of METHOD, RESOURCE_NAME, & RESOURCE_DOMAIN
-- Regarding the values of METHOD:
--   DELETE: Remove a user or group from Snowflake
--   POST: Create a new user or group in Snowflake
--   PATCH: Update specific attributes of an existing user or group 
--    (e.g., activate/deactivate, change name, update role, modify group membership)
select 
    event_timestamp
  , event_type
  , method
  , resource_name
  , resource_domain
  from table(snowflake.information_schema.rest_event_history(
      rest_service_type => 'SCIM',
      time_range_start => dateadd('minutes', -60, current_timestamp()),
      time_range_end => current_timestamp(),
      result_limit => 200))
  order by event_timestamp desc, method asc;


-- *** Demo Cleanup ***

use role accountadmin;

-- Drop SCIM-provisioned users
drop user if exists "ALICE.JOHNSON";
drop user if exists "BOB.SMITH";
drop user if exists "CAROL.DAVIS";

-- Drop SCIM-provisioned roles
drop role if exists data_analysts;
drop role if exists data_engineers;
drop role if exists security_admins;

-- Drop the SCIM security integration & SCIM provisioner role
drop security integration if exists klysy_generic_scim_secint;
drop role if exists generic_scim_provisioner_role;

