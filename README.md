# 📝 Notepad

Hey there! 👋 Welcome to **Notepad**, a polished, buttery-smooth, and local-first Flutter notes app built around fast writing, structured organization, and reliable data handling.

Notepad combines a clean, distraction-free editor experience with practical everyday features. Whether you are typing away, using voice-assisted commands, or syncing your encrypted notes to Google Drive, the app is designed to feel fast, completely dependable, and tailored to your workflow.

<p align="center">
  <img src="https://github.com/user-attachments/assets/ae38b96d-c7fc-4483-9815-17682fd8081e" width="250" alt="Editor Screen" style="margin: 10px;" />
  <img src="https://github.com/user-attachments/assets/edcaacdc-6a28-4dac-bdbf-854de70830cd" width="250" alt="Home Screen" style="margin: 10px;" />
  <img src="https://github.com/user-attachments/assets/7fc3c20a-3746-4ec7-b7f0-244898dba152" width="250" alt="Search screen" style="margin: 10px;" />
</p>

---

## ✨ Features

* **Rich-Text Editing:** Create notes with headers, bold styling, hyperlinks, and interactive bullet lists.
* **Dynamic Full-Text Search:** Instantly locate precise keywords across your entire library with real-time text highlighting inside note previews.
* **Safe Soft-Deletion:** Accidental deletes drop safely into a dedicated Recycle Bin for single-tap restorations or permanent wipes.
* **Google Drive Integration:** Authenticate securely via OAuth 2.0 to push secure database backups directly to your cloud tier on-demand.
* **Groq LLM Voice Engine:** Dictate commands like *"Underline the second paragraph"* or *"Make this line green"* to trigger real-time AI document transformations.

---

## 🛠️ Tech Stack & Architecture

Click the sections below to see the architectural details of how these systems are integrated:

<details>
<summary><b>🤖 AI Core Pipeline (Speech-to-Text-to-LLM)</b></summary>

- `speech_to_text`: Local microphone hardware stream processing for automated voice transcription.
- `Groq LLM API Integration`: Cloud-hosted LLM orchestration. Maps localized semantic voice commands into structured document state mutations via secure REST API endpoints.
- `flutter_tts`: Real-time synthesized auditory speech responses leveraging forced target high-quality hardware voices.
</details>

<details>
<summary><b>💾 Data Architecture (Hybrid Local Storage Engine)</b></summary>

- `sqflite` & `sqlite3_flutter_libs`: Relational storage engine powering a **Hybrid Search Pipeline**. 
  - *Stage 1:* Virtual FTS (Full-Text Search) tables perform high-speed keyword pruning to return a candidate ID set.
  - *Stage 2:* In-memory Dart collection filtering (via `note_search_service.dart`) applies complex business logic constraints like date-range boundaries and active/deleted visibility states.
- `hive` & `hive_flutter`: Low-latency NoSQL key-value cache layer managing live operational document trees.
</details>

<details>
<summary><b>🔒 Security & Ecosystem Bridges</b></summary>

- `flutter_secure_storage`: Hardware-isolated keychain encryption for storage of persistent cloud auth tokens.
- `google_sign_in` & `googleapis`: OAuth 2.0 workflow handling for secure Google Drive binary state synchronization.
- `flutter_quill`: Advanced text mutation management using incremental delta arrays.
- `share_plus` & `url_launcher`: Native system tray share sheets and protocol intent handlers.
</details>

---

## 🚀 Local Setup

<details>
<summary><b>Show Installation Commands</b></summary>

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Version 3.0+)
- Dart SDK
- A configured `.env` file containing your required Google API keys (for Drive Sync and Voice AI features).

### Installation & Run

1. Clone the repo and install the packages:
```bash
flutter pub get
```

2. Spin up the code-generation engine for your local TypeAdapters:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

3. Run the app:
```bash
flutter run
```

*(Want to run it on a specific platform? Use `flutter run -d windows` or `flutter run -d android`)*