on alfred_script(q)
  set kitty to "/opt/homebrew/bin/kitty"
  set kitten to "/opt/homebrew/bin/kitten"
  do shell script "
    q=" & quoted form of q & "
    cmd=\"$q; exec /bin/zsh -i\"
    sock=$(ls -t /tmp/kitty-* 2>/dev/null | head -n1)
    if [ -n \"$sock\" ] && " & quoted form of kitten & " @ --to \"unix:$sock\" ls >/dev/null 2>&1; then
      " & quoted form of kitten & " @ --to \"unix:$sock\" launch --type=tab --cwd=$HOME /bin/zsh -i -c \"$cmd\"
    else
      " & quoted form of kitty & " --single-instance -d ~ /bin/zsh -i -c \"$cmd\" >/dev/null 2>&1 &
    fi
  "
  tell application "kitty" to activate
end alfred_script
