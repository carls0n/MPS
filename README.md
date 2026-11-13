<!--<img width="1269" height="719" alt="github" src="https://github.com/user-attachments/assets/7e4dc6cd-5cc2-4387-b47b-ee9e9c56139a" />-->
![url](https://repository-images.githubusercontent.com/664440080/8f0d75f2-bed3-4075-bf30-0f95c4a09a11)
<!--![url](https://repository-images.githubusercontent.com/664440080/78d5bf4c-45f6-48b3-b9b6-82cbcec63a52)-->

### MPS Features:<br>
\* Customizable equalizer<br>
\* Customizable presets for eq<br>
\* Search for tracks by title, genre, album, artist or range of years<br>
\* Also supports ls and add features to add tracks to playlists<br>
\* Ability to save, update and load playlists<br>
\* Show tracks in a playlist<br>
\* play a track in playlist by line number<br>
\* Searchadd function to add matching tracks to current playlist or optionally to another playlist<br>
\* Searchplay feature to find a track and play it immediately.<br>
\* Show tracks in playlist with 'mps playlist \<playlist\><br>
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


Just as a note, if you want to normalize the volume of all the tracks in your collection, I reccomend mp3gain.<br>
To normalize all tracks -> apply track analysis and adjust to the default target volume (89.0 dB):<br><br>
```
cd Music
```
```
mp3gain -r *
```

<!--https://github.com/user-attachments/assets/6bd0fd32-4ed9-40f8-a2e3-01883b897f3d-->

