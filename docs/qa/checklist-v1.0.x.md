# Pistisai QA Checklist — v1.0.x

## Before you start
- Kill any old `Pistisai.exe` processes (Task Manager)
- Build: `flutter build windows --release`
- Launch: `build/windows/x64/runner/Release/Pistisai.exe`
- Keep the console window visible for log checking

---

## 1. 🚀 First Launch

| # | Test | Expected | Pass/Fail |
|---|------|----------|-----------|
| 1.1 | Double-click Pistisai.exe | Window opens within 5s | |
| 1.2 | Console output | No "Window event: move" spam. Initialization messages only. | |
| 1.3 | App icon in taskbar/tray | Pistisai icon visible | |
| 1.4 | Resize window | Drag edges, maximize, restore — smooth | |

---

## 2. 🧙 Setup Wizard

| # | Test | Expected | Pass/Fail |
|---|------|----------|-----------|
| 2.1 | Wizard appears | "Welcome" step on fresh install | |
| 2.2 | Click Next | Goes to "Connection Method" step | |
| 2.3 | Select "Hermes Agent" | Auto-fills URL: `http://127.0.0.1:8642` | |
| 2.4 | API Key field | Shows green checkmark ✅ + "Auto-discovered from Hermes configuration" | |
| 2.5 | Click "Save and Continue" | Goes to Connection Test step | |
| 2.6 | Connection test | Shows "Connected" or specific error | |
| 2.7 | Click "Complete" | Wizard closes, chat screen appears | |

---

## 3. 💬 Chat

| # | Test | Expected | Pass/Fail |
|---|------|----------|-----------|
| 3.1 | Type a message and send | Message appears in chat bubble | |
| 3.2 | AI responds | Response streams in, typing indicator shows | |
| 3.3 | Send 3+ messages | All messages visible, scroll works | |
| 3.4 | Close and reopen app | Conversations persist | |
| 3.5 | Settings gear (top-right) | Opens config/settings page | |

---

## 4. 🎭 Action Bar

| # | Test | Expected | Pass/Fail |
|---|------|----------|-----------|
| 4.1 | 🎭 Avatar button | Animated avatar dialog opens (pulsing emoji) | |
| 4.2 | Avatar animation | Circle pulses, emoji changes based on state | |
| 4.3 | Close avatar dialog | Returns to chat | |
| 4.4 | 🔧 Tools button | Bottom sheet slides up with 5 capabilities | |
| 4.5 | Tools list | Shows: Desktop Control, Vision, Voice, Web Search, Code Execution | |
| 4.6 | ❤️ Mood button | Dialog with personality bars (Formality, Humor, Enthusiasm, Empathy) | |
| 4.7 | Mood shows evolution stage | Text at bottom: "Evolution: curious_explorer" | |
| 4.8 | All buttons disabled when disconnected | Buttons greyed out (opacity 0.4) | |

---

## 5. 🔧 Desktop Build

| # | Test | Expected | Pass/Fail |
|---|------|----------|-----------|
| 5.1 | Console noise | No 30-second scan loop spam | |
| 5.2 | Window move | No "Window event: move" flood in console | |
| 5.3 | Memory usage | Task Manager: stable, no leak | |

---

## Known Issues (pre-existing)
- Web E2E tests fail (pre-existing, not related)
- Backend Deploy tests fail (pre-existing, needs infra)
- Backend deploy 502 on api.pistisai.app

---

*Save this file as `docs/qa/checklist-v1.0.x.md` and update each release.*
