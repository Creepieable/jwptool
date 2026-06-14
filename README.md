# jwptool

A bash script to generate wallpaper packages from a source image. The image is cropped to a target aspect ratio and rendered at multiple resolutions, with output formatted for KDE Plasma, Linux Mint (WIP), or as a bare directory of images, with added metadata files.

## Dependencies

- [ImageMagick 7+](https://imagemagick.org/) (`magick`, `identify`)
- `util-linux` (for enhanced `getopt`)

## Usage

```
jwptool [options] <input>

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
  -h, --help            Show help and exit
```

## Examples

```bash
# Basic usage — bare directory of images at default widths
jwptool wallpaper.png

# KDE Plasma package at 16:10 with a custom output directory
jwptool --ratio 16:10 --output MyWall --type KDE photo.jpg

# Convert to lossless WEBP, skip all prompts
jwptool -f WEBPl -s image.png

# Set metadata via command line
jwptool -m artist=John -m license=CC0 photo.jpg

# Pass extra ImageMagick arguments
jwptool -e "-quality 85" photo.jpg

# Batch: build one package per image in a folder
jwptool --output Packs ./my_images/
```

## Batch Processing

If `<input>` is a directory, jwptool processes every supported image inside it (`.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, case-insensitive), creating one package per image. In this mode `--output` is the parent directory that holds all the packages, each named after the input directory with a counter (e.g. `my_images_Wallpaper_1`, `my_images_Wallpaper_2`, …).

Unless `--yes` or `--skip` is given, jwptool asks for confirmation before starting a batch run.

## Package Types

- **Bare** — a flat directory of resized images, named by resolution (e.g. `1920x1080.jpg`)
- **KDE** — a KDE Plasma wallpaper package with `contents/images/` layout and `metadata.json`
- **Mint** — Linux Mint / Cinnamon wallpaper package (work in progress)

## Metadata

For package types that support metadata (KDE, Mint), jwptool will prompt for the following fields unless `--skip` is used:

| Key | Description | Default |
|-----|-------------|---------|
| `title` | Wallpaper title | Input filename without extension |
| `artist` | Artist name | Parent directory of the input image |
| `site` | Artist website | _(empty)_ |
| `license` | License string | `Unspecified` |

Metadata can also be set non-interactively via `-m`:

```bash
jwptool -t KDE -m title="Mountain Sunset" -m artist="Jane Doe" -m license=CC-BY-4.0 photo.jpg
```

## Installation

```bash
git clone https://github.com/jaybla/jwptool.git
cd jwptool
chmod +x jwptool.sh
# Optionally symlink to somewhere on your PATH:
ln -s "$PWD/jwptool.sh" ~/.local/bin/jwptool
```

## Bash Completion

```bash
# Install bash completion (user)
ln -s "$PWD/jwptool-completion.bash" ~/.local/share/bash-completion/completions/jwptool
```

Completion supports all options, with context-aware suggestions for `-t`, `-f`, `-r`, `-w`, and file completion for `<input>` (filtered to supported image types).

## License

GPL v3 — see [LICENSE](LICENSE)

## Author

Jay Bla
