# 마인크래프트 월드 폴더 찾기

제작: **스티브코딩**

자바에디션, 베드락에디션, 교육용에디션(Minecraft Education)의 **월드 폴더**를 자동으로 찾아서 목록으로 보여주고, 클릭 한 번으로 탐색기에서 열어주는 Windows용 프로그램입니다.

## 사용법

1. [릴리즈 페이지](https://github.com/ssakspirit/locateMinecraft/releases/latest)에서 `LocateMinecraft.bat` 파일 하나만 내려받습니다.
2. `LocateMinecraft.bat`을 더블클릭합니다. (압축 해제·설치 필요 없음)
3. 창이 뜨면
   - 위쪽 버튼: 에디션별 월드 폴더(`saves`, `minecraftWorlds`)를 엽니다.
   - 목록: 월드 썸네일, 월드 이름, 마지막 수정 시간, 경로가 나옵니다. **더블클릭**하면 해당 월드 폴더가 열립니다.
   - `경로 복사`: 선택한 월드의 경로를 클립보드에 복사합니다.

Windows에 기본으로 들어 있는 PowerShell만 사용합니다. `.bat` 파일 하나 안에 실행부와 PowerShell 코드가 함께 들어 있습니다.

## 찾는 위치

| 화면 표시 | 경로 |
|---|---|
| 자바에디션 | `%APPDATA%\.minecraft\saves` |
| 자바 (프로필 이름) | 런처 프로필에서 게임 폴더를 따로 지정한 경우 그 폴더의 `saves` |
| 베드락 (현재) | `%APPDATA%\Minecraft Bedrock\Users\<계정>\games\com.mojang\minecraftWorlds` |
| 베드락 (이전 버전) | `%LOCALAPPDATA%\Packages\Microsoft.MinecraftUWP_8wekyb3d8bbwe\LocalState\games\com.mojang\minecraftWorlds` |
| 교육용 (스토어판) | `%LOCALAPPDATA%\Packages\Microsoft.MinecraftEducationEdition_8wekyb3d8bbwe\LocalState\games\com.mojang\minecraftWorlds` |
| 교육용 (설치판) | `%APPDATA%\Minecraft Education Edition\games\com.mojang\minecraftWorlds` |

- 프리뷰 버전 폴더도 함께 찾습니다.
- 썸네일은 월드 폴더 안의 `world_icon.jpeg`(베드락/교육용)나 `icon.png`(자바)를 보여줍니다. 없으면 회색 칸으로 표시됩니다.
- 베드락/교육용 월드 폴더는 이름이 무작위 문자열이라, 각 폴더 안의 `levelname.txt`에서 실제 월드 이름을 읽어 표시합니다.
- **베드락 (이전 버전)**: 베드락은 2025년 말 업데이트로 저장 위치가 바뀌었고, 예전 폴더가 남아 있는 경우가 많습니다. "현재" 폴더가 있으면 예전 폴더는 기본으로 숨기며, 아래쪽 `이전 버전 폴더도 보기`를 체크하면 함께 보입니다.
- **베드락 (공유)**: `Users\Shared` 폴더는 특정 계정이 아니라 PC의 모든 계정이 같이 쓰는 폴더입니다(주로 리소스팩/행동팩용). 안에 월드가 있을 때만 표시합니다.
- 한 PC에서 여러 계정으로 플레이했다면 `베드락 (현재) - 계정 …1234`처럼 계정별로 구분해 표시합니다.

## 콘솔에서 목록만 보기

```bat
LocateMinecraft.bat -List
```
