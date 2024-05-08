#!/usr/bin/env bash

# MPS (mplayer script) (2022) Marc Carlson

# My other repositories: https://github.com/carls0n/

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
#eq_settings="2:8:2:1:1:0:1:2:5:2"
eq_settings="4:8:3:4:1:1:3:4:6:6"

function usage {
echo ""
echo "  MPS - Mplayer script (2022 Marc Carlson)"
echo "  Usage: mps [options]"
echo ""
echo "  title <title> - search tracks by title"
echo "  album <album> - search tracks by album"
echo "  genre <genre> - search tracks by genre"
echo "  artist <artist> - search tracks by artist"
echo "  year <range> - search by year (1970-1979)"
echo ""
echo "  ls - list tracks in directory"
echo "  add - add tracks. Can also be used with ls"
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
echo "  albuminfo - show album information"
echo "  status - show time remaining and percent finished"
echo "  playtime - show total duration of playlist"
echo "  delete <track number> - delete track"
echo "  clear - clear playlist"
echo ""
echo "  save <playlist> - save playlist"
echo "  load <playlist> - load playlist"
echo "  remove <playlist> - remove playlist"
echo "  lsplaylists - show playlists"
echo ""
echo "  -s) shuffle songs (random) - use with play"
echo "  -r) repeat playlist - use with play"
echo ""
echo "  notify - turn on notifications"
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

function ls {
find $music -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.aac" \)  -exec basename {} \;| sort
}

function title {
for file in $music/*.mp3
do
[[ $(mp3info -p '%t' "$file") == "$@"* ]] && echo $file | awk -F "/" '{print $NF}'
done | sort
}

function album {
for file in $music/*.mp3
do
[[ $(mp3info -p '%l' "$file") == "$@"* ]] && echo $file | awk -F "/" '{print $NF}'
done | sort
}

function artist {
for file in $music/*.mp3
do
[[ $(mp3info -p '%a' "$file") == "$@"* ]] && echo $file | awk -F "/" '{print $NF}'
done | sort
}

function genre {
for file in $music/*.mp3
do
[[ $(mp3info -p '%g' "$file") == "$@"* ]] && echo $file | awk -F "/" '{print $NF}'
done | sort
}

function year {
string="$1"
IFS='-' read -ra split <<< "$string"
for file in $music/*.mp3
do
year=$(mp3info -p '%y\n' "$file")
[[ ! "${split[1]}" ]] && [[ $year -eq $1 ]] &&
printf "$file" | awk -F "/" '{print $NF}'
[[ $year -ge "${split[0]}" ]] && [[ $year -le ${split[1]} ]] &&        
printf "$file" | awk -F "/" '{print $NF}' || [[ $year -eq "1" ]]
done | sort
}

function playing {
while read -r results
do
echo "$music/$results" >> /tmp/playlist && echo "$music/$results" >> /tmp/new
done &&
echo "loadlist /tmp/new 2" >> /tmp/fifo
}

function not_playing {
while read -r results
do
echo "$music/$results" >> /tmp/playlist 
done
}

function shuffle_error {
printf "Cannot add tracks in shuffle mode\n" && exit
}

test=$(pgrep mplayer)
random=$(ps -A | grep mplayer | grep -v grep | grep shuffle)

function add {
[[ $1 ]] && echo "Use mps title \"title\" | mps add" && exit
[[ -e /tmp/new ]] && rm /tmp/new
[[ $random ]] && shuffle_error && exit
[[ $test ]] && [[ -z $random ]] && playing && exit || not_playing && exit
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
[[ ! -f /tmp/playlist ]] && echo No songs in playlist && exit
[[ $test ]] && pkill mplayer
rm /tmp/playlist && exit
}

function showlist {
[[ ! -f /tmp/playlist ]] && echo No songs in playlist && exit
if [[ ! $1 ]]
then
while read line
do
printf "$(mp3info -p '%a - %t' "$line")\n"
done< /tmp/playlist
elif [[ $1 == "-n" ]]
then
while read line
do
printf "$(mp3info -p '%a - %t' "$line")\n"
done< /tmp/playlist | cat -n | awk '{$1=$1; print}'
fi
}

function trackinfo {
if pgrep -x mplayer > /dev/null
then
song=$(cat /tmp/log | grep Playing | sed 's/Playing//g' | sed 's/ //1'| sed 's/.$//1' | tail -n 1) 
count=$(cat -n /tmp/playlist | grep "$song" | awk '{print $1}')
number=$(cat /tmp/playlist | wc -l | awk '{print $1}')
printf "Track $count/$number - $(mp3info -p '%a - %t (%m:%02s)' "$song")\n"
else printf "mplayer is not running.\n"
fi
}

function status {
[[ ! $test ]] && printf "mplayer is not running\n" && exit
echo get_time_pos > /tmp/fifo
echo get_percent_pos > /tmp/fifo
sleep 0.3
position=$(cat /tmp/log | grep TIME | sed 's/ANS_TIME_POSITION=//g' | sed 's/\..*//' | tail -n 1)
song=$(cat /tmp/log | grep Playing | sed 's/Playing//g' | sed 's/ //1'| sed 's/.$//1'| tail -n 1) 
sec=$(mp3info -p "%S" "$song")
remain=$((sec-position))
duration=$(mp3info -p '%m:%02s' "$song")
percent=$(tail /tmp/log | grep PERCENT | sed 's/ANS_PERCENT_POSITION=//g' | tail -n 1)
random=$(ps -x | grep mplayer | grep -v grep | if grep -q '\-shuffle'; then printf " Random: on"; else printf " Random: off"; fi)
repeat=$(ps -x | grep mplayer | grep -v grep | if grep -q '\-loop 0'; then printf " Repeat: on"; else printf " Repeat: off\n"; fi)
printf "Time Remaining: %d:%02d/$duration - ($percent%%) $random $repeat\n" $((remain / 60 % 60)) $((remain % 60))
}

function playtime  {
[[ ! -f /tmp/playlist ]] &&  printf "No songs in playlist\n" && exit
while read song; do
length=$(mp3info -p '%S ' "$song")
duration=$((duration+length))
done< /tmp/playlist
number=$(cat /tmp/playlist | wc -l | awk '{print $1}')
printf "$number tracks - Total playtime: %02d:%02d:%02d\n" $((duration / 3600)) $((duration / 60 % 60)) $((duration % 60))
}

function save {
[[ ! -d $playlists ]] && mkdir $playlists
[[ $1 ]] && [[ ! -f $playlists/$1 ]] &&
cp /tmp/playlist $playlists/$1 && exit
printf "Playlist already exists\n"
}

function load {
[[ $random ]] && shuffle_error && exit
[[ ! -f $playlists/$1 ]] && echo "Playlist doesn't exist." && exit
[[ $test ]] &&
cat $playlists/$1 >> /tmp/playlist &&
echo "loadlist $playlists/$1 2" > /tmp/fifo &&
echo "Playlist loaded -> $1" && exit
cat $playlists/$1 >> /tmp/playlist
echo "Playlist loaded -> $1"
}

function lsplaylists {
[[ -d $playlists ]] && find $playlists -type f -exec basename {} \; && exit
printf "no playlists found\n"
}

function remove {
[[ -f $playlists/$1 ]] && rm $playlists/$1 && exit
printf "No such playlist\n"
}

function delete {
[[ $test ]] && echo cannot delete tracks during playback && exit
sed -i "$1"'d' /tmp/playlist && exit
}

function stop {
[[ $test ]] && pkill mplayer && exit
echo mps already stopped && exit
}

function notify {
ps -x | grep tail | grep -v grep | if grep -q 'tail -n 25 -f /tmp/log'; then echo notify already enabled && exit
elif pgrep -x mplayer >/dev/null; then
(tail -n 25 -f /tmp/log  | grep --line-buffered "Playing" |  while read line
do
song=$(cat /tmp/log | grep Playing | sed 's/Playing//g' | sed 's/ //1'|sed 's/.$//1' | tail -n 1) 
ffmpeg -y -i "$song" /tmp/album.jpg &
wait
notify-send -i /tmp/album.jpg "Now Playing" "$(mp3info -p '%a - %t' "$song")"
done > /dev/null 2>&1 &)
kill_tail &
fi
}

function albuminfo {
song=$(cat /tmp/log | grep Playing | sed 's/Playing//g' | sed 's/ //1'| sed 's/.$//1' | tail -n 1)
printf "$(mp3info -p '%a - %l (%y)\n' "$song")\n"
}

function kill_tail {
while true; do
if pgrep -x mplayer >/dev/null
then
sleep 1
else
pid=$(ps -x | grep tail | grep -v grep | grep "tail -n 25 -f /tmp/log" | awk '{print $1}')
kill $pid 2>/dev/null
break
fi
done
}

function play {
[[ ! -f /tmp/playlist ]] && echo No songs in playlist && exit
[[ ! -e /tmp/fifo ]] && mkfifo /tmp/fifo
[[ -e /tmp/log ]] && rm /tmp/log
[[ $1 == "-s" ]] || [[ $2 == "-s" ]] && shuffle="-shuffle"
[[ $1 == "-r" ]] || [[ $2 == "-r" ]] && repeat="-loop 0"
[[ $1 == "-rs" ]] || [[ $1 == "-sr" ]] && repeat="-loop 0" && shuffle="-shuffle"
[[ $test ]] && echo mplayer already running && exit
( mplayer $shuffle $repeat -slave -input file=/tmp/fifo -playlist /tmp/playlist -af equalizer="$eq_settings" > /tmp/log 2>&1 &)
}

get_args $@
$@
