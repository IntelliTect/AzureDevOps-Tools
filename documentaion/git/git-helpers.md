
# git gotchas

## Cleaning your local drive
Git does not always remove empty folders and untracked files such as binaries when merging into your workspace. To clean up after git, you can perform a git clean:

```
git clean -dxf
```
d is for directories, x is to cleanup untracked files and f is to force the operation


### Forgetting the commit message
If you performa a "git commit" with the "-m" commit message, git will by default pull up a VI editor.

Use esc :wq to save your message and exit

### 
Git, know that this has little to do with git but with the text editor configured for use. In vim, you can press i to start entering text and save by pressing esc and :wq and enter, this will commit with the message you typed. In your current state, to just come out without committing, you can do :q instead of the :wq as mentioned above.

Alternatively, you can just do git commit -m '<message>' instead of having git open the editor to type the message.

Note that you can also change the editor and use something you set the core.editor configuration values


Set the editor to Notepad++
```
git config --global core.editor "'c:\Program Files\Notepad++\notepad++.exe\'"
```

Set the editor to VS Code
```
git config --global core.editor "'C:\Program Files\Microsoft VS Code\Code.exe'"
```

to list all global configuraiton values:
```
git config --global --list 
```