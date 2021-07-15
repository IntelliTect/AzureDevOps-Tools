# git repo management

Options for managing repo, splitting and merging

## git filter-branch
Rewrites revision history

Can be used to remove folders not required, or, maintain a single folder

git clone 

git filter-branch --index-filter 'git rm --cached -r ActiveDirectory || true' -- --all

git filter-branch --index-filter 'git rm --cached -r lildir lildir2' -- --all

##  notes

#1 Create a sparse clone of the source repo

git config core.sparsecheckout true
git remote add migrator C:\dev\azure-devops-migration-tools\

Set-Content .git\info\sparse-checkout "src/VstsSyncMigrator.Core/Commands" -Encoding Ascii
Add-Content .git\info\sparse-checkout "src/VstsSyncMigrator.Console"

git pull migrator master

- or -

git fetch

#2 Merget that clone into our target repo


***

## Sparse clones
Sparse clones all you to clone a portion of a repo when you don't want or need the repo.

History/indexes/commits and such are maintained in the repo. Cloning a sparse clone does not remove files.

git init
git remote add -f migrator C:\dev\azure-devops-migration-tools\
git config core.sparseCheckout true 

Set-Content .git\info\sparse-checkout "src/VstsSyncMigrator.Core/Commands" -Encoding Ascii
Add-Content .git\info\sparse-checkout "src/VstsSyncMigrator.Console"

git fetch migrator                                                                                                            
git merge --allow-unrelated-histories migrator/master  









## Step 2, merge that sparse clone into a specific folder

