#!/bin/sh

# 2014-02-11 THIS CAN FAIL WHEN THE SCRIPT ICON IS NOT SELECTED
# cd `dirname "$( osascript<<END
# tell application "Finder" to set the d to selection as alias
# set result to (POSIX path of the d as string)
# END
# )"`

DIR=$(cd "$(dirname "$0")" && pwd)
cd "$DIR"
exec ./tsh.pl
