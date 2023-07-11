#!/usr/bin/env bash

# MPS (mplayer script) 2022-2023 Marc Carlson

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see https://www.gnu.org/licenses/

music=~/Music
playlists=/home/user/.mps
eq_settings="2:7:2:1:1:0:1:2:5:2"

function usage {
echo ""
echo "  MPS - Mplayer script 2022-2023 Marc Carlson"
echo ""
echo "  Usage: mps [options]"
echo ""
echo "  title <title> - search tracks by title"
echo "  album <album> - search tracks by album"
echo "  genre <genre> - search tracks by genre"
echo "  artist <artist> - search tracks by artist"
echo ""
echo "  ls - list songs by filename in directory"
echo "  add - add songs by filename. Can be use with ls"
echo ""
echo "  play - play tracks in playlist"
echo "  showlist - show tracks in playlist"
echo "  pause - pause/unpause music"
echo "  mute - toggle mplayer mute"
echo "  next - play next track in playlist"
echo "  previous - play previous track"
echo "  repeat - repeat the currently playing track once"
echo "  stop - stop playback"
echo "  trackinfo - show info about currently playing track"
echo "  status - show time remaining and percent finished"
echo "  playtime - show total duration of playlist"
echo "  delete <track number> - delete track"
echo "  clear - clear playlist"
echo ""
echo "  save <playlist> - save playlist named <playlist>"
echo "  load <playlist> - load playlist named <playlist>"
echo "  remove <playlist> - remove playlist named <playlist>"
echo "  lsplaylists - show playlists"
echo ""
echo "  -s) shuffle songs (random) - use with play"
echo "  -r) repeat playlist - use with play"
echo ""
}

function get_args {
[ $# -eq 0 ] && usage && exit
while getopts ":h" arg; do
case $arg in
h) usage && exit ;;
esac
done
}

shopt -s nocasematch

type -P mp3info 1>/dev/null
[ "$?" -ne 0 ] && echo "Please install mp3info before using this script." && exit
type -P mplayer 1>/dev/null
[ "$?" -ne 0 ] && echo "Please install mplayer before using this script." && exit
type -P ffmpeg 1>/dev/null
if [[ ! -d $music ]]; then echo $music does not exist, edit your music directory in the MPS script. && exit; fi

function genre {
if [[ -e /tmp/out ]]
then
rm /tmp/out
fi
for file in $music/*.mp3
do if [[ "$(mp3info -p '%g' "$file")" == "$@"* ]]
then
echo $file | awk -F "/" '{print $NF}' >> /tmp/out
fi
done
if [ -e /tmp/out ]
then cat /tmp/out && rm /tmp/out
else echo "No matches found"
fi
}

function album { 
if [[ -e /tmp/out ]]
then
rm /tmp/out
fi
for file in $music/*.mp3
do if [[ "$(mp3info -p '%l' "$file")" == "$@"* ]]
then
echo $file | awk -F "/" '{print $NF}' >> /tmp/out
fi
done
if [ -e /tmp/out ]
then cat /tmp/out && rm /tmp/out
else echo "No matches found"
fi
}

function artist {
if [[ -e /tmp/out ]]
then
rm /tmp/out
fi
for file in $music/*.mp3
do if [[ "$(mp3info -p '%a' "$file")" == "$@"* ]]
then
echo $file | awk -F "/" '{print $NF}' >> /tmp/out
fi
done
if [ -e /tmp/out ]
then cat /tmp/out && rm /tmp/out
else echo "No matches found"
fi
}

function title {
if [[ -e /tmp/out ]]
then
rm /tmp/out
fi
for file in $music/*.mp3
do if [[ "$(mp3info -p '%t' "$file")" == "$@"* ]]
then
echo $file | awk -F "/" '{print $NF}' >> /tmp/out
fi
done
if [ -e /tmp/out ]
then cat /tmp/out && rm /tmp/out
else echo "No matches found"
fi
}

function shuffle_error {
printf "Cannot add tracks in shuffle mode\n" && exit
}

function ls {
find $music -type f -maxdepth 1 -exec basename {} \;| sort
}

function add {
if [[ -e /tmp/new ]]; then rm /tmp/new
fi
test=$(pgrep mplayer)
random=$(ps -A | grep mplayer | grep -v grep | grep shuffle)
if [[ $test ]] && [[ $random ]]; then
shuffle_error
fi

if pgrep -x mplayer >/dev/null &&  [ "$1" ]
then

if [[ ! -f "$music/$@" ]]
then
echo No matches found && exit
fi

echo "$music/$@" >> /tmp/playlist && echo "$music/$@" >> /tmp/new
echo "loadlist /tmp/new 2" > /tmp/fifo && exit

elif ! pgrep -x mplayer >/dev/null && [ "$1" ]
then

if [[ -f "$music/$@" ]]
then
echo "$music/$@" >> /tmp/playlist && exit
fi
echo No matches found && exit
fi

if [[ $test ]] && [[ $random ]]
then
shuffle_error
elif [[ $test ]]
then

while read -r results
do
if [[ -e $music/$results ]]; then
echo "$music/$results" >> /tmp/playlist && echo "$music/$results" >> /tmp/new
else echo No matches found
fi
done
echo "loadlist /tmp/new 2" >> /tmp/fifo

elif [[ -z $test ]]
then
while read -r results
do
if [[ -e $music/$results ]]; then
echo "$music/$results" >> /tmp/playlist
else echo No matches found
fi
done
fi
}

function next {
echo "pausing_keep_force pt_step 1" > /tmp/fifo
}

function previous {
echo "pausing_keep_force pt_step -1" > /tmp/fifo
}

function repeat {
echo loop 2 > /tmp/fifo
}

function pause {
echo "pause" > /tmp/fifo
}

function mute {
echo "mute" > /tmp/fifo
}

function clear {
if  [ ! -f /tmp/playlist ]
then
echo No songs in playlist && exit
fi
rm /tmp/playlist && exit
}

function showlist {
if [ ! -f /tmp/playlist ]
then
echo No songs in playlist && exit
fi
while read line
do
printf "$(mp3info -p '%a - %t' "$line")\n"
done< /tmp/playlist
}

function trackinfo {
if pgrep -x mplayer > /dev/null
then
song=$(cat /tmp/log | grep Playing | sed 's/Playing//g' | sed 's/ //1'| cut -d . -f 1,2 | tail -n 1) 
count=$(cat -n /tmp/playlist | grep "$song" | awk '{print $1}')
number=$(cat /tmp/playlist | wc -l | awk '{print $1}')
printf "Track $count/$number - $(mp3info -p '%y %a - %t (%m:%02s)' "$song")\n"
else printf "mplayer is not running.\n"
fi
}

function status {
if pgrep -x mplayer > /dev/null
then
echo get_time_pos > /tmp/fifo
echo get_percent_pos > /tmp/fifo
sleep 0.001
position=$(cat /tmp/log | grep TIME | sed 's/ANS_TIME_POSITION=//g' | sed 's/\..*//' | tail -n 1)
song=$(cat /tmp/log | grep Playing | sed 's/Playing//g' | sed 's/ //1'| cut -d . -f 1,2 | tail -n 1) 
sec=$(mp3info -p "%S" "$song")
remain=$((sec-position))
duration=$(mp3info -p '%m:%02s' "$song")
percent=$(tail /tmp/log | grep PERCENT | sed 's/ANS_PERCENT_POSITION=//g' | tail -n 1)
random=$(ps -A | grep mplayer | grep -v grep | if grep -q '\-shuffle'; then printf " Random: on"; else printf " Random: off"; fi)
repeat=$(ps -A | grep mplayer | grep -v grep | if grep -q '\-loop 0'; then printf " Repeat: on"; else printf " Repeat: off\n"; fi)
printf "Time Remaining: %d:%02d/$duration - ($percent%%) $random $repeat\n" $((remain / 60 % 60)) $((remain % 60))
else printf "mplayer is not running.\n"
fi
}

function playtime  {
if [ -f /tmp/playlist ]
then
while read song; do
length=$(mp3info -p '%S ' "$song")
duration=$((duration+length))
done< /tmp/playlist
number=$(cat /tmp/playlist | wc -l | awk '{print $1}')
printf "$number tracks - Total playtime: %02d:%02d:%02d\n" $((duration / 3600)) $((duration / 60 % 60)) $((duration % 60))
else printf "No songs in playlist.\n"
fi
}

function save {
if [ ! -d ~/.mps ]
then
mkdir ~/.mps
fi
if [ $1 ]
then
if [ ! -f ~/.mps/$1 ]
then
cp /tmp/playlist ~/.mps/$1
else
printf "Playlist already exists\n"
fi
fi
}

function load {
ps -A | grep mplayer | grep -v grep | if grep -q 'shuffle'; then echo cannot add tracks in shuffle mode && exit
else
if [ ! -f ~/.mps/$1 ]
then
echo "Playlist doesn't exist." && exit
else
if pgrep -x mplayer >/dev/null
then
cat ~/.mps/$1 >> /tmp/playlist
echo "loadlist $playlists/$1 2" > /tmp/fifo
echo "Playlist loaded -> $1"
elif ! pgrep -x mplayer >/dev/null
then
cat ~/.mps/$1 >> /tmp/playlist
echo "Playlist loaded -> $1"
fi
fi
fi
}

function lsplaylists {
if [ -d ~/.mps ]
then
find ~/.mps/ -type f -exec basename {} \;
else
printf "no playlists found\n"
fi
}

function remove {
if [ -f ~/.mps/$1 ]
then
rm ~/.mps/$1
else
printf "No such playlist\n"
fi
}

function delete {
if pgrep -x mplayer >/dev/null
then
echo cannot delete tracks during playback
else
sed -i "$1"'d' /tmp/playlist && exit
fi
}

function stop {
if pgrep -x mplayer  >/dev/null
then
pkill mplayer
else echo mps already stopped && exit
fi
}

function play {
if [ ! -f /tmp/playlist ]
then
echo No songs in playlist && exit; fi
if [[ $1 == "-s" ]] || [[ $2 == "-s" ]]
then
shuffle="-shuffle"; fi
if [[ $1 == "-r" ]] || [[ $2 == "-r" ]]
then
repeat="-loop 0"; fi
if [[ $1 == "-rs" ]] || [[ $1 == "-sr" ]]
then
repeat="-loop 0" && shuffle="-shuffle"; fi
if pgrep -x mplayer >/dev/null
then
echo mplayer already running && exit
else
if [[ ! -e /tmp/fifo ]]
then
mkfifo /tmp/fifo; fi
( mplayer $shuffle $repeat -slave -input file=/tmp/fifo -playlist /tmp/playlist -af equalizer="$eq_settings" > /tmp/log 2>&1 &)
fi
}

get_args $@
$@
