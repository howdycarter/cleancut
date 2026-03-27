# Custom Fonts

Drop your `.ttf` or `.otf` font files into this directory, then:

1. **Add to Xcode target** -- ensure each font file is included in the app
   target's "Copy Bundle Resources" build phase (XcodeGen handles this
   automatically via `project.yml`).

2. **Register in Info.plist** -- add every file name (e.g. `Poppins-Bold.ttf`)
   to the `UIAppFonts` array ("Fonts provided by application").

3. **Update FontRegistry** -- open `Core/Theme/FontRegistry.swift` and set
   each `FontFamily` case's raw value to the font's **PostScript name**.

   To find PostScript names, temporarily call `FontRegistry.logAvailableFonts()`
   from any `onAppear` and check the Xcode console.

4. **Done** -- every view already uses `AppTypography` / `.appFont(...)`,
   so the entire app picks up the new fonts automatically.

## Example (Poppins)

```
Resources/Fonts/
  Poppins-Regular.ttf
  Poppins-Medium.ttf
  Poppins-SemiBold.ttf
  Poppins-Bold.ttf
```

Info.plist entry:
```xml
<key>UIAppFonts</key>
<array>
  <string>Poppins-Regular.ttf</string>
  <string>Poppins-Medium.ttf</string>
  <string>Poppins-SemiBold.ttf</string>
  <string>Poppins-Bold.ttf</string>
</array>
```

FontRegistry.swift:
```swift
public enum FontFamily: String, Sendable {
    case regular  = "Poppins-Regular"
    case medium   = "Poppins-Medium"
    case semibold = "Poppins-SemiBold"
    case bold     = "Poppins-Bold"
}
```
