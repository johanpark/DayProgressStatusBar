# 🕒 DayProgressStatusBar

**DayProgressStatusBar**는 하루의 흐름을 macOS 상단바에서 직관적으로 확인할 수 있는 작고 가벼운 유틸리티입니다.  
설정한 시간 기준으로 퍼센트(%)로 하루의 진행률을 표시하며, 대표 일정을 선택하여 표시할 수 있습니다.

![image](https://github.com/user-attachments/assets/f56c8e07-3afc-41ab-a734-76918cc6f6e5)
![image](https://github.com/user-attachments/assets/d0d2b11c-2879-4f00-862f-9fb83b5b0fc7)


---

## ✨ 주요 기능 (Features)

- ✅ 하루 전체 또는 사용자가 설정한 시간대 기준 진행률 표시  
- 🌍 **다국어 지원**: 🇰🇷 한국어, 🇯🇵 일본어, 🇨🇳 중국어, 🇩🇪 독일어, 🇺🇸 영어  
- 🔄 상단바 % 옆에 **일정명 표시 여부 설정 가능**
- 🎯 대표 일정 설정 기능
- 💾 일정 로컬 저장 (UserDefaults 기반)
- 🍎 Swift + AppKit 기반 macOS 네이티브 앱
- ⚠️ 색상 선택 기능은 현재 미작동 (디폴트 `systemBlue` 고정)

---

## 📦 설치 방법 (Installation)

1. [Releases](https://github.com/yourname/DayProgressStatusBar/releases) 탭에서 `.dmg` 또는 `.zip` 다운로드
2. 앱을 `/Applications` 폴더에 이동
3. 보안 경고 발생 시 아래 명령어 실행 (한 번만):

```bash
sudo xattr -r -d com.apple.quarantine /Applications/DayProgressStatusBar.app
```

---

## 🛠 설정 화면
- 언어 선택
- 대표 일정 선택
- 일정명 표시 여부 선택
- 일정 추가/수정/삭제

---

## ⚠️ 참고사항 (Disclaimer)
- 이 앱은 Apple의 공증(Notarization) 을 받지 않았습니다.
- 개인 용도로 제작된 앱이며, 사용 중 발생할 수 있는 문제에 대해서는 책임지지 않습니다.
- 개선 요청이나 피드백은 GitHub Issue로 남겨주세요. 시간 되는 대로 반영하겠습니다.
