# Overview

Git Version Control (aka Git VC)
TF Version Control (aka TFVC)


# Git Migration
Clone repos

Import manually if source is available to Azure DevOps Org

Scripts can automate mirating a large number of repos

# TF Migration

For several years now, most TF migrations have been one of the following:

1. Migrate from TF to Git
2. Full fidelity migrations which preserve the TF database intact

## TF to Git

[git-tfs tool](https://github.com/git-tfs/git-tfs)

## TF to TF
Clone repo
Note target needs repo initialized

### TF Tip Migration
1. Copy latest source, typically manually, from source to target
2. Workspace on source references old location
3. Workspace on target references new location

Typically takes one branch, though, multiple branches can be taken by repeating the process for each branch

### History Migration
- Challenging and not ideal
- 3rd party apps exist
- Challenge!!!
