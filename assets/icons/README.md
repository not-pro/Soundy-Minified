# Soundy Minified icons

The app uses the original ear-on-keycap shape, recolored in violet and cobalt blue so it is distinct from Soundy’s amber icon. `soundy.png` is the transparent master; `Soundy.icns` contains the macOS sizes from 16 to 1024 pixels. The monochrome menu-bar template uses the system tint. Windows assets are exported in violet-blue for consistency.

Regenerate platform files on macOS:

```sh
swift -module-cache-path .zig-cache/installer-swift-cache scripts/export-icons.swift
```

The recolor was made with the built-in imagegen tool, editing the original Soundy master. Final prompt:

> Use case: precise-object-edit. Asset type: macOS application icon for Soundy Minified. Input image 1 is the EDIT TARGET, the existing Soundy icon. Change ONLY its amber/orange color palette to a rich violet-blue palette: deep cobalt blue glass body, violet and electric blue rim light, luminous pale lavender ear glyph highlights. Preserve the exact ear-on-keycap geometry, framing, dimensions, perspective, proportions, glass material, polished bevels, reflections, composition and transparent background. It should be clearly the same icon recolored, not redesigned. No orange or amber remaining. No text, letters, extra shapes, backdrop or watermark. Output a square 1024x1024 icon with real transparent alpha around the keycap.
