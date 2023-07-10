MPS supports the following features<br><br>

* Command line interface<br>
* Makes use of mplayers builtin equalizer. Customizable.
* Search for and add tracks by title, genre, album or artist<br>
* Also supports ls and add features to add tracks to playlists<br>
* Supports multiple playlists<br>
* Ability to save and load playlists<br>
* Full control over Mplayer in the background (slave mode)<br>
* Supports  repeat and shuffle modes<br>
* Trackinfo feature to get information about currently playing track<br>
* Status feature to get duration of song, time remaining and percent finished<br>
* Status feature also has a repeat and random indicator.<br>
* Show number of tracks and total playlist duration<br>
* Ability to delete tracks in playlist<br><br>

Requires: mplayer and mp3info

Add an alias to .bash_aliases in Linux or .profile in OpenBSD.<br>
alias mps="/path/to/mps.sh"<br><br>

Examples:<br>
mps album "back in black"<br>
mps album "back in black" | mps add<br>
mps ls | grep -i acdc<br>
mps ls | grep -i acdc | mps add<br>
mps add "ACDC - Back in Black.mp3"<br>
mps save acdc<br>
mps load acdc
