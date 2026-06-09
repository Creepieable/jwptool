#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2025 Jay Bla

set -euo pipefail

usage() {
  cat <<EOF
Usage: ${0##*/} [options] <input>

Generate a wallpaper package from an input image. The image is cropped to
the target aspect ratio and rendered at multiple resolutions.

Arguments:
  <input>               Path to the source image (JPEG, PNG, or GIF)

Options:
  -o, --output DIR      Output directory (default: Wallpaper_<timestamp>)
  -r, --ratio RATIO     Target aspect ratio, e.g. 16:9 or 16:10 (default: 16:9)
  -t, --type TYPE       Package type: KDE, Mint, Bare (default: Bare)
  -f, --format FMT      Output format: KEEP, PNG, JPG, WEBP, WEBPl (lossless) (default: KEEP)
  -w, --widths LIST     Comma-separated output widths in pixels (default: 1920,2560,3840)
  -e, --extra ARGS      Extra arguments passed to ImageMagick (e.g. -quality 85)
  -u, --upscale         Allow upscaling images smaller than the target width
  -s, --skip            Skip all prompts (use defaults)
  -y, --yes             Say yes to all prompts (use default behaviour)
  -v, --verbose         Enable verbose output
  -h, --help            Show this help and exit

Examples:
  ${0##*/} wallpaper.png
  ${0##*/} --ratio 16:10 --output MyWall --type KDE photo.jpg
  ${0##*/} -sv image.png
EOF
}

log() {
  if [[ $verbose -eq 1 ]]; then
    echo "$@" >&2
  fi
}

TEMPFILES=()
cleanup() {
  local f
  for f in "${TEMPFILES[@]+"${TEMPFILES[@]}"}"; do
    rm -f "$f"
  done
}
trap 'cleanup' EXIT

##
# main pack creation func
##
create-wallpaper-package() {
  wp_id="wp_$(date +%s)"
  wp_title="${input##*/}"
  wp_title="${wp_title%.*}"
  wp_artist="Unknown"
  wp_license="Unspecified"
  wp_site=""

  log "Creating $type wallpaper package: $output"

  case "$type" in
  KDE) create_kde ;;
  Mint)
    echo "Mint support is not yet implemented."
    exit 1
    ;; #create_mint ;;
  Bare) create-bare ;;
  *)
    echo "Type $type not supported" >&2
    exit 1
    ;;
  esac

  log "Wallpaper $output of type $type created."
  echo "$output"
}

##
# specific pack creation funcs
##
create-bare() {
  mkdir -p "$output"
  log "Created output directory."

  format-img "$output"
}

create_kde() {
  # ask for metadata
  if [[ $skip -ne 1 ]]; then
    ask_meta
  else
    log "Skipping metadata prompts."
  fi

  # create directory structure
  kde_dirs="${output}/contents/images"
  mkdir -p "${kde_dirs}"
  log "Created directory structure: ${kde_dirs}"

  # create images at output path
  format-img "$kde_dirs"

  # create metadata file
  kde_json_file="$output/metadata.json"
  cat >"$kde_json_file" <<EOF
{
  "KPlugin": {
    "Authors": [
      {
        "Name": "${wp_artist}",
        "Website": "${wp_site}"
      }
    ],
  "Id": "${wp_id}",
  "License": "${wp_license}",
  "Name": "${wp_title}"
  }
}
EOF
  log "Wrote $kde_json_file"
}

create_mint() {
  # ask for metadata
  if [[ $skip -ne 1 ]]; then
    ask_meta
  else
    log "Skipping metadata prompts."
  fi

  # mirror the system layout: backgrounds/<name>/ + a properties xml
  name=$(basename "$output")
  bg_dir="${output}/backgrounds/${name}"
  props_dir="${output}/cinnamon-background-properties"
  mkdir -p "$bg_dir" "$props_dir"
  log "Created directory structure: ${bg_dir}"

  # generate the images into the backgrounds dir
  format-img "$bg_dir"

  # absolute path is required by the XML — resolve output as it exists now
  abs_bg=$(cd "$bg_dir" && pwd)

  xml_file="${props_dir}/${name}.xml"
  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">'
    echo '<wallpapers>'
    for f in "$abs_bg"/*."${ext}"; do
      [ -e "$f" ] || continue        # guard: no files matched
      res=$(basename "$f" ".${ext}") # e.g. 1920x1080
      cat <<EOF
  <wallpaper deleted="false">
    <name>${wp_title} (${res})</name>
    <filename>${f}</filename>
    <options>zoom</options>
  </wallpaper>
EOF
    done
    echo '</wallpapers>'
  } >"$xml_file"

  log "Wrote $xml_file"
}

ask_meta() {
  # ask metadata
  wp_id=$(date +%s)

  read -r -p "Image Title [$wp_title]: " out
  wp_title="${out:-$wp_title}"

  read -r -p "Artist Name [$wp_artist]: " out
  wp_artist="${out:-$wp_artist}"

  read -r -p "Artist Website [$wp_site]: " out
  wp_site="${out:-$wp_site}"

  read -r -p "License [$wp_license]: " out
  wp_license="${out:-$wp_license}"
}

format-img() {
  img_output_dir=$1

  # manage image Filetype
  fmt=$(identify -format "%m" "$input"[0])
  ext=""
  case "$fmt" in
  JPEG | JPG) ext="jpg" ;;
  PNG) ext="png" ;;
  GIF) ext="gif" ;;
  WEBP) ext="webp" ;;
  *)
    echo "Filetype is not supported" >&2
    exit 1
    ;;
  esac

  # Copy to output directory
  image="$img_output_dir/image.${ext}"

  # extra args passed to all magick invocations
  if [[ $format == "WEBPl" ]]; then
    magick_extra_args+=(-define webp:lossless=true)
    log "Added lossless webp ImageMagick parameter."
  fi

  # Keep/Convert image
  if [[ $format != "KEEP" ]]; then
    ext=${format,,}
    ext=${ext%l}
    image="$img_output_dir/image.${ext}"
    magick "$input" "${magick_extra_args[@]}" "$image"
    log "Formatted image to $ext."
  else
    cp "$input" "$image"
    log "Kept format."
  fi

  TEMPFILES+=("$image")

  # manage image ratio and crop
  rw="${ratio%:*}"
  rh="${ratio#*:}"

  match=$(identify -format "%[fx: abs( (w/h) - ($rw/$rh) ) < 0.01 ? 1 : 0 ]" "$image"[0])
  log "Matching $ratio to input image."

  # match aspect ratio
  if [[ $yes -ne 1 ]]; then
    if [[ "$match" -ne 1 ]]; then
      actual=$(identify -format "%[fx:w/h]" "$image"[0])
      target=$(magick xc: -format "%[fx:$rw/$rh]" info:)
      echo "Warning: image '$image' is not $ratio ≈ $target (actual ratio ≈ $actual) and will be cropped."
      read -rp "Continue to crop image? [y/N] " answer
      case "$answer" in
      [Yy]*) ;;
      *)
        echo "Cancelled."
        exit 1
        ;;
      esac
    else
      log "Aspect ratio matches."
    fi
  else
    log "Skipping crop confirmation (--yes)."
  fi

  # crop image to fix ratio
  magick "$image" -gravity center -crop "$(identify -format "%[fx:min(w,h*${rw}/${rh})]x%[fx:min(h,w*${rh}/${rw})]+0+0" "$image")" +repage "$image"
  log "Cropped image to ${rw}:${rh}."

  img_width=$(identify -format "%w" "$image")

  # create resized variants
  for w in "${widths[@]}"; do
    log "Trying to convert to width $w"

    if [[ $w -gt $img_width && $upscale -ne 1 ]]; then
      log "Skipping: $w, image too small."
      continue
    fi

    tmp=$(mktemp "${img_output_dir}/.resize.XXXXXX")
    TEMPFILES+=("$tmp")
    magick "$image" -resize "$w" "${magick_extra_args[@]}" "${ext}:${tmp}"
    res=$(identify -format "%wx%h" "$tmp")

    final="${img_output_dir}/${res}.${ext}"
    mv "$tmp" "${final}"
    TEMPFILES=("${TEMPFILES[@]/$tmp/}")
    log "Created: $final"
  done

  rm "$image"
  TEMPFILES=("${TEMPFILES[@]/$image/}")
  log "Removed original copy."
}

##
# main
##
input=""
output="Wallpaper_$(date +%s)"
verbose=0
skip=0
yes=0
upscale=0

format="KEEP"

widths=(1920 2560 3840)
ratio="16:9"

magick_extra_args=()

type="Bare"

# test getopt
getopt --test >/dev/null && true
if [[ ${PIPESTATUS[0]:-$?} -ne 4 ]]; then
  echo "This script needs enhanced getopt (util-linux)." >&2
  exit 1
fi

# parse options
VALID_ARGS=$(getopt -o 'o:r:t:f:w:e:syvuh' \
  --long 'output:,ratio:,type:,format:,widths:,extra:,skip,yes,verbose,upscale,help' \
  -n "${0##*/}" -- "$@") || exit 1

# getopt failed (bad option) → it already printed an error; exit
eval set -- "$VALID_ARGS"
unset VALID_ARGS

while true; do
  case "$1" in
  -o | --output)
    if [[ -z $2 ]]; then
      echo "Option $1 requires a non-empty argument" >&2
      exit 1
    fi
    output="$2"
    shift 2
    ;;
  -r | --ratio)
    ratio="$2"
    shift 2
    ;;
  -t | --type)
    case "$2" in
    KDE | Mint | Bare) type=$2 ;;
    *)
      echo "Invalid wallpaper type $2 (see -h or --help for valid types)" >&2
      exit 1
      ;;
    esac
    shift 2
    ;;
  -f | --format)
    case $2 in
    KEEP | PNG | WEBP | WEBPl) format=$2 ;;
    JPEG | JPG) format="JPG" ;;
    *)
      echo "Invalid format $2 (see -h or --help for valid formats)" >&2
      exit 1
      ;;
    esac
    shift 2
    ;;
  -w | --widths)
    IFS=',' read -ra widths <<<"$2"
    for w in "${widths[@]}"; do
      if ! [[ $w =~ ^[1-9][0-9]*$ ]]; then
        echo "Invalid width '$w': must be a positive integer." >&2
        exit 1
      fi
    done
    shift 2
    ;;
  -e | --extra)
    # shellcheck disable=SC2206
    magick_extra_args+=($2)
    shift 2
    ;;
  -s | --skip)
    skip=1
    shift
    ;;
  -y | --yes)
    yes=1
    shift
    ;;
  -v | --verbose)
    verbose=1
    shift
    ;;
  -u | --upscale)
    upscale=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  --)
    shift
    break
    ;;
  *)
    echo "Internal parsing error: $1" >&2
    exit 1
    ;;
  esac
done

# parse input
input="${1-}"

# return usage if no input
if [[ -z $input ]]; then
  usage
  exit 0
fi

if [[ ! -e $input ]]; then
  echo "'$input' does not exist." >&2
  exit 1
fi

create-wallpaper-package
