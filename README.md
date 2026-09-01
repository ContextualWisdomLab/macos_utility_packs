# macOS AI Developer Bootstrap

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/ContextualWisdomLab/macos_utility_packs)

새 macOS를 AI 개발용 워크스테이션으로 구성하는 멱등적 설치 도구입니다.
Apple Silicon과 Intel, macOS 14 이상을 지원합니다.
현재 프로젝트 버전은 `0.1.0`입니다.

```bash
./bootstrap --dry-run
./bootstrap
./bootstrap auth
./bootstrap doctor
./bootstrap doctor --json
```

전체 설명과 운영 방법은 [한국어 매뉴얼](docs/korean-manual.md)을
참조하세요. 공개 문서의 시작점은 [`docs/index.md`](docs/index.md)입니다.

## 주요 원칙

- 패키지는 가능한 한 Homebrew `Brewfile`로 설치합니다.
- 기존 dotfile과 클라이언트 설정의 관리 대상 외 항목은 보존합니다.
- 토큰과 로그인 정보는 저장소에 저장하지 않습니다.
- Glances는 `uv`의 `glances[all]`로 모든 선택 통합을 포함해 설치합니다.
- Docker Desktop과 Podman 대신 Colima의 containerd/nerdctl을 사용합니다.
- Kubernetes는 요청할 때만 별도 Colima 프로필로 시작합니다.
- 표준 근거와 비인증 범위는 [보안·컴플라이언스 근거](docs/standards.md)에 기록합니다.
- 설치 전 `--dry-run`, 설치 후 `doctor` 사용을 권장합니다.

## 지원 명령

| 명령 | 설명 |
| --- | --- |
| `./bootstrap` | 전체 설치와 비밀정보가 없는 설정 |
| `./bootstrap --only packages,shell` | 선택한 단계만 실행 |
| `./bootstrap --skip skills` | 선택한 단계 제외 |
| `./bootstrap skills` | skills.sh Official 및 모든 Topic 동기화 |
| `./bootstrap mcp` | MCP와 공용 에이전트 지침 동기화 |
| `./bootstrap auth` | 대화형 로그인 |
| `./bootstrap kubernetes` | 소규모 k3s 실습 프로필 시작 |
| `./bootstrap doctor` | 21개 요구사항 읽기 전용 진단 |
| `./bootstrap doctor --json` | 같은 21개 진단을 단일 JSON 객체로 stdout에 출력 |

## 자동화용 진단 JSON

CI, MDM 또는 플릿 관리 도구에서는 `./bootstrap doctor --json`을 사용합니다.
stdout에는 `generatedAt`, `checks`, `failures`를 가진 하나의 JSON 객체만 출력되며,
동일한 보고서는 `${BOOTSTRAP_STATE_DIR}/doctor.json`에도 계속 기록됩니다. 실패한
요구사항이 하나라도 있으면 JSON 증거를 먼저 출력한 뒤 명령은 비정상 종료하므로
자동화가 진단 내용을 보존하면서도 fail-closed로 동작할 수 있습니다.

`--json`은 `doctor` 명령에만 허용됩니다. 기존 운영 스크립트의 사람용 출력을
복원해야 하면 `--json`을 제거하면 되며, 설치·인증·패키지 변경 경로에는 영향을
주지 않습니다.

## 테스트

```bash
scripts/test
RUN_LIVE_TESTS=1 bash tests/live_test.sh
```

테스트는 임시 HOME과 mock 명령을 사용하며 실제 사용자 환경에 패키지를
설치하지 않습니다. Python 보조 스크립트는 표준 라이브러리 `trace`로 실행
가능 라인 100%를 검증합니다. `RUN_LIVE_TESTS=1`은 실제 Homebrew·Colima·
`nerdctl` 상태를 읽어 운영 환경 증거를 수집하며, 패키지를 설치하거나
프로파일을 삭제하지 않습니다.
