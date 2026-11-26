# Tonverk Kit Forge

A small, cross-platform desktop app that builds random drum subtrack kits for the Elektron Tonverk from your own WAV sample folders.

Tonverk Kit Forge was inspired by [Kit Constructor by Metropolis Border](https://metropolisborder.github.io/kit-constructor/). This is an independent project and is not affiliated with or endorsed by the Kit Constructor author or Elektron.

## Features

- Assign a separate WAV folder and editable category to each of eight slots.
- Remembers the selected folders, output folder, categories, and kit count between launches.
- Randomly selects a sample for each slot and creates as many as 500 kits per run.
- Converts each sample to 48 kHz, 24-bit PCM WAV, mono, peak-normalized to −0.3 dBFS.
- Creates one ZIP per kit. Each ZIP contains a same-named folder, eight WAV files, and a matching `.eldrum` mapping.
- Uses the mapping pitches from the supplied example: 60, 62, 64, 65, 67, 69, 71, and 72.

Input folders are scanned nonrecursively and accept uncompressed PCM WAV files with 8, 16, 24, or 32 bits per sample. Stereo and multichannel audio is downmixed by averaging the channels. Other input formats can be converted to WAV before use.

## Run from source

Python 3.10 or newer is required. Tkinter is included with most Python distributions. On some Linux distributions, install its separate Tk package (for example `python3-tk`).

```bash
python3 app.py
```

No Python packages are needed to run the source version.

## Build a standalone app

Install the build dependency:

```bash
python3 -m pip install -r requirements-build.txt
```

Then build on the operating system you want to target:

```bash
pyinstaller --noconfirm --windowed --name "Tonverk Kit Forge" app.py
```

The app is created in `dist/`. Build separately on macOS, Windows, and Linux; PyInstaller does not cross-compile desktop apps between operating systems. On Linux, Tkinter must be installed on the build machine.

## GitHub Actions builds

The workflow in `.github/workflows/build.yml` builds all three desktop targets when changes are pushed to `main`, when run manually, or when a version tag such as `v1.0.0` is pushed. Each platform build is uploaded as a downloadable workflow artifact. Tag builds also create a GitHub Release with the packaged app files.

To make a release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Settings and generated files

Settings are stored locally in the operating system's normal per-user configuration folder. Sample audio stays on your computer; it is only read to build the ZIP files.

Each output ZIP has this structure:

```text
KIT NAME/
├── 1_kick_KIT NAME.wav
├── 2_kick2_KIT NAME.wav
├── 3_snare_KIT NAME.wav
├── 4_perc_KIT NAME.wav
├── 5_misc_KIT NAME.wav
├── 6_tom_KIT NAME.wav
├── 7_hihat_KIT NAME.wav
├── 8_cymbal_KIT NAME.wav
└── KIT NAME.eldrum
```

## License

MIT. See [LICENSE](LICENSE).
