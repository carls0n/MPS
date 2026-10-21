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

export music=~/Music
export playlists=~/.mps
export fifo=/tmp/fifo

cleanup() {
  if ! pgrep -x mplayer >/dev/null; then
    pid=$(pgrep -f "tail -n 25 -f /tmp/log")
    pid2=$(pgrep -f "tail -n 26 -f /tmp/log")
    kill "$pid" 2>/dev/null
    kill "$pid2" 2>/dev/null

    files=(/tmp/log /tmp/new "$fifo" /tmp/album.jpg "$playlists/.shuffled")
    for file in "${files[@]}"; do
      [[ -e "$file" ]] && rm "$file" 2>/dev/null
    done
  fi
}

trap 'cleanup' EXIT

usage() {
  echo ""
  echo "  MPS - Mplayer script 2022 Marc Carlson"
  echo "  Usage: mps [options]"
  echo ""
  echo "  search title <title> - search tracks by title"
  echo "  search album <album> - search tracks by album"
  echo "  search genre <genre> - search tracks by genre"
  echo "  search artist <artist> - search tracks by artist"
  echo "  search year <range> - search by year (1970-1979)"
  echo ""
  echo "  ls - list tracks in directory"
  echo "  add - add tracks. Can also be used with ls"
  echo ""
  echo "  play - play tracks in playlist"
  echo "  searchadd - add search results to playlist"
  echo "  searchplay - locate track and play immediately"
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
  echo "  playlist <playlist> - List tracks in playlist"
  echo "  delete <track number> - delete track"
  echo "  clear - clear playlist"
  echo "  queued - show next track in queue"
  echo ""
  echo "  eq [on|off|list] -p [preset] [--silent]" 
  echo "  notify on|off - Turn notifications on or off"
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
  echo "  -e) enable equalizer. Use with -p [preset]"
  echo ""
}

eq_settings=""
valid_preset=0

set_eq_profile() {
  local preset_arg="$1"
  case "$preset_arg" in
    lowbass) eq_settings="6:6:4:1:1:0:1:2:5:5"; valid_preset=1 ;;
    metal)   eq_settings="8:7:4:1:1:0:1:2:5:5"; valid_preset=1 ;;
    reggae)  eq_settings="7:6:4:1:1:0:1:2:5:5"; valid_preset=1 ;;
    rock)    eq_settings="9:8:4:1:1:0:1:2:4:5"; valid_preset=1 ;;
    list|help)
      echo "Available profiles: lowbass, metal, reggae, rock"
      valid_preset=0
      ;;
    *) 
      echo "Error: Unknown profile '$preset_arg'. Equalizer will not be enabled."
      valid_preset=0 
      ;;
  esac
}

parse_options() {
    local opt
    local OPTIND=1

    shuf_enabled=0
    repeat_enabled=0
    notify_enabled=0
    eq_enabled=0
    
    local preset_specified=0

    while getopts "nsrhep:" opt; do
        case "$opt" in
            s) shuf_enabled=1 ;;
            r) repeat_enabled=1 ;;
            n) notify_enabled=1 ;;
            e) eq_enabled=1 ;;
            p) 
                preset_specified=1
                # Call the global helper function at the top
                set_eq_profile "$OPTARG"
                ;;
            h) usage; exit 0 ;;
            *) ;;
        esac
    done

    if [[ $eq_enabled -eq 1 ]]; then
        if [[ $preset_specified -eq 0 ]] || [[ $valid_preset -eq 0 ]]; then
            if [[ $preset_specified -eq 0 ]]; then
                echo "Error: Enabling the equalizer requires a preset flag (-p)."
            fi
            exit 1
        fi
    fi

   
    return $((OPTIND - 1))
}


type -P mp3info >/dev/null || { echo "Please install mp3info before using this script."; exit; }
type -P mplayer >/dev/null || { echo "Please install mplayer before using this script."; exit; }
type -P ffmpeg >/dev/null || { echo "Please install ffmpeg before using this script."; exit; }
type -P shuf >/dev/null || { echo "Please install shuf before using this script."; exit; }

[[ ! -d $music ]] && echo "$music does not exist, edit your music directory in the MPS script." && exit

ls() {
  find "$music" -maxdepth 1 -type f -exec basename {} \; | sort
}

_music_search() {
  local mode="$1" # 'text', 'year', or 'global'
  local format_or_query="$2"
  local query="$3"
  
  local start end
  if [[ "$mode" == "year" || "$mode" == "global" ]]; then
    local year_query="${query:-$format_or_query}"
    if [[ "$year_query" =~ ^[0-9]{4}$ ]]; then
      start="$year_query"
      end="$year_query"
    elif [[ "$year_query" =~ ^[0-9]{4}-[0-9]{4}$ ]]; then
      start="${year_query%%-*}"
      end="${year_query##*-}"
    fi
  fi

  for file in "$music"/*.mp3; do
    [[ -e "$file" ]] || continue 

    if [[ "$mode" == "text" ]]; then
      local tag_val
      tag_val=$(mp3info -p "$format_or_query" "$file")
      if [[ "${tag_val,,}" == *"${query,,}"* ]]; then
        basename "$file"
      fi

    elif [[ "$mode" == "year" ]]; then
      local year_val
      year_val=$(mp3info -p '%y' "$file")
      if [[ -n "$start" && -n "$year_val" && "$year_val" -ge "$start" && "$year_val" -le "$end" ]]; then
        basename "$file"
      fi

    elif [[ "$mode" == "global" ]]; then
      local all_tags year_val
      all_tags=$(mp3info -p "%t|%l|%a|%g" "$file")
      year_val=$(mp3info -p '%y' "$file")
      
      if [[ "${all_tags,,}" == *"${format_or_query,,}"* ]]; then
        basename "$file"
      elif [[ -n "$start" && -n "$year_val" && "$year_val" -ge "$start" && "$year_val" -le "$end" ]]; then
        basename "$file"
      fi
    fi
  done
}

title() {
  if [[ "${1,,}" != "search" ]]; then
    echo "Error: Command must contain the term 'search'." >&2
    return 1
  fi
  shift
  _music_search 'text' '%t' "$*"
}

album() {
  if [[ "${1,,}" != "search" ]]; then
    echo "Error: Command must contain the term 'search'." >&2
    return 1
  fi
  shift
  _music_search 'text' '%l' "$*"
}

artist() {
  if [[ "${1,,}" != "search" ]]; then
    echo "Error: Command must contain the term 'search'." >&2
    return 1
  fi
  shift
  _music_search 'text' '%a' "$*"
}

genre() {
  if [[ "${1,,}" != "search" ]]; then
    echo "Error: Command must contain the term 'search'." >&2
    return 1
  fi
  shift
  _music_search 'text' '%g' "$*"
}

year() {
  if [[ "${1,,}" != "search" ]]; then
    echo "Error: Command must contain the term 'search'." >&2
    return 1
  fi
  shift
  _music_search 'year' "$*"
}

search() {
  if [[ -z "$1" ]]; then
    echo "Error: Search query cannot be empty." >&2
    return 1
  fi

  case "${1,,}" in
    title|album|artist|genre|year)
      local cmd="$1"
      shift
      "$cmd" "search" "$@"
      ;;
    *)
      _music_search 'global' "$@"
      ;;
  esac
}

process_tracks() {
  > /tmp/new

  [[ -d "$playlists" ]] || mkdir -p "$playlists"

  local cr=$'\r'

  if [ $# -gt 0 ]; then
    for track in "$@"; do
      # Trim leading whitespace safely
      while [[ "$track" == [[:space:]]* ]]; do
        track="${track#?}"
      done

      while [[ "$track" == *[[:space:]] ]]; do
        track="${track%?}"
      done

      track="${track//$cr/}"
      [ -z "$track" ] && continue

      if [ -f "$music/$track" ]; then
        echo "$music/$track" >> "$playlists/.current"
        echo "$music/$track" >> /tmp/new
      else
        echo "error: file does not exist: $music/$track" >&2
        return 1
      fi
    done
  else
    while read -r track || [[ -n "$track" ]]; do
      while [[ "$track" == [[:space:]]* ]]; do
        track="${track#?}"
      done
      
      while [[ "$track" == *[[:space:]] ]]; do
        track="${track%?}"
      done
      
      track="${track//$cr/}"
      [ -z "$track" ] && continue

      if [ -f "$music/$track" ]; then
        echo "$music/$track" >> "$playlists/.current"
        echo "$music/$track" >> /tmp/new
      else
        echo "error: file does not exist: $music/$track" >&2
        return 1
      fi
    done
  fi

  if [ -s /tmp/new ]; then
    if [[ -p "$fifo" ]]; then
      exec 3<> "$fifo"
      echo "loadlist /tmp/new 2" >&3
      exec 3>&-
    fi
  fi
}

shuffle_error() {
  printf "Cannot add tracks in shuffle mode\n"
  exit
}

test=$(pgrep mplayer)
[[ -f $playlists/.state ]] && random=$(grep 1 "$playlists/.state")

playlist() {
find "$playlists/$1" -maxdepth 1 -type f -exec sh -c 'while read -r line; do basename "$line"; done < "$1"' _ {} \;
}

add() {
  [[ ! -d "$playlists" ]] && mkdir -p "$playlists"
  [[ -e /tmp/new ]] && rm -f /tmp/new
  [[ -n "$random" ]] && shuffle_error

  local track_status=0

  if [[ "$1" == "/" ]]; then
    if [[ -d "$music" ]]; then
      set --

      while IFS= read -r -d '' file; do
        set -- "$@" "${file#$music/}"
      done < <(find "$music" -type f -print0|sort -z -f)
      
      process_tracks "$@"
      track_status=$?
    else
      echo "Error: Music directory '$music' does not exist." >&2
      exit 1
    fi
  elif [[ $# -gt 0 ]]; then
    process_tracks "$@"
    track_status=$?
  else
    process_tracks
    track_status=$?
  fi

  if [[ $track_status -ne 0 ]]; then
    exit 1
  fi

  exit 0
}

searchadd() {
  local search_term="$1"
  local target file all_tags track_year
  local matching_tracks=()
  local playlist=".current" 

  shift 
  
  if [[ -z "$search_term" ]]; then
    echo "Error: Search term cannot be empty." >&2
    return 1
  fi

  if [[ $# -gt 0 ]]; then
    if [[ ! -d "${!#}" ]]; then
      playlist="${!#}"
      set -- "${@:1:$#-1}"
    fi
  fi

  local targets=()
  if [[ $# -eq 0 ]]; then
    targets=( "$music" )
  else
    targets=( "$@" )
  fi

  local is_range=0 start_year=0 end_year=0
  if [[ "$search_term" =~ ^([0-9]{4})-([0-9]{4})$ ]]; then
    is_range=1
    start_year="${BASH_REMATCH[1]}"
    end_year="${BASH_REMATCH[2]}"
  fi

  local search_lower="${search_term,,}"

  for target in "${targets[@]}"; do
    [[ -d "$target" ]] || continue

    while IFS= read -r -d '' file; do
      all_tags=$(mp3info -p "%t|%l|%a|%g|%y" "$file" 2>/dev/null)
      
      if [[ $is_range -eq 1 ]]; then
        track_year="${all_tags##*|}"
        
        if [[ "$track_year" =~ ^[0-9]{4}$ ]] && (( track_year >= start_year && track_year <= end_year )); then
          matching_tracks+=( "${file#"$music"}" )
        fi
      else
        local tags_lower="${all_tags,,}"
        if [[ "$tags_lower" == *"$search_lower"* ]]; then
          matching_tracks+=( "${file#"$music"}" )
        fi
      fi
      
    done < <(find "$target" -type f -iname "*.mp3" -print0 | sort -z -f)
  done

  if [[ ${#matching_tracks[@]} -gt 0 ]]; then
    local playlist_dir="$playlists"
    local playlist_file="$playlist_dir/$playlist"
    
    mkdir -p "$playlist_dir"
    
    local track added_count=0
    for track in "${matching_tracks[@]}"; do
      if echo "$music$track" >> "$playlist_file" 2>/dev/null; then
        ((added_count++))
      fi
    done
    
    if [[ $added_count -eq 0 ]]; then
      echo "Error: Could not write to $playlist_file. Check directory permissions." >&2
      return 1
    fi
    
    local label="tracks"
    [[ $added_count -eq 1 ]] && label="track" || label="tracks" 
    if [[ $playlist_file == *".current" ]]; then
      echo "Added $added_count $label to current playlist"
    else
      echo "Added $added_count $label to playlist -> ${playlist_file##*/}"
    fi

  else
    echo "No matching tracks found for: $search_term" >&2
    return 1
  fi
}

next() {
  echo "pausing_keep_force pt_step 1" > "$fifo"
}

previous() {
  echo "pausing_keep_force pt_step -1" > "$fifo"
}


repeat() {
  echo "set_property loop 1" > "$fifo"
}

pause() {
  echo "pause" > "$fifo"
}

mute() {
  echo "mute" > "$fifo"
}

clear() {
  [[ ! -f $playlists/.current ]] && echo "No songs in playlist" && exit
  [[ $test ]] && pkill mplayer

  rm "$playlists/.current"
  [[ -f $playlists/.shuffled ]] && rm "$playlists/.shuffled"

  echo "0" > "$playlists/.state"
  cleanup
}

showlist() {
  [[ ! -f $playlists/.current ]] && echo "No songs in playlist" && exit

  if [[ -z $1 ]]; then
    while IFS= read -r line; do
      printf "%s\n" "$(mp3info -p '%a - %t' "$line")"
    done < "$playlists/.current"

  elif [[ $1 == "-n" ]]; then
    while IFS= read -r line; do
      printf "%s\n" "$(mp3info -p '%a - %t' "$line")"
    done < "$playlists/.current" | nl -ba
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

  printf "get_time_pos\nget_percent_pos\n" > "$fifo"
  sleep 0.15

  local log_tail
  log_tail=$(tail -n 20 /tmp/log 2>/dev/null)
  
  position=$(echo "$log_tail" | grep TIME | sed 's/ANS_TIME_POSITION=//; s/\..*//' | tail -n 1)
  song=$(grep Playing /tmp/log 2>/dev/null | sed 's/Playing//; s/^ //; s/.$//' | tail -n 1)

  [[ -z "$position" ]] && position=0
  [[ -z "$song" ]] && printf "No song metadata found in log.\n" && exit

  sec=$(mp3info -p "%S" "$song" 2>/dev/null)
  duration=$(mp3info -p '%m:%02s' "$song" 2>/dev/null)
  remain=$((sec - position))

  percent=$(echo "$log_tail" | grep PERCENT | sed 's/ANS_PERCENT_POSITION=//' | tail -n 1)
  [[ -z "$percent" ]] && percent=0

  repeat=$(pgrep -f "mplayer.*-loop 0" >/dev/null && echo " Repeat: on" || echo " Repeat: off")
  random=$(grep -q "^1$" "$playlists/.state" 2>/dev/null && echo " Random: on" || echo " Random: off")
  eq=$(grep -q "1" "$playlists/.eq" 2>/dev/null && echo " eq: on" || echo " eq: off")
  notify=$(grep -q "1" "$playlists/.notify" 2>/dev/null && echo " Notify: on" || echo " Notify: off")
  
  printf "Remaining: %d:%02d/$duration - (%s%%)%s %s %s %s\n" \
    $((remain / 60)) $((remain % 60)) "$percent" "$random" "$repeat" "$notify" "$eq"
}


eq() {
  local action=""
  local preset_arg=""
  local silent=0
  valid_preset=0 

  while [[ $# -gt 0 ]]; do
    case "$1" in
      on|off|list)
        action="$1"
        shift
        ;;
      -p)
        if [[ -z "$2" || "$2" == -* ]]; then
          echo "Error: -p requires a valid preset name."
          return 1
        fi
        preset_arg="$2"
        shift 2
        ;;
      -s|--silent)
        silent=1
        shift
        ;;
      *)
        echo "Unknown argument: $1"
        echo "Usage: eq [on|off|list] -p [preset] [--silent]"
        return 1
        ;;
    esac
  done

  if [[ "$action" == "list" || "$preset_arg" == "list" || "$preset_arg" == "help" ]]; then
    local profiles
    profiles=$(type set_eq_profile | sed -E -n 's/^[[:space:]]*([a-zA-Z0-9_-]+)\).*/\1/p' | grep -vE 'list|help|\*')
    
    for p in $profiles; do
      (
        eq_settings=""
        set_eq_profile "$p" >/dev/null 2>&1
        echo "$p: $eq_settings"
      )
    done
    return 0
  fi

  if [[ "$action" == "off" ]]; then
    echo "af_cmdline equalizer 0:0:0:0:0:0:0:0:0:0" > "$fifo"
    echo "0" > "$playlists/.eq"
    echo "0:0:0:0:0:0:0:0:0:0" > "$playlists/.eq_bands"
    [[ $silent -eq 0 ]] && echo "Equalizer disabled."
    return 0
  fi

  if [[ "$action" == "on" ]]; then
    if [[ -n "$preset_arg" ]]; then
      set_eq_profile "$preset_arg"
      if [[ $valid_preset -eq 0 ]]; then
        return 1
      fi
    elif [[ -z "$eq_settings" ]]; then
      echo "Error: Use with -p \$preset. Use mps eq list for a list of available presets."
      return 1
    fi

    echo "1" > "$playlists/.eq"
    
    # 1. Update live audio context instantly via FIFO
    echo "af_cmdline equalizer ${eq_settings}" > "$fifo"
    
    echo "${eq_settings}" > "$playlists/.eq_bands"

    if [[ $silent -eq 0 ]]; then
      if [[ -n "$preset_arg" ]]; then
        echo "Equalizer enabled with preset '$preset_arg': $eq_settings"
      else
        echo "Equalizer re-applied with current settings: $eq_settings"
      fi
    fi
    return 0
  fi

  echo "Usage: eq [on|off|list] -p [preset] [--silent]"
  return 1
}

playtime() {
  playlist="$playlists/.current"
  [[ -f $playlists/.state && $(<"$playlists/.state") == 1 ]] && \
    playlist="$playlists/.shuffled"

  [[ ! -f $playlists/.current ]] && printf "No songs in playlist\n" && exit

  number=$(wc -l < "$playlist")

  if [[ ! $test ]]; then
    duration=0
    while IFS= read -r line; do
      (( duration += $(mp3info -p '%S' "$line") ))
    done < "$playlist"

    num=$([[ $number -eq 1 ]] && echo track || echo tracks)

    printf "%d %s total - Total playtime: %02d:%02d:%02d\n" \
      "$number" "$num" \
      $((duration/3600)) $((duration/60%60)) $((duration%60))
    exit
  fi

  echo get_time_pos > "$fifo"
  sleep 0.2

  position=$(grep -o 'ANS_TIME_POSITION=[0-9]*' /tmp/log | awk -F= '{print $2}' | tail -n1)
  song=$(grep -o 'Playing .*' /tmp/log | sed 's/Playing //; s/.$//' | tail -n1)

  length=$(mp3info -p '%S' "$song")
  duration=$length
  found=0

  while IFS= read -r line; do
    if [[ $found -eq 1 ]]; then
      (( duration += $(mp3info -p '%S' "$line") ))
    elif [[ $line == "$song" ]]; then
      found=1
    fi
  done < "$playlist"

  remain=$((duration - position))
  left=$((number - $(<"$playlists/.count")))
  num=$([[ $left -eq 1 ]] && echo track || echo tracks)

  printf "%d %s remaining - Time remaining: %02d:%02d:%02d\n" \
    "$left" "$num" \
    $((remain/3600)) $((remain/60%60)) $((remain%60))
}

save() {
if [[ $(cat $playlists/.state) == "1" ]]
then
playlist="$playlists/.shuffled"
else 
playlist="$playlists/.current"
fi
[[ ! -d $playlists ]] && mkdir -p $playlists
[[ $1 ]] && [[ ! -f $playlists/$1 ]] &&
cp $playlist $playlists/$1 &&
echo Playlist successfully saved && exit
printf "Playlist already exists - Use mps update\n" && exit
}

update() {
  [[ -z $1 ]] && echo "Enter playlist name - mps update playlist" && exit

  if [[ -f $playlists/$2 && $1 == "sort" ]]; then
    sort "$playlists/.current" -o "$playlists/$2"
    cp "$playlists/$2" "$playlists/.current"
    cp "$playlists/.current" "$playlists/$1"
  fi

  if [[ -f $playlists/$1 ]]; then
    cp "$playlists/.current" "$playlists/$1"
    echo "Playlist successfully updated"
    exit
  fi

  echo "Playlist doesn't exist. Use mps save"
}

load() {
  [[ $random ]] && shuffle_error
  [[ ! -f $playlists/$1 ]] && echo "Playlist doesn't exist." && exit

  if [[ $test ]]; then
    cat "$playlists/$1" >> "$playlists/.current"
    echo "loadlist $playlists/$1 2" > "$fifo"
    echo "Playlist loaded -> $1"
    exit
  fi

  cat "$playlists/$1" >> "$playlists/.current"
  echo "Playlist loaded -> $1"
}

lsplaylists() {
  if [[ -d $playlists ]]; then
    find "$playlists" -type f ! -name ".*" -exec basename {} \; | sort
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
  sed -i "${1}d" "$playlists/.current"
}

function stop {
[[ -f $playlists/.state ]] &&
echo "0" > $playlists/.state && 
echo "0" > $playlists/.notify && 
[[ $test ]] && pkill mplayer
cleanup
[[ ! $test ]] &&
echo mps already stopped 

}

notify() {
    nf=$(pgrep -f "tail --follow=name -n 0 /tmp/log")

    if [[ $1 == "off" ]]; then 
        if [[ -n "$nf" ]]; then
            kill "$nf"
        fi
        echo "0" > "$playlists/.notify"
        return 0
    fi

    if [[ -n "$nf" ]]; then
        echo "notify already enabled"
        echo "1" > "$playlists/.notify"  
        return 0
    elif pgrep -x mplayer >/dev/null; then
        if [[ $1 == "on" || -z $1 ]]; then 
            echo "1" > "$playlists/.notify"

            local current_song
            current_song=$(grep Playing /tmp/log 2>/dev/null | sed 's/Playing//; s/^ //; s/.$//' | tail -n 1)
            if [[ -f "$current_song" ]]; then
                ffmpeg -y -i "$current_song" /tmp/album.jpg >/dev/null 2>&1
                notify-send -i /tmp/album.jpg "Now Playing" "$(mp3info -p '%a - %t' "$current_song")"
            fi
            (
                tail --follow=name -n 0 /tmp/log | grep --line-buffered "Playing" | while read -r line; do
                    song=$(grep Playing /tmp/log 2>/dev/null | sed 's/Playing//; s/^ //; s/.$//' | tail -n 1)
                    if [[ -f "$song" ]]; then
                        ffmpeg -y -i "$song" /tmp/album.jpg >/dev/null 2>&1
                        notify-send -i /tmp/album.jpg "Now Playing" "$(mp3info -p '%a - %t' "$song")"
                    fi
                done &
            ) >/dev/null 2>&1
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
  [[ $test ]] &&
  song=$(grep Playing /tmp/log | sed 's/Playing//; s/^ //; s/.$//' | tail -n 1) &&
  printf "%s\n" "$(mp3info -p '%a - %l (%y)' "$song")" && exit                  
  printf "mplayer is not running\n"
}

queued() {
  [[ ! $test ]] && echo "start playback of playlist to see the next song in the queue" && exit

  if [[ $(cat "$playlists/.state") == "0" ]]; then
    playlist="$playlists/.current"
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
  shuf "$playlists/.current" > "$playlists/.shuffled"
}

searchplay() {
    [[ ! -e "$fifo" ]] && mkfifo "$fifo"

    local args_clean=()
    
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == -* ]]; then
            parse_options "$1" "${2:-}"
            local shift_count=$?
            
            if [[ $shift_count -gt 0 ]]; then
                shift $shift_count
            else
                shift
            fi
        else
            args_clean+=("$1")
            shift
        fi
    done

    [[ $test ]] && echo "mplayer already running" && return 1

    if [[ ${#args_clean[@]} -eq 0 ]]; then
        echo "Error: Please provide a search query!"
        return 1
    fi

    local find_args=()
    for term in "${args_clean[@]}"; do
        if [[ ${#find_args[@]} -gt 0 ]]; then
            find_args+=( -a )
        fi
        find_args+=( -iname "*$term*" )
    done

    actual_file=$(find "$music" -maxdepth 1 "${find_args[@]}" -printf "%f" -quit)

    if [[ -z "$actual_file" ]]; then
        echo "Error: file '${args_clean[*]}' does not exist!"
        return 1
    fi

    local repeat=""
    [[ $repeat_enabled -eq 1 ]] && repeat="-loop 0"
    
    if [[ $eq_enabled -eq 1 ]]; then
        echo "1" > "$playlists/.eq"
        if [[ -z "$eq_settings" ]]; then
            eq_settings="0:0:0:0:0:0:0:0:0:0"
        fi
    else
        echo "0" > "$playlists/.eq"
        eq_settings="0:0:0:0:0:0:0:0:0:0"
    fi

    echo "$eq_settings" > "$playlists/.eq_bands"
    local mplayer_eq_filter="-af equalizer=${eq_settings}"

    (
        > /tmp/log
        local track_initialized=0

        mplayer $repeat $mplayer_eq_filter -input file="$fifo" "$music/$actual_file" > /tmp/log 2>&1
    ) &
}

play() {
    local line_number=""
    local seek_flag=""

    for arg in "$@"; do
        if [[ "$arg" =~ ^[0-9]+$ ]]; then
            line_number="$arg"
            break
        fi
    done

    local args_clean=()
    for arg in "$@"; do
        [[ "$arg" != "$line_number" ]] && args_clean+=("$arg")
    done

    parse_options "${args_clean[@]}"
    local shift_count=$?

    [[ $test ]] && { echo "mplayer already running"; return 1; }
    [[ ! -f "$playlists/.current" ]] && { echo "No songs in playlist"; return 1; }
    [[ ! -e "$fifo" ]] && mkfifo "$fifo"

    local playlist=""
    local mplayer_target_flag=""
    
    if [[ -n "$line_number" ]]; then
        local specific_track
        specific_track=$(sed -n "${line_number}p" "$playlists/.current")
        
        if [[ -z "$specific_track" ]]; then
            echo "Error: Track #$line_number does not exist in playlist." >&2
            return 1
        fi

        specific_track="${specific_track//$'\r'/}"
        specific_track=$(echo "$specific_track" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [[ ! -f "$specific_track" ]]; then
            echo "Error: File does not exist: $specific_track" >&2
            return 1
        fi
        
        playlist="$specific_track"
        mplayer_target_flag=""
    else
        if [[ $shuf_enabled -eq 1 ]]; then
            shuf "$playlists/.current" > "$playlists/.shuffled"
            echo "1" > "$playlists/.state"
            playlist="$playlists/.shuffled"
        else
            echo "0" > "$playlists/.state"
            playlist="$playlists/.current"
        fi
        mplayer_target_flag="-playlist"
    fi

    [[ $repeat_enabled -eq 1 ]] && local repeat="-loop 0" || local repeat=""
    
    if [[ $eq_enabled -eq 1 ]]; then
        echo "1" > "$playlists/.eq"
        if [[ -n "$eq_preset" ]]; then
            set_eq_profile "$eq_preset" >/dev/null 2>&1
        fi
        if [[ -z "$eq_settings" ]]; then
            eq_settings="0:0:0:0:0:0:0:0:0:0"
        fi
    else
        echo "0" > "$playlists/.eq"
        eq_settings="0:0:0:0:0:0:0:0:0:0"
    fi

    echo "$eq_settings" > "$playlists/.eq_bands"

    local mplayer_eq_filter="-af equalizer=${eq_settings}"

    ( 
        > /tmp/log
        
        local track_initialized=0

        mplayer $repeat $mplayer_eq_filter -slave -input file="$fifo" $mplayer_target_flag "$playlist" &> >(
            while read -r line; do
                echo "$line" >> /tmp/log
                
                # --- FIXED: ZERO-LATENCY BOUNDARY CAPTURE ---
                # Triggered the exact millisecond the text header hits, before audio begins
                if [[ "$line" == *"Playing "* ]]; then
                    track_initialized=0
                    
                    # 1. Force a non-blocking wake up to open the pipeline
                    echo "get_time_pos" > "$fifo" &
                    
                    # 2. Instantly push your target equalizer values right behind it
                    if [[ $(cat "$playlists/.eq" 2>/dev/null) == "1" ]]; then
                        local current_bands
                        current_bands=$(cat "$playlists/.eq_bands" 2>/dev/null || echo "0:0:0:0:0:0:0:0:0:0")
                        echo "af_cmdline equalizer ${current_bands}" > "$fifo" &
                    else
                        echo "af_cmdline equalizer 0:0:0:0:0:0:0:0:0:0" > "$fifo" &
                    fi
                fi

                if [[ $track_initialized -eq 0 && "$line" =~ ^A:[[:space:]]*[0-9] ]]; then
                    track_initialized=1
                fi
            done
        ) &
        mplayer_pid=$! 
        
        [[ $notify_enabled -eq 1 ]] && notify
        wait "$mplayer_pid" 
        cleanup 
    ) &

    counting &
}


dispatch() {
  local cmd="$1"
  [[ -z $cmd ]] && usage && exit
  shift
  case "$cmd" in
    ls|title|album|artist|genre|year|add|play|showlist|pause|mute|next|previous|repeat|stop|trackinfo|albuminfo|status|playtime|delete|clear|queued|save|update|load|remove|lsplaylists|notify|shuffle|search|playlist|process_tracks|searchplay|searchadd|eq)
      "$cmd" "$@"
      ;;
    *)
      echo "Unknown command: $cmd. Please see 'mps -h' for help with commands"
      exit 1
      ;;
  esac
}

parse_options "$@"
shift $?
dispatch "$@"
