# Building PokeRPGLink

This page is for people who want to change PokeRPGLink or build it themselves. To just **use** the app, follow the [README](README.md): install it with Obtainium.

## Build the APK

**A. GitHub (no software needed).** Fork this repo, open the **Actions** tab, wait for **Build PokeRPGLink APK** to go green (≈4 min), open the run, download **PokeRPGLink-apk**, unzip, copy `app-release.apk` to the Thor and install it.

**B. Android Studio on your PC.** *Open* the `android` folder, let it sync, then *Build → Build APK(s)*.

A build signed with a different key can't update the Obtainium install: uninstall that one first (your settings start fresh).

## Signed releases (for Obtainium updates)

Every version must be signed with the same key or Android refuses the update.

1. **Make a signing key — once, and keep it forever** (Android Studio includes `keytool`):
   ```
   keytool -genkeypair -v -keystore pokerpglink.jks -alias pokerpglink -keyalg RSA -keysize 2048 -validity 10000
   ```
   Back up `pokerpglink.jks` and its password somewhere safe. Never commit it.
2. **Give the key to GitHub:** repo → Settings → Secrets and variables → Actions → *New repository secret*:
   - `KEYSTORE_BASE64` — the key file as text. Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("pokerpglink.jks")) | Set-Clipboard`, then paste. Mac/Linux: `base64 -w0 pokerpglink.jks`.
   - `KEYSTORE_PASSWORD`, `KEY_ALIAS` (`pokerpglink`), `KEY_PASSWORD` (the same as the keystore password unless you chose another).
3. **Publish a version:** GitHub → Releases → *Draft a new release* → new tag `v1.2.3` (or `git tag v1.2.3 && git push origin v1.2.3`). The *Release PokeRPGLink* action builds the signed APK and attaches it to the release. Each new version needs a higher number.

Building on your PC with the same key: create `android/keystore.properties` with `storeFile=`, `storePassword=`, `keyAlias=`, `keyPassword=`.

## Tests

```
ruby test/run_tests.rb             (Rejuvenation-shaped)
ruby test/run_reborn_tests.rb      (Reborn/Desolation-shaped)
ruby test/run_essentials_tests.rb  (Essentials v21 / Infinite Fusion-shaped)
ruby test/run_tectonic_tests.rb    (Pokémon Tectonic-shaped)
```

The mock games are built from Rejuvenation 13.5's scripts, a Reborn-shaped variant, an Essentials v21 mock and a Tectonic mock. Every hook fails on its own and is logged in `<game>/PokeRPGLink/log.txt`, so a mismatch with a game turns off one feature rather than breaking the game.

## Project layout

```
mod/PokeRPGLink.rb     the in-game mod (Ruby)
ui/                    the bottom-screen interface (HTML/CSS/JS); open ui/index.html#battle in a browser to preview
ui/skins/              built-in skins (and examples for making your own — see SKINS.md)
android/               the Android app (Java, no dependencies)
test/                  mock games + tests
docs/images/           README pictures
.github/workflows/     builds the APK (every push) and signed releases (tags v*)
```

**How the mod is organised:** a shared core (file bridge, commands, virtual buttons, battle-menu driving) plus adapters — Rebornverse (the default), Essentials (`PokeRPGLink::EssMethods`, switched on when the game has `GameData::Species`) and Tectonic (`PokeRPGLink::TectMethods`). A new engine family means a new adapter module that fills in the same state; the UI and app don't change.
