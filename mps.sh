#!/usr/bin/env bash

# MPS (mplayer script) 2022 Marc Carlson
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
eq_settings="8:7:4:1:1:0:1:2:5:5"

function usage {
echo ""
echo "  MPS - Mplayer script 2022 Marc Carlson"
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
echo "  showlist - show remaining tracks in playlist"
echo "  pause - pause/unpause music"
echo "  mute - toggle mplayer mute"
echo "  next - play next track in playlist"
echo "  previous - play previous track in playlist"
echo "  repeat - repeat the currently playing track once"
echo "  stop - stop playback"
echo "  trackinfo - show info about currently playing track"
echo "  albuminfo - show album information"
echo "  status - show time remaining and percent finished"
echo "  playtime - show remaining tracks and time of playlist"
echo "  delete <track number> - delete track"
echo "  clear - clear playlist"
echo "  queued - show next track in queue"
echo ""
echo "  save <playlist> - save playlist"
echo "  update <playlist> - update playlist"
echo "  load <playlist> - load playlist"
echo "  remove <playlist> - remove playlist"
echo "  lsplaylists - show playlists"
echo ""
echo "  -s) shuffle songs (random) - use with play"
echo "  -r) repeat playlist - use with play"
echo "  -e) use equalizer - use with play"
echo "  -n) use notifications - use with play"
echo ""
echo "  notify - turn on notifications"
echo "  notify off - turn off notifications"
echo ""
echo "  eq - turn on equalizer"
echo "  eq off - turn off equalizer"
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
[ "$?" -ne 0 ] && echo "Please install ffmpeg before using this script." && exit
type -P shuf 1>/dev/null
[ "$?" -ne 0 ] && echo "Please install shuf before using this script." && exit
if [[ ! -d $music ]]; then echo $music does not exist, edit your music directory in the MPS script. && exit
fi

function ls {
find $music -maxdepth 1 -type f -exec basename {} \;| sort
}

function title {
for file in $music/*.mp3
do
[[ $(mp3info -p '%t' "$file") == "$@"* ]] && echo $file | awk -F "/" '{print $NF}'
done
}

function album {
for file in $music/*.mp3
do
[[ $(mp3info -p '%l' "$file") == "$@"* ]] && echo $file | awk -F "/" '{print $NF}'
done
}

function artist {
for file in $music/*.mp3
do
[[ $(mp3info -p '%a' "$file") == "$@"* ]] && echo $file | awk -F "/" '{print $NF}'
done
}

function genre {
for file in $music/*.mp3
do
[[ $(mp3info -p '%g' "$file") == "$@"* ]] && echo $file | awk -F "/" '{print $NF}'
done
}

function year {
string="$1"
IFS='-' read -ra split <<< "$string"
for file in $music/*mp3
do
year=$(mp3info -p '%y\n' "$file")
[[ ! "${split[1]}" ]] && [[ $year -eq $1 ]] &&
printf "$file" | awk -F "/" '{print $NF}'
[[ $year -ge "${split[0]}" ]] && [[ $year -le ${split[1]} ]] &&        
printf "$file" | awk -F "/" '{print $NF}' || [[ $year -eq "1" ]]
done
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
[[ -f $playlists/.state ]] &&
random=$(cat $playlists/.state | grep 1)

function add {
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
song=$(cat /tmp/log | grep Playing | sed 's/Playing//g' | sed 's/ //1'| sed 's/.$//1' | tail -n 1) 
echo 'loadfile "$song"' 2 > /tmp/fifo
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
rm /tmp/playlist
[[ -f /tmp/2 ]] && rm /tmp/2
echo "0" > $playlists/.state
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
number=$(cat /tmp/playlist | wc -l | awk '{print $1}')
printf "$(mp3info -p '%a - %t (%m:%02s)' "$song")\n"
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
#random=$(ps -x | grep mplayer | grep -v grep | if grep -q '\-shuffle'; then printf " Random: on"; else printf " Random: off"; fi)
repeat=$(ps -x | grep mplayer | grep -v grep | if grep -q '\-loop 0'; then printf " Repeat: on"; else printf " Repeat: off"; fi)
random=$(if [[ $(cat $playlists/.state) == "1" ]]; then printf " Random: on"; else printf " Random: off"; fi)
notify=$(ps -x | grep tail | grep -v grep | if grep -q 'tail -n 25 -f /tmp/log'; then printf " Notify: on"; else printf " Notify: off\n"; fi)
eq=$(ps -x | grep tail | grep -v grep | if grep -q "tail -n 24 -f /tmp/log"; then printf " Equalizer: on"; else printf " Equalizer: off\n"; fi)
printf "Time Remaining: %d:%02d/$duration - ($percent%%) $random $repeat $eq\n" $((remain / 60 % 60)) $((remain % 60))
}


function playtime {
[[ -f $playlists/.state ]] &&
[[ $(cat $playlists/.state) == "1" ]] && playlist="/tmp/2" || playlist="/tmp/playlist"
[[ ! -f /tmp/playlist ]] && printf "No songs in playlist\n" && exit
number=$(cat $playlist | wc -l | awk '{print $1}')
[[ $test ]] &&
song=$(cat /tmp/log | grep Playing | sed 's/Playing//g' | sed 's/ //1'| sed 's/.$//1' | tail -n 1) 
if [[ ! $test ]]
then
while read line
do
length=$(mp3info -p '%S' "$line")
duration=$((duration+length))
done< $playlist
else
while read -r line
do
length=$(mp3info -p '%S' "$line")
duration=$((duration+length))
done< <(grep -A $(($number-1)) "$song" $playlist)
fi
if [[ ! $test ]]
then
[[ $number == "1" ]] && num="track" || num="tracks"
printf "$number $num total - Total playtime: %02d:%02d:%02d\n" $((duration / 3600)) $((duration / 60 % 60)) $((duration % 60)) && exit
fi
[[ $test ]] &&
echo get_time_pos > /tmp/fifo
sleep 0.3
position=$(cat /tmp/log | grep TIME | sed 's/ANS_TIME_POSITION=//g' | sed 's/\..*//' | tail -n 1)
song=$(cat /tmp/log | grep Playing | sed 's/Playing//g' | sed 's/ //1'| sed 's/.$//1' | tail -n 1) 
length=$(mp3info -p '%S' "$song")
duration=$((duration+length))
time=$((duration-position))
remain=$((duration-length-position))
count=$(cat $playlists/.count)
#[[ -f $playlists/.previous ]] && previous=$(cat $playlists/.previous)
left=$((number-count))
if [[ $left == "1" ]] && num="track" || num="tracks"
then
printf "$left $num remaining - Time remaining: %02d:%02d:%02d\n" $((remain / 3600)) $((remain / 60 % 60)) $((remain % 60))
fi
}

function save {
if [[ $(cat $playlists/.state) == "1" ]]
then
playlist="/tmp/2"
else 
playlist="/tmp/playlist"
fi
[[ ! -d $playlists ]] && mkdir -p $playlists
[[ $1 ]] && [[ ! -f $playlists/$1 ]] &&
cp $playlist $playlists/$1 && exit
printf "Playlist already exists - Use mps update\n" && exit
}

function update {
[[ -z $1 ]] && echo Enter playlist name - mps update playlist && exit
[[ -f $playlists/$2 ]] && [[ $1 == "sort" ]] && cat /tmp/playlist | sort /tmp/playlist -o $playlists/$2 && cp $playlists/$2 /tmp/playlist && exit
[[ -f $playlists/$1 ]] && cp /tmp/playlist $playlists/$1 && exit
echo "Playlist doesn't exist. Use mps save"
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
[[ -d $playlists ]] && find $playlists -type f  ! -name ".*"  -exec basename {} \;  && exit
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
[[ -f $playlists/.state ]] &&
echo "0" > $playlists/.state
[[ $test ]] && pkill mplayer && exit
echo mps already stopped && exit
}

function notify {
if [[ $1 == "off" ]]
then
pid2=$(ps -x | grep tail | grep -v grep | grep "tail -n 25 -f /tmp/log" | awk '{print $1}')
kill $pid2 2>/dev/null
else
ps -x | grep tail | grep -v grep | if grep -q 'tail -n 25 -f /tmp/log'; then echo notify already enabled && exit
elif pgrep -x mplayer >/dev/null; then
(tail -n 25 -f /tmp/log  | grep --line-buffered "Playing" |  while read line
do
song=$(cat /tmp/log | grep Playing | sed 's/Playing//g' | sed 's/ //1'| sed 's/.$//1' | tail -n 1) 
ffmpeg -y -i "$song" /tmp/album.jpg &
wait
notify-send -i /tmp/album.jpg "Now Playing" "$(mp3info -p '%a - %t' "$song")"
done > /dev/null 2>&1 &)
fi
fi
}

function counting {
[[ ! -d $playlists ]] && mkdir -p $playlists
(tail -n 26 -f /tmp/log  | grep --line-buffered "Playing" |  while read line
do
((count++))
echo $count > $playlists/.count
done > /dev/null 2>&1 &)
kill_tail &
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
pid2=$(ps -x | grep tail | grep -v grep | grep "tail -n 26 -f /tmp/log" | awk '{print $1}')
kill $pid 2>/dev/null
kill $pid2 2>/dev/null
break
fi
done
}

function queued {
[[ ! $test ]] && echo start playback of playlist to see the next song in the queue && exit
if [[ $(cat $playlists/.state) == "0" ]]
then
playlist="/tmp/playlist"
else
playlist="/tmp/2"
fi
song=$(cat /tmp/log | grep Playing | sed 's/Playing//g' | sed 's/ //1'| sed 's/.$//1' | tail -n 1) 
while read second_line;
do
if [[ "$second_line" == "$song" ]]
then
if read -r song
then
printf "$(mp3info -p '%a - %t' "$song")\n" 
fi
fi
done< $playlist
}

function shuffle {
shuf /tmp/playlist > /tmp/2
}

function eq {
[[ ! -e $playlists/.eq_state ]] && touch $playlists/.eq_state
if [[ $1 == "off" ]]; then
echo "af_clr" > /tmp/fifo
echo "0" > $playlists/.eq_state
pid6=$(ps -x | grep "tail -n 24 -f /tmp/log" | awk '{print $1}')
kill $pid6 2>/dev/null
else
ps -x | grep tail | grep -v grep | if grep -q 'tail -n 24 -f /tmp/log'; then echo equalizer already enabled && exit
elif pgrep -x mplayer >/dev/null; then
echo "af_add equalizer=$eq_settings" > /tmp/fifo
echo "1" > $playlists/.eq_state 
(tail -n 24 -f /tmp/log  | grep --line-buffered "Playing" |  while read line
do
echo "af_add equalizer=$eq_settings" > /tmp/fifo
echo "1" > $playlists/.eq_state
done > /dev/null 2>&1 &)
else
echo mplayer is not running && exit
fi
fi
kill_eq &
}

function kill_eq {
while true; do
if pgrep -x mplayer >/dev/null
then
sleep 1
else
pid6=$(ps -x | grep tail | grep -v grep | grep 'tail -n 24 -f /tmp/log' | awk '{print $1}')
kill $pid6 2>/dev/null
echo "0" > $playlists/.eq_state
break
fi
done
}

function play {
[[ ! -f $playlists/.state ]] && mkdir -p $playlists
echo 0 > $playlists/.state
#echo 0 > $playlists/.eq_state
[[ $test ]] && echo mplayer already running && exit
[[ ! -f /tmp/playlist ]] && echo No songs in playlist && exit
[[ ! -e /tmp/fifo ]] && mkfifo /tmp/fifo
[[ -e /tmp/log ]] && rm /tmp/log
[[ "$@" =~ 'r' ]] && repeat="-loop 0"
[[ "$@" =~ 's' ]] && (shuffle &) && echo "1" > $playlists/.state
[[ "$@" =~ 's' ]] && playlist=/tmp/2 || playlist=/tmp/playlist &&
(mplayer $repeat -slave -input file=/tmp/fifo -playlist $playlist > /tmp/log 2>&1 &)
[[ "$@" =~ 'n' ]] && notify &
[[ "$@" =~ 'e' ]] && eq &
counting &
}

get_args $@
$@
