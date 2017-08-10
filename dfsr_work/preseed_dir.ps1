# Preseed a DFSR directory folder examples:

# Initial Seed
PS C:\data\second_holder\finance> Robocopy.exe “\\member1\c$\data” “C:\data” /b /e /copyall /r:6 /xd dfsrprivate /log:robo.log /tee
