# ARCHiVES

Lightweight archive extraction and compression for macOS, built into the Finder.

## About

ARCHiVES is a small personal app inspired by The Unarchiver, with no link to its authors. Double-click an archive (ZIP, RAR, 7z, TAR, GZ, BZ2, XZ…) and it is extracted into a folder named after the file, next to it. Right-click one or more files › Services › "Extract" / "Create an ARCHiVE". Password-protected archives are supported (ZIP, 7z, RAR for extraction; ZIP/7z for creation). Authors: Starbudweiser & Claude Code (Anthropic). MIT License, provided as is, without warranty. See the "About ARCHiVES" menu entry in the app.

## Build

```bash
brew install sevenzip   # 7zz is embedded in the app (passwords, RAR fallback)
./build_app.sh          # tests, build, signature, install in ~/Applications/Applications Personnelles
```

Engine: system `libarchive` (no password) and an embedded `7zz` (passwords, RAR fallback). RAR creation is impossible (proprietary format).
