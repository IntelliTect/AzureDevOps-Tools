# UHS Branching Strategy

Branching strategy guidelines:
- Keep things as simple as possible.
- Add branching complexity when you need it
- Frequent merges keep changes small and merge conflicts low
- Easier to code review

The recommended approach is modeled after branching strategy described here:
[Branching Strategy](https://docs.microsoft.com/en-us/azure/devops/repos/git/git-branching-guidance?view=azure-devops)

Summary:
1. Master Branch has latest and greatest
2. Create Feature or Bug fix branches from Master
3. Features branches that span a release are "feature flagged"
4. Create a Release Branch to reflect what's being released

## Release Branches
Release branches provide ready access to code that has been deployed.

Remove branches once 