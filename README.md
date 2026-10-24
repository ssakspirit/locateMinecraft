# 마인크래프트 월드 폴더 찾기

자바에디션, 베드락에디션, 교육용에디션(Minecraft Education)의 **월드 폴더**를 자동으로 찾아서 목록으로 보여주고, 클릭 한 번으로 탐색기에서 열어주는 Windows용 프로그램입니다.

## 사용법

1. `LocateMinecraft.bat`과 `LocateMinecraft.ps1`을 같은 폴더에 둡니다.
2. `LocateMinecraft.bat`을 더블클릭합니다.
3. 창이 뜨면
   - 위쪽 버튼: 에디션별 월드 폴더(`saves`, `minecraftWorlds`)를 엽니다.
   - 목록: 월드 이름, 마지막 수정 시간, 경로가 나옵니다. **더블클릭**하면 해당 월드 폴더가 열립니다.
   - `경로 복사`: 선택한 월드의 경로를 클립보드에 복사합니다.

설치는 필요 없고, Windows에 기본으로 들어 있는 PowerShell만 사용합니다.

## 찾는 위치

| 에디션 | 경로 |
|---|---|
| 자바에디션 | `%APPDATA%\.minecraft\saves` (런처 설정의 사용자 지정 게임 폴더도 확인) |
| 베드락 (최신 버전) | `%APPDATA%\Minecraft Bedrock\Users\<계정>\games\com.mojang\minecraftWorlds` |
| 베드락 (이전 Store 버전) | `%LOCALAPPDATA%\Packages\Microsoft.MinecraftUWP_8wekyb3d8bbwe\LocalState\games\com.mojang\minecraftWorlds` |
| 교육용 (Store 버전) | `%LOCALAPPDATA%\Packages\Microsoft.MinecraftEducationEdition_8wekyb3d8bbwe\LocalState\games\com.mojang\minecraftWorlds` |
| 교육용 (설치 프로그램 버전) | `%APPDATA%\Minecraft Education Edition\games\com.mojang\minecraftWorlds` |

프리뷰 버전 폴더도 함께 찾습니다. 베드락/교육용 월드 폴더는 이름이 무작위 문자열이라, 각 폴더 안의 `levelname.txt`에서 실제 월드 이름을 읽어 표시합니다.

## 콘솔에서 목록만 보기

```powershell
powershell -ExecutionPolicy Bypass -File .\LocateMinecraft.ps1 -List
```
