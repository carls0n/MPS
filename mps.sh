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
playlists=~/.mps
fifo=/tmp/fifo
eq_settings="8:7:4:1:1:0:1:2:5:5"

cleanup() {
  if ! pgrep -x mplayer >/dev/null; then
    pid=$(pgrep -f "tail -n 25 -f /tmp/log")
    pid2=$(pgrep -f "tail -n 26 -f /tmp/log")
    kill "$pid" 2>/dev/null
    kill "$pid2" 2>/dev/null

    files=(/tmp/log "$fifo" /tmp/album.jpg "$playlists/.shuffled")
    for file in "${files[@]}"; do
      [[ -e "$file" ]] && rm "$file"
    done
  fi
}

trap 'cleanup' EXIT

usage() {
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
  echo "  -n) use notifications - use with play"
  echo ""
  echo "  notify - turn on notifications"
  echo "  notify off - turn off notifications"
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

parse_options() {
    local OPTIND=1
    local opt
    shuf_enabled=0 
    repeat_enabled=0


    while getopts "nsr" opt "${@:2}"; do
        case $opt in
            s) shuf_enabled=1 ;;
            r) repeat_enabled=1 ;;
            n) notify ;;
            *) ;;
        esac
    done
}

shopt -s nocasematch

type -P mp3info >/dev/null || { echo "Please install mp3info before using this script."; exit; }
type -P mplayer >/dev/null || { echo "Please install mplayer before using this script."; exit; }
type -P ffmpeg >/dev/null || { echo "Please install ffmpeg before using this script."; exit; }
type -P shuf >/dev/null || { echo "Please install shuf before using this script."; exit; }

[[ ! -d $music ]] && echo "$music does not exist, edit your music directory in the MPS script." && exit

ls() {
  find "$music" -maxdepth 1 -type f -exec basename {} \; | sort
}

title() {
  for file in "$music"/*.mp3; do
    [[ $(mp3info -p '%t' "$file") == "$@"* ]] && basename "$file"
  done
}

album() {
  for file in "$music"/*.mp3; do
    [[ $(mp3info -p '%l' "$file") == "$@"* ]] && basename "$file"
  done
}

artist() {
  for file in "$music"/*.mp3; do
    [[ $(mp3info -p '%a' "$file") == "$@"* ]] && basename "$file"
  done
}

genre() {
  for file in "$music"/*.mp3; do
    [[ $(mp3info -p '%g' "$file") == "$@"* ]] && basename "$file"
  done
}

year() {
  string="$1"
  IFS='-' read -ra split <<< "$string"

  for file in "$music"/*.mp3; do
    year=$(mp3info -p '%y' "$file")

    if [[ -z "${split[1]}" ]]; then
      [[ $year -eq $1 ]] && basename "$file"
    else
      [[ $year -ge "${split[0]}" && $year -le "${split[1]}" ]] && basename "$file"
    fi
  done
}

playing() {
  while read -r results; do
    echo "$music/$results" >> "$playlists/current"
    echo "$music/$results" >> /tmp/new
  done

  echo "loadlist /tmp/new 2" >> "$fifo"
}

not_playing() {
  while read -r results; do
    echo "$music/$results" >> "$playlists/current"
  done
}

shuffle_error() {
  printf "Cannot add tracks in shuffle mode\n"
  exit
}

test=$(pgrep mplayer)
[[ -f $playlists/.state ]] && random=$(grep 1 "$playlists/.state")

add() {
  [[ ! -d $playlists ]] && mkdir -p "$playlists"
  [[ -e /tmp/new ]] && rm /tmp/new
  [[ $random ]] && shuffle_error

  if [[ $test ]] && [[ -z $random ]]; then
    playing
  else
    not_playing
  fi

  exit
}

next() {
  echo "pausing_keep_force pt_step 1" > "$fifo"
}

previous() {
  echo "pausing_keep_force pt_step -1" > "$fifo"
}


repeat() {
  echo "loop 2" > "$fifo"
  song=$(grep Playing /tmp/log | sed 's/Playing//; s/^ //; s/.$//' | tail -n 1)
  echo "loadfile \"$song\"" > "$fifo"
}

pause() {
  echo "pause" > "$fifo"
}

mute() {
  echo "mute" > "$fifo"
}

clear() {
  [[ ! -f $playlists/current ]] && echo "No songs in playlist" && exit
  [[ $test ]] && pkill mplayer

  rm "$playlists/current"
  [[ -f $playlists/.shuffled ]] && rm "$playlists/.shuffled"

  echo "0" > "$playlists/.state"
  cleanup
}

showlist() {
  [[ ! -f $playlists/current ]] && echo "No songs in playlist" && exit

  if [[ -z $1 ]]; then
    while IFS= read -r line; do
      printf "%s\n" "$(mp3info -p '%a - %t' "$line")"
    done < "$playlists/current"

  elif [[ $1 == "-n" ]]; then
    while IFS= read -r line; do
      printf "%s\n" "$(mp3info -p '%a - %t' "$line")"
    done < "$playlists/current" | nl -ba
  fi
}

trackinfo() {
  if pgrep -x mplayer >/dev/null; then
    song=$(grep Playing /tmp/log | sed 's/Playing//; s/^ //; s/.$//' | tail -n 1)
    printf "%s\n" "$(mp3info -p '%a - %t (%m:%02s)' "$song")"
  else
    printf "mplayer is not running.\n"
  fi
}

status() {
  [[ ! $test ]] && printf "mplayer is not running\n" && exit

  echo get_time_pos > "$fifo"
  echo get_percent_pos > "$fifo"
  sleep 0.3

  position=$(grep TIME /tmp/log | sed 's/ANS_TIME_POSITION=//; s/\..*//' | tail -n 1)
  song=$(grep Playing /tmp/log | sed 's/Playing//; s/^ //; s/.$//' | tail -n 1)
  sec=$(mp3info -p "%S" "$song")
  remain=$((sec - position))
  duration=$(mp3info -p '%m:%02s' "$song")
  percent=$(grep PERCENT /tmp/log | sed 's/ANS_PERCENT_POSITION=//' | tail -n 1)

  repeat=$(pgrep -f "mplayer.*-loop 0" >/dev/null && printf " Repeat: on" || printf " Repeat: off")
  random=$(grep -q "^1$" "$playlists/.state" && printf " Random: on" || printf " Random: off")
  notify=$(pgrep -f "tail -n 25 -f /tmp/log" >/dev/null && printf " Notify: on" || printf " Notify: off")

  printf "Time Remaining: %d:%02d/$duration - (%s%%) %s %s %s\n" \
    $((remain / 60)) $((remain % 60)) "$percent" "$random" "$repeat" "$notify"
}

playtime() {
  if [[ -f $playlists/.state && $(cat "$playlists/.state") == "1" ]]; then
    playlist="$playlists/.shuffled"
  else
    playlist="$playlists/current"
  fi

  [[ ! -f $playlists/current ]] && printf "No songs in playlist\n" && exit

  number=$(wc -l < "$playlist")

  if [[ ! $test ]]; then
    duration=0
    while read -r line; do
      length=$(mp3info -p '%S' "$line")
      duration=$((duration + length))
    done < "$playlist"

    [[ $number == 1 ]] && num="track" || num="tracks"

    printf "%d %s total - Total playtime: %02d:%02d:%02d\n" \
      "$number" "$num" $((duration / 3600)) $((duration / 60 % 60)) $((duration % 60))

    exit
  fi

  echo get_time_pos > "$fifo"
  sleep 0.3

  position=$(grep TIME /tmp/log | sed 's/ANS_TIME_POSITION=//; s/\..*//' | tail -n 1)
  song=$(grep Playing /tmp/log | sed 's/Playing//; s/^ //; s/.$//' | tail -n 1)
  length=$(mp3info -p '%S' "$song")

  duration=$length
  while read -r line; do
    length=$(mp3info -p '%S' "$line")
    duration=$((duration + length))
  done < <(grep -A $((number - 1)) "$song" "$playlist")

  time=$((duration - position))
  remain=$((duration - length - position))
  count=$(cat "$playlists/.count")
  left=$((number - count))

  [[ $left == 1 ]] && num="track" || num="tracks"

  printf "%d %s remaining - Time remaining: %02d:%02d:%02d\n" \
    "$left" "$num" $((remain / 3600)) $((remain / 60 % 60)) $((remain % 60))
}
    
save() {
  if [[ $(cat "$playlists/.state") == "1" ]]; then
    playlist="$playlists/.shuffled"
  else
    playlist="$playlists/current"
  fi

  [[ ! -d $playlists ]] && mkdir -p "$playlists"

  if [[ $1 && ! -f $playlists/$1 ]]; then
    cp "$playlist" "$playlists/$1"
    echo "Playlist successfully saved"
    exit
  fi

  printf "Playlist already exists - Use mps update\n"
  exit
}

update() {
  [[ -z $1 ]] && echo "Enter playlist name - mps update playlist" && exit

  if [[ -f $playlists/$2 && $1 == "sort" ]]; then
    sort "$playlists/current" -o "$playlists/$2"
    cp "$playlists/$2" "$playlists/current"
    cp "$playlists/current" "$playlists/$1"
  fi

  if [[ -f $playlists/$1 ]]; then
    cp "$playlists/current" "$playlists/$1"
    echo "Playlist successfully updated"
    exit
  fi

  echo "Playlist doesn't exist. Use mps save"
}

load() {
  [[ $random ]] && shuffle_error
  [[ ! -f $playlists/$1 ]] && echo "Playlist doesn't exist." && exit

  if [[ $test ]]; then
    cat "$playlists/$1" >> "$playlists/current"
    echo "loadlist $playlists/$1 2" > "$fifo"
    echo "Playlist loaded -> $1"
    exit
  fi

  cat "$playlists/$1" >> "$playlists/current"
  echo "Playlist loaded -> $1"
}

lsplaylists() {
  if [[ -d $playlists ]]; then
    find "$playlists" -type f ! -name ".*" -exec basename {} \;
    exit
  fi

  printf "no playlists found\n"
}

remove() {
  [[ -f $playlists/$1 ]] && rm "$playlists/$1" && exit
  printf "No such playlist\n"
}

delete() {
  [[ $test ]] && echo "cannot delete tracks during playback" && exit
  sed -i "${1}d" "$playlists/current"
}

stop() {
  if [[ -f $playlists/.state ]]; then
    echo "0" > "$playlists/.state"
    [[ $test ]] && pkill mplayer
    cleanup
    exit
  fi

  echo "mps already stopped"
  exit
}

notify() {
  if [[ $1 == "off" ]] && [[ $notify == "true" ]];then
    pid2=$(pgrep -f "tail -n 25 -f /tmp/log")
    kill "$pid2" 2>/dev/null
  else
    if pgrep -f "tail -n 25 -f /tmp/log" >/dev/null; then
      echo "notify already enabled"
      exit
    elif pgrep -x mplayer >/dev/null; then
      (
        tail -n 25 -f /tmp/log | grep --line-buffered "Playing" | while read -r line; do
          song=$(grep Playing /tmp/log | sed 's/Playing//; s/^ //; s/.$//' | tail -n 1)
          ffmpeg -y -i "$song" /tmp/album.jpg &
          wait
          notify-send -i /tmp/album.jpg "Now Playing" "$(mp3info -p '%a - %t' "$song")"
        done >/dev/null 2>&1 &
      )
    fi
  fi
}

counting() {
while [[ ! -f /tmp/log ]]; do
    sleep 0.1
  done


  [[ ! -d $playlists ]] && mkdir -p "$playlists"

  (
    tail -n 26 -f /tmp/log | grep --line-buffered "Playing" | while read -r line; do
      ((count++))
      echo "$count" > "$playlists/.count"
    done >/dev/null 2>&1 &
  )
}

albuminfo() {
  song=$(grep Playing /tmp/log | sed 's/Playing//; s/^ //; s/.$//' | tail -n 1)
  printf "%s\n" "$(mp3info -p '%a - %l (%y)' "$song")"
}

queued() {
  [[ ! $test ]] && echo "start playback of playlist to see the next song in the queue" && exit

  if [[ $(cat "$playlists/.state") == "0" ]]; then
    playlist="$playlists/current"
  else
    playlist="$playlists/.shuffled"
  fi

  song=$(grep Playing /tmp/log | sed 's/Playing//; s/^ //; s/.$//' | tail -n 1)

  while read -r second_line; do
    if [[ "$second_line" == "$song" ]]; then
      if read -r next_song; then
        printf "%s\n" "$(mp3info -p '%a - %t' "$next_song")"
      fi
    fi
  done < "$playlist"
}

shuffle() {
  shuf "$playlists/current" > "$playlists/.shuffled"
}

play() {
    parse_options "$@"
    local shift_count=$?
    shift "$shift_count"  # Remove the flags (-s, -n, -r) from the arguments

    [[ $test ]] && echo "mplayer already running" && exit
    [[ ! -f $playlists/current ]] && echo "No songs in playlist" && exit
    [[ ! -e $fifo ]] && mkfifo "$fifo"

    local playlist="$playlists/current"
    if [[ $shuf_enabled -eq 1 ]]; then
        # Create shuffled playlist
        shuf "$playlists/current" > "$playlists/.shuffled"
        echo "1" > "$playlists/.state"
        playlist="$playlists/.shuffled"
    else
        echo "0" > "$playlists/.state"
    fi
[[ $repeat_enabled -eq 1 ]] && repeat="-loop 0"

   ( mplayer $repeat -slave -input file="$fifo" -playlist "$playlist"  -af equalizer="$eq_settings" > /tmp/log 2>&1 &
    mplayer_pid=$! 
    wait "$mplayer_pid" 
    cleanup ) &
    counting &
}

dispatch() {
  local cmd="$1"
  shift

  case "$cmd" in
    ls|title|album|artist|genre|year|add|play|showlist|pause|mute|next|previous|repeat|stop|trackinfo|albuminfo|status|playtime|delete|clear|queued|save|update|load|remove|lsplaylists|notify|shuffle|usage)
      "$cmd" "$@"
      ;;
    *)
      echo "Unknown command: $cmd. Please see 'mps -h' for help with commands"
      exit 1
      ;;
  esac
}

get_args "$@"
dispatch "$@"
parse_options "$@"
