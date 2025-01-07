# Helper Scripts 

This directory contains PowerShell scripts that are used by the migration process during a ADO project migration. 

### Files:

<u>ADODeletePolicies.ps1</u>: <br />
Used by the `Migrate-ADO-Policies.psm1` module file to delete all of the Policies prior to migrating them. 

<u>ADODeleteRepos.ps1</u>: <br />
Used by the `Migrate-ADO-Repos.psm1` module file to delete and re-create all of the Repositories in the Target project. 

<u>ADODeleteVariableGroups.ps1</u>: <br />
Used by the `Migrate-ADO-VariableGroups.psm1` module file to re-migrate Variable Groups







