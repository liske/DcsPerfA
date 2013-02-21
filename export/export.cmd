set BCP=C:\Program Files\Microsoft SQL Server\110\Tools\Binn\bcp.exe

"%BCP%" DcsA.dbo.CounterDefs out CouterDefs.csv -T -Slocalhost\SQLEXPRESS -c
"%BCP%" DcsA.dbo.CounterData out CouterData.csv -T -Slocalhost\SQLEXPRESS -c

pause
