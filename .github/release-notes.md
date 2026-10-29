Soundy Minified 1.0.1 reduces audio memory use and moves translations into a JSON resource.

- Decode only the selected keyboard pack and mouse pair (at most 12 buffers). Reuse the audio engine and compatible voice pools; release unused buffers and nodes when switching.
- Load replacement sounds on the serial audio queue. Failed loads preserve the working selection and restore its preferences; outdated failures cannot overwrite a newer choice.
- Read English, Russian and Simplified Chinese translations from `i18n.json` once at startup, with validation of all languages and message keys.

Measured physical footprint with Tactile on the development Mac: about 14 MiB after startup and 16 MiB after 168 profile changes, compared with 34.5 MiB before this update. Actual memory use depends on the selected sounds and system.

Download `arm64` for Apple Silicon or `x86_64` for Intel. Each architecture includes a PKG installer, a ZIP for manual installation, and SHA-256 checksums. Requires macOS 13+.
