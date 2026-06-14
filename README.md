<div align="center">

<img src="docs/icon.png" width="120" alt="Glassnote"/>

# Glassnote для macOS

**Голосовые заметки с локальной расшифровкой. Нативное приложение для menu bar.**

[![Release](https://img.shields.io/github/v/release/Arti-Ko/glassnote?label=Скачать&style=for-the-badge)](https://github.com/Arti-Ko/glassnote/releases/latest)
[![Platform](https://img.shields.io/badge/macOS-14%2B-000000?style=for-the-badge&logo=apple&logoColor=white)](#)

</div>

## Что это

Glassnote живёт в строке меню. Жмёте горячую клавишу — снизу всплывает стеклянная панель записи, говорите, и заметка с расшифровкой сохраняется в библиотеку. Распознавание — **локально**, через [WhisperKit](https://github.com/argmaxinc/WhisperKit) (`large-v3-turbo`), без интернета.

## Возможности

- 🎙 **Глобальный хоткей** (⌥⇧Space) — запись из любого приложения
- 🪟 **Стеклянная панель** записи (NSVisualEffectView) с волной и таймером
- 🧠 **Локальная расшифровка** WhisperKit (ru + en, автоопределение)
- 🟢 **Индикатор в menu bar** — зелёный при записи, синий при расшифровке
- 🔔 Звуковые сигналы старта/окончания записи
- 🔎 Поиск (SQLite FTS5), правка, копирование/экспорт в Markdown
- 🔄 Проверка обновлений через GitHub Releases

## Установка

Скачайте `Glassnote-*.zip` из [последнего релиза](https://github.com/Arti-Ko/glassnote/releases/latest), распакуйте в «Программы». Сборка не подписана, поэтому при первом запуске снимите карантин:

```bash
xattr -dr com.apple.quarantine /Applications/Glassnote.app
```

## Сборка из исходников

```bash
brew install xcodegen
git clone https://github.com/Arti-Ko/glassnote
cd glassnote
xcodegen generate
open Glassnote.xcodeproj   # ⌘R
```

## Хранение заметок

```
~/Documents/Glassnote/<дата-время>/
├── audio.m4a
├── note.json
└── transcript.md
```

## Технологии

SwiftUI · WhisperKit (CoreML) · AVFoundation · KeyboardShortcuts · SQLite FTS5 · NSPanel

## Лицензии

Код — MIT. WhisperKit — MIT.

---

📱 Версия для Android: [Arti-Ko/glassnote-android](https://github.com/Arti-Ko/glassnote-android)
