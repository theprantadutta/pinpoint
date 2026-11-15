# usage: source rec.sh; recstart N; ...actions...; recstop N
export MSYS_NO_PATHCONV=1
A="adb -s RR8W901JDRL"
V="C:/Users/pranta/AppData/Local/Temp/claude/df2778a8ef02d273/4b8df593-8fd7-413c-9714-76d1fe04163f/scratchpad/vid"
recstart() { ( $A shell screenrecord --bit-rate 16000000 /sdcard/pp_rec$1.mp4 >/dev/null 2>&1 & ); sleep 1.5; }
recstop() { sleep 1; $A shell pkill -INT screenrecord; sleep 3; $A pull /sdcard/pp_rec$1.mp4 "$V/rec$1.mp4" >/dev/null && $A shell rm /sdcard/pp_rec$1.mp4; ls -la "$V/rec$1.mp4"; }
tap() { $A shell input tap $1 $2; }
swipe() { $A shell input swipe $1 $2 $3 $4 ${5:-500}; }
shot() { $A exec-out screencap -p > "$V/$1.png"; }
