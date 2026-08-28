# Popoji

Popoji is a native macOS menu-bar app for inserting emoji without leaving the keyboard. Type a colon followed by two letters, numbers, `+`, or `-` (for example, `:sm`), choose a match with the arrow keys, and press Return to replace the trigger with the emoji.

## Build and run

Popoji requires macOS 13 or later and the Swift toolchain.

If this is the first command-line build after installing Xcode, accept Apple's license first with `sudo xcodebuild -license accept`.

### One-time signing setup

Popoji must use the same code-signing identity across builds for macOS to preserve its Accessibility permission. The packaging script automatically uses an Apple Development identity when one is available. Otherwise, create a local identity once:

1. Open **Keychain Access**.
2. Choose **Keychain Access → Certificate Assistant → Create a Certificate**.
3. Name it `Popoji Local Development`.
4. Select **Self Signed Root** as the identity type and **Code Signing** as the certificate type.
5. Enable **Let me override defaults**, use a unique serial number, and optionally set a longer validity period for local development.
6. Continue through the remaining screens with their defaults and save the certificate in the **login** keychain.

You can instead select another installed identity by setting `POPOJI_CODESIGN_IDENTITY` to its exact name.

```sh
chmod +x scripts/package-app.sh
./scripts/package-app.sh debug
open dist/Popoji.app
```

The first launch asks for Accessibility permission. Enable Popoji in **System Settings → Privacy & Security → Accessibility**, then click **Check Accessibility Permission** from its menu-bar icon. When switching from an older ad-hoc-signed build, remove the old Popoji entry and add the newly signed app once. Later builds signed with the same identity retain the grant. This permission is required to read global keyboard events and type the selected emoji into another app.

## Controls

- Type `:` plus two letters to open the picker.
- Use Up/Down to change the selection.
- Press Return to insert, or Escape to close.
- Clicking an emoji also inserts it without taking focus from the current app.

The initial emoji catalog lives in `Sources/Popoji/Emoji.swift` and can be expanded without changing the picker logic.
