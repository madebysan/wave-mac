<p align="center">
  <img src="assets/app-icon.png" width="128" height="128" alt="Wave app icon">
</p>
<h1 align="center">Wave</h1>
<p align="center">Local voice-to-text for your Mac.<br>
Press a shortcut, speak, and the transcribed text appears wherever your cursor is – no cloud, no API keys, no subscriptions.</p>
<p align="center"><strong>Version 0.4.0</strong> · macOS 14+ · Apple Silicon & Intel</p>
<p align="center"><a href="https://github.com/madebysan/wave-mac/releases/latest"><strong>Download Wave</strong></a></p>
<p align="center">Also available for <a href="https://github.com/madebysan/wave-ios"><strong>iOS</strong></a></p>

## How it works

1. Press **Option+Space** (or your custom shortcut)
2. Speak – a floating preview shows your words in real time
3. Press the shortcut again (or click the menu bar icon) to stop
4. Your words are transcribed locally and pasted into the active app

Everything runs on-device using [WhisperKit](https://github.com/argmaxinc/WhisperKit) – no audio leaves your Mac.

## Features

- **Real-time preview** – A floating HUD shows confirmed and tentative text as you speak
- **Local transcription** – Powered by OpenAI's Whisper model running on Apple Neural Engine via WhisperKit
- **Works in any app** – Text is pasted wherever your cursor is (TextEdit, Notes, Slack, browser, etc.)
- **Push-to-talk mode** – Hold the shortcut to record, release to transcribe (configurable alongside toggle mode)
- **Language auto-detection** – Let Whisper identify the spoken language, or choose from 99 supported languages
- **Smart filler removal** – Strips "um", "uh", stutters, and context-aware fillers like "basically" and "sort of" without breaking real words
- **Audio file import** – Transcribe existing audio files (MP3, WAV, AIFF, OGG, FLAC) via the menu bar
- **Auto-punctuation** – Whisper adds punctuation naturally
- **Transcription history** – Review, search, and export past transcriptions
- **Configurable shortcut** – Change the hotkey in Settings
- **Model selection** – Choose between base, small, medium, or large Whisper models
- **Launch at login** – Optional, runs quietly in the menu bar
- **Sound feedback** – Audio cues when recording starts and stops
- **Silence auto-stop** – Configurable timeout (30s to 10 min, or never)
- **Auto-mute playback** – System audio is silenced while recording so YouTube, music, etc. don't interfere
- **Trailing word capture** – A 1-second buffer after you stop ensures your last words aren't clipped

## Install

1. Download `Wave.dmg` from the [latest release](https://github.com/madebysan/wave-mac/releases/latest)
2. Open the DMG and drag **Wave** to Applications
3. Launch from Applications
4. Grant **Microphone** and **Accessibility** permissions when prompted
5. The Whisper model (~460MB) downloads automatically on first launch

## Permissions

| Permission | Why |
|-----------|-----|
| Microphone | Records your voice for transcription |
| Accessibility | Pastes transcribed text into the active app via simulated Cmd+V |

## Tech stack

- Swift + AppKit (native macOS menu bar app)
- [WhisperKit](https://github.com/argmaxinc/WhisperKit) – Core ML-optimized Whisper inference
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) – Global hotkey management
- No sandbox (required for Accessibility API + global hotkeys)

## Feedback

Found a bug or have a feature idea? [Open an issue](https://github.com/madebysan/wave-mac/issues).

## License

[MIT](LICENSE)

---

Made by [santiagoalonso.com](https://santiagoalonso.com)
