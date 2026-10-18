<hr>
10.15.2026 changelog<br>
\* Changed search syntax from 'mps title <title>' to 'mps search title <title>'<br>
\* Added the ability to add one track at a time via 'mps add <trackname.mp3>'<br>
\* Added ability to view songs in a playlist via 'mps playlist $playlist'

10.16.2026 changelog<br>
\* Added ability to play a song in playlist by line number 'mps play 5'<br>
\* mps showlist -n' will show you line numbers.

10.17.2026 changelog<br>
\* Previously, using 'mps add' and typing in a track<br>
that doesn't exist would produce an error in the playlist. Better track processing<br>
and error handling prevent this.

10.18.2026 changelog<br>
\* previously, you would use 'mps ls | mps add' to add all tracks. Now, you can use 'mps add /'<br>
\* Now you can use 'mps searchplay <track>' to immediately play a song. Flags -n (notify) and -r<br>
(repeat) can be used also.
<hr>

### MPS Features:<br>
\* Customizable equalizer<br>
\* Search for tracks by title, genre, album, artist or range of years<br>
\* Also supports ls and add features to add tracks to playlists<br>
\* Ability to save, update and load playlists<br>
\* Show tracks in a playlist<br>
\* play a track in playlist by line number<br>
\* Puts Mplayer in the background (slave mode)<br>
\* Supports repeat and shuffle modes<br>
\* Trackinfo feature to get information about currently playing track<br>
\* Albuminfo command to get album info and year<br>
\* Status feature to get time remaining and percent finished, as well as status indicators<br>
\* Shows remaining number of tracks and remaining playlist time.<br>
\* Enable notifications (xfce-notify-4.0)<br>
\* Showlist function includes -n flag to number lines. Handy for using delete or play<br>
\* Queued command to see the next song in the queue.<br>
\* Requires mplayer, mp3info, ffmpeg and shuf be installed. shuf is part of the coreutils package<br>
\* When updating a playlist after adding songs, you can now use 'mps update sort [ playlist ]' to sort songs alphabetically.<br>
\* OpenBSD users can install coreutils from the OpenBSD repository and then cp /usr/local/bin/gshuf /usr/local/bin/shuf<br><br>

https://github.com/user-attachments/assets/6bd0fd32-4ed9-40f8-a2e3-01883b897f3d

