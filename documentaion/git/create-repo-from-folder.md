# Repo Management

## Create a new repo from folders of an existing repo

To create a new repo from a folder of an existing repo while preserving history requires some special operations. The original repo needs to be copied and all commits not related to the target folder are removed.

A step by step can be found on GitHub Help:

https://help.github.com/en/articles/splitting-a-subfolder-out-into-a-new-repository


## Merging a repo into an existing repo

The following step by step adds a remote, "projectB" into an existing git repo.

1. git remote add -f projectB /path/to/B
1. git merge -s ours --allow-unrelated-histories --no-commit Bproject/master
1. git read-tree --prefix=dir-B/ -u Bproject/master
1. git commit -m "Merge B project as our subdirectory"
1. git pull -s subtree Bproject master

(Option --allow-unrelated-histories is needed for Git >= 2.9.0.)




