#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2025 Jay Bla

set -euo pipefail

usage() {
  cat <<EOF
Usage: ${0##*/} [options] <input>

Generate a wallpaper package from an input image. The image is cropped to
the target aspect ratio and rendered at multiple resolutions.

If <input> is a directory, every supported image in it is processed in
batch mode (one package per image).

Arguments:
  <input>               Path to a source image (JPEG, PNG, GIF, or WEBP),
                        or a directory of images for batch processing

Options:
  -o, --output DIR      Output directory (default: Wallpaper_<timestamp>);
                        in batch mode, the parent dir for all packages
  -r, --ratio RATIO     Target aspect ratio as N:M, e.g. 16:9 or 16:10 (default: 16:9)
  -t, --type TYPE       Package type: KDE, Mint, Bare (default: Bare)
                        (Mint is currently a work in progress)
  -f, --format FMT      Output format: KEEP, PNG, JPG, WEBP, WEBPl (lossless) (default: KEEP)
  -w, --widths LIST     Comma-separated output widths in pixels (default: 1920,2560,3840);
                        widths larger than the source are skipped unless --upscale is set
  -m, --meta KEY=VALUE  Set metadata (repeatable, e.g. -m artist=John -m license=CC0)
                        Valid keys: title, artist, site, license
  -e, --extra ARGS      Extra arguments passed to ImageMagick (e.g. -e "-quality 85")
                        (repeatable, e.g. -e "option 1" -e "option 2")
  -u, --upscale         Allow upscaling images smaller than the target width
  -s, --skip            Skip all prompts (use defaults)
  -y, --yes             Say yes to all prompts (use default behaviour)
  -v, --verbose         Enable verbose output
  -h, --help            Show this help and exit

Examples:
  ${0##*/} wallpaper.png
  ${0##*/} --ratio 16:10 --output MyWall --type KDE photo.jpg
  ${0##*/} -sv image.png
  ${0##*/} -m artist=John -m license=CC0 photo.jpg
  ${0##*/} --output Packs ./my_images/      # batch: every image in the folder
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
  local input_img=$1
  local output_package=$2

  # metadata default
  wp_id="wp_$(date +%s)"
  wp_title="${input_img##*/}"
  wp_title="${wp_title%.*}"
  wp_artist="$(basename "$(dirname "$input_img")")"
  if [[ $wp_artist == "." ]]; then
    wp_artist=$(basename "$PWD")
  fi
  wp_license="Unspecified"
  wp_site=""

  for entry in "${usr_meta[@]}"; do
    key="${entry%%=*}"
    value="${entry#*=}"
    case "$key" in
    title) wp_title="$value" ;;
    artist) wp_artist="$value" ;;
    site) wp_site="$value" ;;
    license) wp_license="$value" ;;
    *)
      echo "Unknown meta key '$key' (valid: title, artist, site, license)" >&2
      exit 1
      ;;
    esac
  done

  log "Creating $type wallpaper package: $output_package"

  case "$type" in
  KDE) create-kde "$input_img" "$output_package" ;;
  Mint) create-mint "$input_img" "$output_package" ;;
  Bare) create-bare "$input_img" "$output_package" ;;
  *)
    echo "Type $type not supported" >&2
    exit 1
    ;;
  esac

  log "Wallpaper $output_package of type $type created."
  echo "$output_package"
}

process-batch() {
  if [[ $yes -ne 1 && $skip -ne 1 ]]; then
    read -rp "Input is a directory, run batch processing? [y/N] " answer
    case "$answer" in
    [Yy]*) ;;
    *)
      echo "Cancelled."
      exit 1
      ;;
    esac
  fi

  local input_dir="$1"
  local output_dir="$2"
  local found=0
  local dirname=""

  dirname="$(basename "$input_dir")"
  if [[ $dirname == "." ]]; then
    dirname=$(basename "$PWD")
  fi

  # get dir name for pack naming
  for f in "$input_dir"/*.{jpg,jpeg,png,gif,webp,JPG,JPEG,PNG,GIF,WEBP}; do
    [[ -e "$f" ]] || continue
    ((found += 1))
    echo "Processing: $f"

    # get image file name for naming package
    file_name="${f##*/}"
    file_name="${file_name%.*}"
    file_name="${file_name// /_}"

    create-wallpaper-package "$f" "$output_dir/${dirname}_Wallpaper_${found}_${file_name}"
  done

  if [[ $found -eq 0 ]]; then
    echo "No supported files in $input_dir." >&2
    exit 1
  fi

  echo "$found wallpaper packages created: $output_dir"
}

##
# specific pack creation funcs
##
create-bare() {
  local input_img="$1"
  local bare_output_dir="$2"

  mkdir -p "$bare_output_dir"
  log "Created output directory."

  format-img "$input_img" "$bare_output_dir"
}

create-kde() {
  local input_img="$1"
  local kde_output_dir="$2"

  # ask for metadata
  if [[ $skip -ne 1 ]]; then
    ask_meta
  else
    log "Skipping metadata prompts."
  fi

  # create directory structure
  kde_dirs="${kde_output_dir}/contents/images"
  mkdir -p "${kde_dirs}"
  log "Created directory structure: ${kde_dirs}"

  # create images at output path
  format-img "$input_img" "$kde_dirs"

  # create metadata file
  kde_json_file="$kde_output_dir/metadata.json"
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

# TODO: not implement fully
create-mint() {
  local input_img="$1"
  local mint_output_dir="$2"

  # ask for metadata
  if [[ $skip -ne 1 ]]; then
    ask_meta
  else
    log "Skipping metadata prompts."
  fi

  echo "$mint_output_dir with $input_img not created, this function is currently WIP."
}

ask_meta() {
  # ask metadata
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
  local input_img=$1
  local img_output_dir=$2

  local magick_extra_args=("${usr_magick_extra_args[@]+"${usr_magick_extra_args[@]}"}")

  # manage image Filetype
  fmt=$(identify -format "%m" "$input_img"[0])
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
    magick "$input_img" "${magick_extra_args[@]}" "$image"
    log "Formatted image to $ext."
  else
    cp "$input_img" "$image"
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
      log "Aspect ratio matches (within margin)."
    fi
  else
    log "Skipping crop confirmation (--yes)."
  fi

  # crop image to fix ratio
  magick "$image" -gravity center -crop "$(identify -format "%[fx:min(w,h*${rw}/${rh})]x%[fx:min(h,w*${rh}/${rw})]+0+0" "$image")" +repage "$image"
  log "Cropped image to ${rw}:${rh}."

  img_width=$(identify -format "%w" "$image"[0])

  local made=0

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
    res=$(identify -format "%wx%h" "$tmp"[0])

    final="${img_output_dir}/${res}.${ext}"
    mv "$tmp" "${final}"
    TEMPFILES=("${TEMPFILES[@]/$tmp/}")
    log "Created: $final"

    ((made += 1))
  done

  if [[ $made -eq 0 ]]; then
    echo "Error: '$input_img' is smaller than all target widths; nothing produced (use --upscale)." >&2
    rm -f "$image"
    exit 1
  fi

  rm "$image"
  TEMPFILES=("${TEMPFILES[@]/$image/}")
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

usr_magick_extra_args=()

usr_meta=()

type="Bare"

# need enhanced getopt
getopt --test >/dev/null && true
if [[ ${PIPESTATUS[0]:-$?} -ne 4 ]]; then
  echo "This script needs enhanced getopt (util-linux)." >&2
  exit 1
fi

# parse options
VALID_ARGS=$(getopt -o 'o:r:t:f:w:e:m:syvuh' \
  --long 'output:,ratio:,type:,format:,widths:,extra:,meta:,skip,yes,verbose,upscale,help' \
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
    if ! [[ $2 =~ ^[1-9][0-9]*:[1-9][0-9]*$ ]]; then
      echo "Invalid ratio '$2': expected N:M (e.g. 16:9)." >&2
      exit 1
    fi
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
    usr_magick_extra_args+=($2)
    shift 2
    ;;
  -m | --meta)
    if [[ $2 != *=* || -z ${2%%=*} || -z ${2#*=} ]]; then
      echo "Invalid meta '$2': expected KEY=VALUE format." >&2
      exit 1
    else
      usr_meta+=("$2")
    fi
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

# usage if no input
if [[ -z $input ]]; then
  usage
  exit 0
fi

if [[ ! -e $input ]]; then
  echo "'$input' does not exist." >&2
  exit 1
fi

# test dependencies
command -v magick >/dev/null && command -v identify >/dev/null || {
  echo "ImageMagick (magick/identify) is required." >&2
  exit 1
}

# run
if [[ -d $input ]]; then
  process-batch "$input" "$output"
elif [[ -f $input ]]; then
  create-wallpaper-package "$input" "$output"
else
  echo "Unknown input type." >&2
  exit 1
fi
