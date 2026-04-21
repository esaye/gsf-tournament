IF EXIST C:\Strawberry\perl\bin\perl.exe (
  C:\Strawberry\perl\bin\perl.exe util\mirror-ftp %*
) ELSE IF EXIST C:\Perl\bin\perl.exe (
  C:\Perl\bin\perl.exe util\mirror-ftp %*
) ELSE IF EXIST C:\Perl64\bin\perl.exe (
  C:\Perl64\bin\perl.exe util\mirror-ftp %*
) ELSE (
  perl util\mirror-ftp %*
)
@ping 127.0.0.1 -n 10 -w 1000 > nul
