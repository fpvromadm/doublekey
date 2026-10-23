# DoubleKey

A tiny macOS menu bar app that blocks accidental double key presses (key chatter) on worn or butterfly keyboards. Like [Unshaky](https://github.com/aahung/Unshaky), but with no per-key setup: it works on every key out of the box.

- ~220 KB universal binary, ~12 MB memory, 0% CPU when idle
- No timers and no polling: it only wakes up when you press a key
- Starts at login by itself

## How it works

When you press a key again less than **40 ms** after you released it, and you pressed no other key in between, that press is chatter. DoubleKey drops it and its release. Real typing is never that fast, so deliberate double letters ("ll", "ee") still go through.

If you still get doubles, raise the threshold from the menu (Threshold → 50/60/80 ms). If a fast deliberate double tap is lost, lower it.

## Install

```bash
./build.sh install
```

This builds `build/DoubleKey.app`, copies it to `/Applications` and starts it. On first launch macOS asks for **Accessibility** access (System Settings → Privacy & Security → Accessibility). Turn on DoubleKey; it starts working within 2 seconds, no restart needed.

Other commands:

```bash
./build.sh        # build only
./build.sh test   # run the debounce logic tests
```

Needs macOS 13+ and the Xcode command line tools (`xcode-select --install`).

### Signing

`build.sh` signs with `$SIGN_ID`, or the first code-signing identity in your keychain, or ad-hoc. With a real identity, macOS keeps the Accessibility permission across rebuilds. With ad-hoc signing, remove DoubleKey from the Accessibility list and add it again after each rebuild.

## Menu

- **Blocked N double presses**: count since the app started
- **Enabled**: pause or resume filtering
- **Threshold**: 20–100 ms
- **Launch at Login**
- **Quit**

## License

MIT
