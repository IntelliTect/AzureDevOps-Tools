- Generate import files with prepare step in TfsMigrator
You are ready to generate the import specification and related files you will need to queue an
import of your collection database. This section will cover the different files that are produced
but first you will need to run the prepare command to generate them.

_**Migrator prepare /collection:http://localhost:8080/tfs/DefaultCollection/
tenantDomainName:contoso.com /Region:CUS**_

The tenant domain name option is the name of your company’s Azure Active Directory
tenant. The prepare command will contact your Azure Active Directory tenant so it will
prompt you to login with a user from the tenant with permissions to read information about
all of the users in the Azure Active Directory tenant. It is important to understand that the
prepare command needs to have access to the Internet for this step. If your Azure DevOps
Server does not have access to the Internet, then you will need to run this command from
a different computer.

Organization region refers to the location you plan to import your TFS collection into Azure
DevOps Services. In Phase 1 you selected a region and recorded its shorthand code to be
used in the prepare command. Just in case, a list of supported regions can be discovered on
the following page https://aka.ms/ImportSupportedRegion.
More information about the prepare command is available at
https://aka.ms/TfsMigratorPrepare.