_jwptool() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$prev" in
  -o | --output)
    # complete directories
    COMPREPLY=($(compgen -d -- "$cur"))
    return
    ;;
  -r | --ratio)
    COMPREPLY=($(compgen -W "16:9 16:10 4:3 21:9" -- "$cur"))
    return
    ;;
  -t | --type)
    COMPREPLY=($(compgen -W "KDE Mint Bare" -- "$cur"))
    return
    ;;
  -f | --format)
    COMPREPLY=($(compgen -W "KEEP PNG JPG WEBP WEBPl" -- "$cur"))
    return
    ;;
  -w | --widths)
    COMPREPLY=($(compgen -W "1920 2560 3840 1920,2560 1920,2560,3840" -- "$cur"))
    return
    ;;
  -e | --extra)
    # free-form, no completion
    return
    ;;
  esac

  # complete options if the word starts with -
  if [[ $cur == -* ]]; then
    COMPREPLY=($(compgen -W "
      -o --output
      -r --ratio
      -t --type
      -f --format
      -w --widths
      -e --extra
      -u --upscale
      -s --skip
      -y --yes
      -v --verbose
      -h --help
    " -- "$cur"))
    return
  fi

  # otherwise complete files (the <input> argument)
  COMPREPLY=($(compgen -f -- "$cur"))
}

complete -F _jwptool jwptool
complete -F _jwptool jwptool.sh
