<p align="right">
🇰🇷 <a href="./README.ko.md">한국어</a> | 🇺🇸 <a href="./README.md">English</a>
</p>

# 🕒 DayProgressStatusBar

**DayProgressStatusBar** is a lightweight macOS utility that displays your day's progress directly in the menu bar.  
It shows the percentage of time passed based on either the full day or your custom schedule, and lets you choose a representative schedule to display.

![image](https://github.com/user-attachments/assets/f56c8e07-3afc-41ab-a734-76918cc6f6e5)  
![image](https://github.com/user-attachments/assets/7b084e99-42b2-4744-be6f-5be24701e839)

---

## ✨ Features

- ✅ Display progress based on the full day or a user-defined time range  
- 🌍 **Multilingual Support**: 🇰🇷 Korean, 🇯🇵 Japanese, 🇨🇳 Chinese, 🇩🇪 German, 🇺🇸 English  
- 🔄 Option to show or hide schedule name next to the percentage
- 🎯 Set a representative schedule for display
- 💾 Local data storage using UserDefaults
- 🍎 Built with Swift + AppKit for a native macOS experience
- ⚠️ Color picker is currently not functional (defaults to `systemBlue`)

---

## 📦 Installation

1. Download the `.dmg` or `.zip` file from the [Releases](https://github.com/yourname/DayProgressStatusBar/releases) tab
2. Move the app into your `/Applications` folder
3. If macOS blocks the app, run the following command (once only):

```bash
sudo xattr -r -d com.apple.quarantine /Applications/DayProgressStatusBar.app
```

---

## 🛠 Settings
-	Language selection
-	Representative schedule selection
-	Toggle schedule name display
-	Add/edit/delete schedules

---

## ⚠️ Disclaimer
- This app is not notarized by Apple.
- It was created for personal use. The developer does not take responsibility for any issues caused by usage.
- Feel free to open an issue for bugs or suggestions. Improvements will be made as time allows.
