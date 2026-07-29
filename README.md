# macOS AI Developer Bootstrap

새 macOS를 AI 개발용 워크스테이션으로 구성하는 멱등적 설치 도구입니다.
Apple Silicon과 Intel, macOS 14 이상을 지원합니다.

```bash
./bootstrap --dry-run
./bootstrap
./bootstrap auth
./bootstrap doctor
```

전체 설명과 운영 방법은 [한국어 매뉴얼](docs/한국어-매뉴얼.md)을
참조하세요.

## 주요 원칙

- 패키지는 가능한 한 Homebrew `Brewfile`로 설치합니다.
- 기존 dotfile과 클라이언트 설정의 관리 대상 외 항목은 보존합니다.
- 토큰과 로그인 정보는 저장소에 저장하지 않습니다.
- Glances는 `uv`의 `glances[all]`로 모든 선택 통합을 포함해 설치합니다.
- Docker Desktop과 Podman 대신 Colima의 containerd/nerdctl을 사용합니다.
- Kubernetes는 요청할 때만 별도 Colima 프로필로 시작합니다.
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
| `./bootstrap doctor` | 20개 요구사항 읽기 전용 진단 |

## 테스트

```bash
scripts/test
```

테스트는 임시 HOME과 mock 명령을 사용하며 실제 사용자 환경에 패키지를
설치하지 않습니다.
