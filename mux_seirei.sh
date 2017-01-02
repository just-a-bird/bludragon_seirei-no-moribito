#!/bin/bash
shopt -s nocaseglob nocasematch
clear
outdir=Edited
fontdir=fonts
logfile=mux_seirei.log
rm -r -f "$outdir"
rm -f "$logfile"
declare -a fonts
echo "Looking for fonts in '$fontdir'..." | tee -a "$logfile"
for font in $fontdir/*.ttf; do
  echo "  Found '$font', adding." | tee -a "$logfile"
  fonts=("${fonts[@]}" \
        "--attachment-name $(basename "$font")" \
        "--attachment-mime-type application/x-truetype-font" \
        "--attach-file $font")
done
font_attachments="${fonts[@]}"
for video in *.mkv; do
  echo
  echo "== $video =="
  subs="$(basename "$video" .mkv).ass"
  chapters="$(basename "$video" .mkv).xml"
  echo "video    = $video"
  echo "subs     = $subs"
  echo "chapters = $chapters"
  echo
  mkvmerge \
    --ui-language en \
    --output "$outdir/$video" \
    --audio-tracks 1 --default-track 1:yes \
    --no-subtitles \
    --language 4:jpn '(' "$video" ')' \
    --language 0:eng --track-name '0:Signs & Dialogue (SSA)' '(' "$subs" ')' \
    $font_attachments \
    --chapters "$chapters" \
    --track-order 0:1,1:0,0:4 \
  | tee -a "$logfile"
done