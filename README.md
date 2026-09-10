# 📝 Notepad

**Notepad** is a sophisticated, local-first workspace engineered to dissolve the friction between thought and digital record. Blending high-performance SQLite FTS power with advanced Groq AI integration, it transforms a minimalist interface into a secure, intelligent thinking partner. Every interaction is tuned for near-instant responsiveness, ensuring your focus remains entirely on your ideas.

<div align="center">
   <picture>
     <source media="(prefers-color-scheme: dark)" srcset="web/screenshots/Home/Home_Page_1.webp">
     <source media="(prefers-color-scheme: light)" srcset="web/screenshots/Readme/Home.webp">
     <img src="web/screenshots/Readme/Home.webp" width="340" alt="Home Screen"/>
   </picture>
   <picture>
     <source media="(prefers-color-scheme: dark)" srcset="web/screenshots/Note/Note_Page_2.webp">
     <source media="(prefers-color-scheme: light)" srcset="web/screenshots/Readme/Editor.webp">
     <img src="web/screenshots/Readme/Editor.webp" width="339" alt="Note Editor"/>
   </picture>
   <picture>
     <source media="(prefers-color-scheme: dark)" srcset="web/screenshots/Search/Search_Page_1.webp">
     <source media="(prefers-color-scheme: light)" srcset="web/screenshots/Readme/Search.webp">
     <img src="web/screenshots/Readme/Search.webp" width="342" alt="Search Page"/>
   </picture>
   <picture>
     <source media="(prefers-color-scheme: dark)" srcset="web/screenshots/Trash/Trash_Page_1.webp">
     <source media="(prefers-color-scheme: light)" srcset="web/screenshots/Readme/Trash.webp">
     <img src="web/screenshots/Readme/Trash.webp" width="338" alt="Recycle Bin"/>
   </picture>
</div>

---

## 📥 Download

[📱 Download Latest APK](https://github.com/SayanMz/notepad-app/releases/download/2.5.0/app-release-2.5.apk)

---

## 🚀 Core Pillars

### 🧠 Intelligence & Search
* **Smart AI Assistant:** Execute hands-free commands and dictate thoughts via high-speed Groq AI integration. Transform documents in real-time with natural commands like *"Make the first line green"* or *"Underline all instances of 'Notepad'"*.
* **Lightning-Fast Search:** Locate precise keywords instantly with local SQLite FTS and smart fuzzy search. Catches typos effortlessly, with real-time text highlighting and smart date-range filtering.
* **Intelligent Auto-Save:** Every stroke is captured in real-time with zero latency, backed by visual save-status indicators.
* **Smart Topic Discovery:** Automatically organizes and tags your notes by topic using an on-device AI model. Finds related ideas instantly without any of your personal notes ever leaving your phone.

### 🔒 Uncompromising Privacy & Safety
* **Privacy-First Design:** Your data is your business. Every note is secured on-device using local, high-security hardware-backed encryption (AES-256).
* **Secure Cloud Backup:** Never lose a moment of inspiration. Authenticate safely to sync your notes directly to your personal, private Google Drive storage on-demand.
* **Managed Recycle Bin:** A robust safety net to recover accidental deletions or perform permanent data purging from a dedicated bin.

### ✨ Editor & Workspace
* **Professional Editor:** A highly responsive rich-text engine supporting headers, styles, hyperlinks, interactive bullet lists, and smart link overlays for instant calling, emailing, or adding calendar events.
* **Smart Organization:** Power-user multi-select tools for batch pinning, sharing, or deleting, plus a bespoke draggable color picker interface for workspace personalization.
* **Modern Design System:** AMOLED-optimized dark mode, adaptive grid layouts for tablets, and silky-smooth cross-fade transitions powered by a central Design Token engine.

---

## 🏗️ Engineering & Tech Stack

Notepad is built on a **Feature-First** architecture with a strict **Controller-Service-Repository** pattern, ensuring the app is highly optimized, testable, and production-ready.

- **Decoupled Logic**: Separation into distinct layers (UI → Controller → Service → Repository) for maximum modularity.
- **Robust Test Coverage**: Supported by a comprehensive suite of **250+ automated tests** utilizing Dependency Injection to ensure 100% logic reliability.
- **Polyglot Data Layer**: High-speed **Hive (NoSQL)** for live document state, in-memory **SQLite FTS5** for zero-latency text indexing, and dedicated persistent on-device **Vector Storage** for semantic embeddings.
- **Data Integrity**: Uses **ULID-based identifiers** for consistent lexicographical ordering and reliable local-to-cloud synchronization.
- **Semantic Theming**: Unified `Tokens` engine and `context_extensions` for instant, type-safe UI consistency across the entire app.

<details>
<summary><b>View Detailed Package Breakdown</b></summary>

- **AI & ML**: `onnxruntime`, `bert_tokenizer`, `Groq Cloud API`, `speech_to_text`, `flutter_tts`
- **Data**: `sqflite` (FTS Engine), `hive_flutter`, `ulid`
- **Security & Sync**: `flutter_secure_storage`, `googleapis` (Drive Sync), `google_sign_in`
- **UI & Export**: `flutter_quill`, `pdf`, `printing`, `flutter_colorpicker`, `lottie`, `share_plus`
</details>

---

### 🎬 Application Walkthroughs

[📝 Note Editor](https://github.com/SayanMz/notepad-app/releases/download/2.3.0/Note_Editor_demo.mp4) &nbsp;|&nbsp; [🤖 Groq AI Assistant](https://github.com/SayanMz/notepad-app/releases/download/2.3.0/Groq_Ai_demo.mp4) &nbsp;|&nbsp; [🏠 Home Screen](https://github.com/SayanMz/notepad-app/releases/download/2.3.0/Home_Page.mp4) &nbsp;|&nbsp; [🔍 Search Filter](https://github.com/SayanMz/notepad-app/releases/download/2.3.0/Search_Page.mp4) &nbsp;|&nbsp; [🗑️ Recycle Bin](https://github.com/SayanMz/notepad-app/releases/download/2.3.0/Recycle_Page.mp4)

---

## 🚀 Local Setup

<details>
<summary><b>Show Installation Commands</b></summary>

<br/>

**Prerequisites**
- **Flutter SDK**: ^3.44.8 (Latest Stable)
- **Dart SDK**: ^3.12.2
- A configured `.env` file at root (refer to [.env.example](.env.example)).

**Installation**
1. `flutter pub get`
2. `dart run build_runner build --delete-conflicting-outputs` (Generates Hive adapters)
3. `flutter create --platforms=ios,macos,web,linux,windows .` (Optional: add platform runners if missing)
4. `flutter run`

</details>

---

## 📜 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

## 👤 Author

Developed with ❤️ by **Sayan Mazumder**