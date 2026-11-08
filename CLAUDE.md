# 말뭉치 (Malmungchi)

녹음 기반 세컨드 브레인 iOS 앱. 하루의 녹음(직접 녹음, 통화 녹음, 음성 메모)을 기기 안에서 받아쓰고, LLM이 일기·할 일·결정 사항·사람/프로젝트 위키로 정리한다. 자세한 소개와 구조는 README.md 참고.

## 빌드·테스트

```bash
xcodegen generate   # project.yml을 고치거나 파일을 추가·삭제한 뒤 반드시 실행
xcodebuild test -project Malmungchi.xcodeproj -scheme Malmungchi \
  -destination "platform=iOS Simulator,name=<설치된 iPhone 시뮬레이터>" CODE_SIGNING_ALLOWED=NO
```

- 시뮬레이터 이름은 `xcrun simctl list devices available`로 확인해 설치된 iPhone으로 바꿔 쓴다.
- `Malmungchi.xcodeproj`는 생성물이다. 직접 고치지 말고 `project.yml`을 고친다.
- 작업을 끝내기 전에 빌드와 테스트가 통과하는지 확인한다.

## 아키텍처 원칙

- Domain / Data / Presentation 3계층. Domain은 다른 계층과 Apple 프레임워크(AVFoundation, WhisperKit 등)를 모른다.
- 외부 의존성은 Domain의 프로토콜(`RecordingRepository`, `AudioStorage`, `AudioRecording`, `AudioPlaying`, `Transcribing` 등)로 감싸고 Data 계층에서 구현한다.
- 구체 타입은 `AppContainer`(Composition Root)에서만 조립한다. 생성자 주입 DI를 쓴다.
- ViewModel은 `@MainActor @Observable`. View에는 로직을 두지 않는다.
- 테스트는 Swift Testing(`import Testing`)으로 쓰고, 의존성은 `MalmungchiTests/Fakes.swift`의 Fake로 바꾼다. Mock 대신 Fake를 쓴다.
- 새 UseCase·ViewModel 동작을 추가하면 테스트도 같이 추가한다.

## 원칙

- 오디오와 받아쓰기 원문은 기기 밖으로 보내지 않는다. LLM에는 요약에 필요한 텍스트만 보낸다.
- 본인이 참여한 대화만 녹음하는 앱이다. 남의 대화를 몰래 녹음하는 기능은 만들지 않는다.
- 사용자에게 보이는 문구는 한국어, 짧고 친근한 존댓말("~해요")로 쓴다.

## 로드맵

- [x] 1주: 녹음·가져오기, 온디바이스 받아쓰기(WhisperKit), 저장, 재생, 테스트, CI
- [ ] 2주: LLM 정리 → 하루 일기·할 일·결정 사항, iOS 미리알림 연동, 공유 시트 확장
- [ ] 3주: 사람·프로젝트 위키 자동 갱신(LLM 위키), 기록 검색·질문(RAG)
- [ ] 4주: MCP 서버, 데모 영상

## 커밋 규칙

[Conventional Commits](https://www.conventionalcommits.org/) 형식을 따르고, 메시지는 영어로 쓴다.

```
<type>(<scope>): <summary>

<body: 무엇을, 왜 바꿨는지 (선택)>
```

- **summary:** 명령형 현재 시제, 소문자로 시작, 마침표 없음, 50자 안팎. 예: `add playback controls`
- **scope (선택):** `recording`, `transcription`, `playback`, `storage`, `ui`, `ci` 등 바뀐 영역
- **type:**

| type | 쓰는 경우 |
|---|---|
| `feat` | 새 기능 |
| `fix` | 버그 수정 |
| `refactor` | 동작 변화 없는 구조 변경 |
| `test` | 테스트 추가·수정 |
| `docs` | README, CLAUDE.md 등 문서 |
| `style` | 포맷, 공백 등 코드 의미와 무관한 변경 |
| `perf` | 성능 개선 |
| `build` | project.yml, 패키지 의존성 |
| `ci` | GitHub Actions |
| `chore` | 그 밖의 잡일 (.gitignore 등) |

- 한 커밋에는 한 가지 목적만 담는다. 기능과 리팩터링을 섞지 않는다.
- 호환이 깨지는 변경은 type 뒤에 `!`를 붙이고 body에 `BREAKING CHANGE:`를 적는다.

예시:

```
feat(playback): seek to a transcript segment when tapped
fix(storage): back up corrupted recordings.json instead of crashing
test(transcription): cover failed status transition
build: bump WhisperKit to 1.2.0
```
