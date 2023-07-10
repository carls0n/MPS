
  MPS - Mplayer script 2022-2023 Marc Carlson<br><br>

  Usage: ./mps.sh [options]<br><br>

  title <title> - add tracks by title<br>
  album <album> - add tracks by album<br>
  genre <genre> - add tracks by genre<br>
  artist <artist> - add tracks by artist<br><br>

  ls - list songs by filename in directory<br>
  add - add songs by filename. Can be used with ls<br><br>

  play - play tracks in playlist<br>
  showlist - show tracks in playlist<br>
  pause - pause/unpause music<br>
  mute - toggle mplayer mute<br>
  next - play next track in playlist<br>
  previous - play previous track<br>
  repeat - repeat the currently playing track once<br>
  stop - stop playback<br>
  trackinfo - show info about currently playing track<br>
  status - show time remaining and percent finished<br>
  playtime - show total duration of playlist<br>
  delete <track number> - delete track<br>
  clear - clear playlist<br><br>

  save <playlist> - save playlist named <playlist><br>
  load <playlist> - load playlist named <playlist><br>
  remove <playlist> - remove playlist named <playlist><br>
  lsplaylists - show playlists<br><br>

  -s) shuffle songs (random) - use with play<br>
  -r) repeat playlist - use with play<br><br>

Create an alias in your .bashr_aliases file in Linux or .profile in OpenBSD<br>
alias mps="/path/to/mps.sh"<br>

Examples:<br>
mps album "peace sells"<br>
mps album "peace sells" | mps add<br>
mps ls | grep Megadeth | mps add<br>
mps add "Megadeth - Peace Sells.mp3"<br>
