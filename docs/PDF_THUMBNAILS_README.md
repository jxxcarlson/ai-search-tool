# PDF Thumbnail Generation

To enable PDF thumbnail generation, you need to install poppler:

## macOS
```bash
brew install poppler
```

## Ubuntu/Debian
```bash
sudo apt-get install poppler-utils
```

## Windows
Download poppler for Windows from: https://github.com/oschwartz10612/poppler-windows/releases
Add the `bin` folder to your PATH.

## Note
Without poppler, PDF uploads will still work but thumbnail generation will be skipped.