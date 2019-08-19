#!/bin/bash

#SNAP_BASE="/mnt/hgfs/Disk2/UniFi-Snaps"
SNAP_BASE="/nas/data/Development/UniFi/TimeLapse/UniFi-Timelapse/UniFi-Snaps"
OUT_DIR="$SNAP_BASE/timelapse"
DATE_EXT=`date '+%F %H:%M'`

declare -A CAMS

CAMS["Front Door"]="rtsp://127.0.0.1:7447/5d571edbdd2eqb6839_0"  #Find this in the unifi video controller interface
CAMS["Back Garden"]="rtsp://address_to_unifi_video_controller:7447/some_long_hash-like_thing_0"

# If we are in a terminal, be verbose.
if [[ -z $VERBOSE && -t 1 ]]; then
  VERBOSE=1
fi

log()
{
  if [ ! -z $VERBOSE ]; then echo "$@"; fi
}

logerr() 
{ 
  echo "$@" 1>&2; 
}

createDir()
{
  if [ ! -d "$1" ]; then
    mkdir "$1"
    # check error here
  fi  
}

getSnap() {

  snapDir="$SNAP_BASE/$1"
  if [ ! -d "$snapDir" ]; then
    mkdir -p "$snapDir"
    # check error here
  fi
  
  snapFile="$snapDir/$1 - $DATE_EXT.jpg"

  log savingSnap "$2" to "$snapFile" 

  ffmpeg -ss 00:00:00 -i $2 -vframes 1 -q:v 1 $snapFile
  #wget --quiet -O "$snapFile" "$2"
}

createMovie()
{
  snapDir="$SNAP_BASE/$1"
  snapTemp="$snapDir/temp-$DATE_EXT"
  snapFileList="$snapDir/temp-$DATE_EXT/files.list"
  
  if [ ! -d "$snapDir" ]; then
    logedd "Error : No media files in '$snapDir'"
    exit 2
  fi

  createDir "$snapTemp"

  if [ "$2" = "today" ]; then
    log "Creating video of $1 from today's images"
    ls "$snapDir/"*`date '+%F'`*.jpg | sort > "$snapFileList"
  elif [ "$2" = "yesterday" ]; then
    log "Creating video of $1 from yesterday's images"
    ls "$snapDir/"*`date '+%F' -d "1 day ago"`*.jpg | sort > "$snapFileList"
  elif [ "$2" = "file" ]; then
    if [ ! -f "$3" ]; then
      logerr "ERROR file '$3' not found"
      exit 1
    fi
    log "Creating video of $1 from images in $3"
    cp "$3" "$snapFileList"
  else
    log "Creating video of $1 from all images"
    `ls "$snapDir/"*.jpg | sort > "$snapFileList"`
  fi

  # need to chance current dir so links work over network mounts
  cwd=`pwd`
  cd "$snapTemp"
  x=1
  #for file in $snapSearch; do
  while IFS= read -r file; do
    counter=$(printf %06d $x)
    ln -s "../`basename "$file"`" "./$counter.jpg"
    x=$(($x+1))
  done < "$snapFileList"
  #done

  if [ $x -eq 1 ]; then
    logerr "ERROR no files found"
    exit 2
  fi

  createDir "$OUT_DIR"
  outfile="$OUT_DIR/$1 - $DATE_EXT.mp4"

  ffmpeg -r 15 -start_number 1 -i "$snapTemp/"%06d.jpg -c:v libx264 -preset slow -crf 18 -c:a copy -pix_fmt yuv420p "$outfile" -hide_banner -loglevel panic

  log "Created $outfile"

  cd $cwd
  rm -rf "$snapTemp"
  
}


case $1 in
  savesnap)
    for ((i = 2; i <= $#; i++ )); do
      if [ -z "${CAMS[${!i}]}" ]; then
        logerr "ERROR, can't find camera '${!i}'"
      else
        getSnap "${!i}" "${CAMS[${!i}]}"
      fi
    done
  ;;

  createvideo)
    createMovie "${2}" "${3}" "${4}"
  ;;

  *)
    logerr "Bad Args use :-"
    logerr "$0 savesnap \"camera name\""
    logerr "$0 createvideo \"camera name\" today"
    logerr "options (today|yesterday|all|filename)"
  ;;

esac



