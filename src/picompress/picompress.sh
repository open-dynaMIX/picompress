#!/bin/bash


APPNAME="picompress"

scriptlocation=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$scriptlocation")

# Translation
TEXTDOMAIN=picompress.sh
TEXTDOMAINDIR="${SCRIPTPATH}/locale"
export TEXTDOMAIN
export TEXTDOMAINDIR

show_help () {
    echo -e $"\
Usage: $0 [OPTIONS]

Optional arguments:
  -h              Show this help message and exit
  -d              Print debug-messages\
"
}

parse_args () {
    OPTIND=1

    debug=false

    while getopts "h?d" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        d)  debug=true
            ;;
        esac
    done

    shift $((OPTIND-1))

    [ "$1" = "--" ] && shift

    [ $# -eq 1 ] && directory="${1%/}/"

    if ! [ -d "$directory" ]; then
        echo -e $"$directory is not a directory!" 1>&2
        exit 1
    fi
}

dep_check () {
    if ! which "$1" >> /dev/null 2>&1; then
        echo -e $"Couldn't find $2.\nYou need to install it to use $APPNAME." 1>&2
        exit 1
    fi
}

check_geometry () {
    # check if geometry is in one of the following formats: 100 or x100 or 100x100 or 100%
    regex='^0*(100|[0-9]?[0-9])%$|^([1-9][0-9]+)?x?([1-9][0-9])?+$|^$'
    if echo "$1" | egrep "$regex" | egrep -qv "^x$"; then
        return 0
    else
        return 1
    fi
}

round () {
    # Round floats. $1: float to round $2: how many decimals
    printf %."$2"f "$(echo "scale=$2;(((10^$2)*$1)+0.5)/(10^$2)" | bc)"
}

collect_filenames () {
    picfiles=()
    picfilesjpg=()
    picfilespng=()
    for file in "$1"*; do
        type=$(file "$file")
        if echo "$type" | egrep -q "JPEG image data"; then
            picfiles+=("$(basename "$file")")
            picfilesjpg+=("$(basename "$file")")
        fi
        if echo "$type" | egrep -q "PNG image data"; then
            picfiles+=("$(basename "$file")")
            picfilespng+=("$(basename "$file")")
        fi
    done
}

fetch_path () {
    # fetch the image-directory, strip ending newline and add a /
    if [ -d "${HOME}/Pictures" ]; then
        start_path="--filename=${HOME}/Pictures/"
    elif [ -d "${HOME}/Bilder" ]; then
        start_path="--filename=${HOME}/Bilder/"
    else
        start_path="--filename=${HOME}/"
    fi

    directory=$(zenity --file-selection --directory "$start_path" --window-icon="${SCRIPTPATH}/data/pixmaps/${APPNAME}.png" --text=$"Choose a folder with image-files:" --title="$APPNAME"|cut -d: -f2)

    # if the user clicks 'cancel'
    if [[ "$directory" == "/" ]]; then
        exit 1
    fi
    if ! [[ -n "$directory" ]]; then
        exit 0
    fi
    directory="${directory}/"
}

fetch_comprate () {
    comprate=$(zenity --scale --value=100 --min-value=1 --text=$"Choose the quality of the image-files in %:" --title=$"$APPNAME - Compression" --window-icon="${SCRIPTPATH}/data/pixmaps/${APPNAME}.png")
    if ! [[ -n "$comprate" ]]; then
        exit 0
    fi

    if ! [[ $comprate -eq 100 ]]; then
        doitcomp=("-quality" "$comprate")
    fi
}

doyouwantit () {
    picfilescount=${#picfiles[@]}
    if ! zenity --question --window-icon="${SCRIPTPATH}/data/pixmaps/${APPNAME}.png" --text=$"There are $picfilescount image-files in $directory.\nDo you want to shrink or rename them?" --title="$APPNAME"; then
        exit 0
    fi
}

fetch_geometry () {
    text=$"Enter the target-size of the images in pixel or in percent. Enter 100% to keep the actual size.
The ratio of the images will stay the same.

Examples:
Width in pixels: 120
Heigth in pixels: x120
Width & heigth in pixels: 120x120
Percent: 50%

Default is 100%"

    while true; do
        if ! geometry=$(zenity --entry --window-icon="${SCRIPTPATH}/data/pixmaps/${APPNAME}.png" --title=$"$APPNAME - Image-size" --text="$text"); then
            exit 0
        fi
        if ! check_geometry "$geometry"; then
            zenity --error --window-icon="${SCRIPTPATH}/data/pixmaps/${APPNAME}.png" --text=$"You need to enter a value in percent or pixels!" --title=$"$APPNAME - Error!"
            continue
        else
            if ! [[ -n $geometry ]]; then
                geometry="100%"
            fi
            break
        fi
    done
    if [[ "$geometry" == "100%" ]]; then
      true
    else
      doitsize=("-resize" "$geometry")
    fi
}

wannarename () {
    if ! zenity --question --window-icon="${SCRIPTPATH}/data/pixmaps/${APPNAME}.png" --text=$"Do you want to rename the images, according to the timestamp in the EXIF-header (the time you've taken the picture)?\nThis works only for \*.jpg-files." --title="$APPNAME"; then
        return 1
    fi
}

fetch_rename () {
    while true; do
        if ! rename=$(zenity --entry --window-icon="${SCRIPTPATH}/data/pixmaps/${APPNAME}.png" --title=$"$APPNAME - Rename images" --text=$"\
%H Hour in 24-hour format (00 - 23)
%j Day of year as decimal number (001 - 366)
%m Month as decimal number (01 - 12)
%M Minute as decimal number (00 - 59)
%S Second as decimal number (00 - 59)
%w Weekday as decimal number (0 - 6; Sunday is 0)
%y Year without century, as decimal number (00 - 99)
%Y Year with century, as decimal number\n
If there is no Timestamp in the EXIF-header,
the timestamp of the file will be used." --entry-text="%Y-%m-%d_%H-%M-%S"); then
            exit 0
        else
            break
        fi
    done
}

mk_workdir () {
    if [ -d "${directory}picompress1" ]; then
        foldercount=2
        while true; do
            if [ -d "${directory}picompress${foldercount}" ]; then
                let foldercount=foldercount+1
            else
                mkdir "${directory}picompress${foldercount}"
                workdir="${directory}picompress${foldercount}/"
                break
            fi
        done
    else
        mkdir "${directory}picompress1"
        workdir="${directory}picompress1/"
    fi
}

do_convert () {
    if [[ $doconvert == true ]]; then
        convert "${doitcomp[@]}" "${doitsize[@]}" "${directory}${pic}" "${workdir}${pic}"
        converterror=$?
    fi
}

do_rename () {
    if [[ $dorenaming == true ]]; then
        if ! [[ -f "${workdir}${pic}" ]]; then
            cp "${directory}${pic}" "${workdir}${pic}"
            cperror=$?
        fi
        if file "${workdir}${pic}" | egrep -q "JPEG image data"; then
            jhead -q -se -ft -nf"$rename" "${workdir}${pic}"
            jheaderror=$?
        fi
    fi
}

collect_errors () {
    if [[ $converterror -ne 0 ]]; then
        error_text+=$"\nShrinking          $pic"
    fi

    if [[ $jheaderror -ne 0 ]]; then
        error_text+=$"\nRenaming           $pic"
    fi

    if [[ $cperror -ne 0 ]]; then
        error_text+=$"\nCopying            $pic"
    fi
}

do_debug () {
    if $debug; then
        echo -e "DEBUG: $1" 1>&2
    fi
}

parse_args "$@"
dep_check zenity zenity
dep_check jhead jhead
dep_check convert imagemagick

if ! [ -n "$directory" ]; then
    # Welcome
    if ! zenity --info --title="$APPNAME" --window-icon="${SCRIPTPATH}/data/pixmaps/${APPNAME}.png" --text=$"$APPNAME\n\nChoose a folder with \*.jpg- and/or \*.png-files to process."; then
        exit 0
    fi
fi

while true; do
    if ! [ -n "$directory" ]; then
        do_debug "fetch_path"
        fetch_path
    else
        do_debug $"directory is already set."
    fi

    do_debug "collect_filenames"
    collect_filenames "$directory"

    if ! [[ -n "${picfiles[@]}" ]]; then
        zenity --info --window-icon="${SCRIPTPATH}/data/pixmaps/${APPNAME}.png" --title=$"$APPNAME - Error!" --text=$"The folder $directory contains no \*.jpg- or \*.png-files."
        unset directory
        continue
    fi

    do_debug "doyouwantit"
    doyouwantit

    do_debug "fetch_comprate"
    fetch_comprate

    do_debug "fetch_geometry"
    fetch_geometry

    if [[ "$comprate" == "100" ]] && [[ "$geometry" == "100%" ]]; then
        doconvert=false
    else
        doconvert=true
    fi

    do_debug "wannarename"
    if wannarename; then
        dorenaming=true
        do_debug "fetch_rename"
        fetch_rename
    else
        dorenaming=false
    fi

    if [[ $doconvert == false ]] && [[ $dorenaming == false ]]; then
        zenity --error --window-icon="${SCRIPTPATH}/data/pixmaps/${APPNAME}.png" --text=$"Your settings won't change anything on the images!" --title=$"$APPNAME - Error!"
        continue
    fi

    if [[ $dorenaming == true ]]; then
        if [ ${#picfilesjpg[@]} -eq 0 ]; then
            zenity --error --window-icon="${SCRIPTPATH}/data/pixmaps/${APPNAME}.png" --text=$"There are no *.jpg-files in $directory.\nRenaming only works on them!" --title=$"$APPNAME - Error!"
            continue
        fi
    fi

    do_debug "mk_workdir"
    mk_workdir

    percent=$(bc -l <<< "100/$picfilescount")
    percentorig=$percent
    fileof=1
    error_text=$"One or more error(s) occured:\n"

    (
    for pic in "${picfiles[@]}"; do
        do_debug "do_convert"
        do_convert

        do_debug "do_rename"
        do_rename

        do_debug "collect_errors"
        collect_errors
        echo "$percent"
        echo $"# Image $fileof of $picfilescount was processed."

        percent=$(echo "$percent"+"$percentorig" | bc)
        let fileof=fileof+1
    done
    ) | zenity --progress --auto-close --window-icon="${SCRIPTPATH}/data/pixmaps/${APPNAME}.png" --text=$"$picfilescount image-files are about to get shrinked and/or renamed." --title="$APPNAME" --percentage=0

    if [ $? -ne 0 ]; then
      exit 1
    fi

    if [ "$(echo "$error_text" | wc -l)" -gt 2 ]; then
        zenity --error --window-icon="${SCRIPTPATH}/data/pixmaps/${APPNAME}.png" --text="$error_text" --title=$"$APPNAME - Error!"
        exit 1
    else
        if zenity --question --window-icon="${SCRIPTPATH}/data/pixmaps/${APPNAME}.png" --text=$"$picfilescount image-files were successfully processed.\nDo you want to shrink or rename other images?" --title=$"$APPNAME - Success!"; then
            continue 2
        else
            exit 0
        fi
    fi
done
