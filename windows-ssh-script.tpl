add-content -path c:/users/dvlad/.ssh/config -value @'

Host ${hostname}
    HostName ${hostname}
    User ${user}
    IdentityFile ${IdentityFile}
'@
