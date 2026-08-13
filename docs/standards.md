# 보안·컴플라이언스 근거

이 문서는 macOS 로컬 부트스트랩 도구의 설계·운영 근거를 기록한다.
`doctor`는 이 문서가 존재하고 핵심 표준 식별자와 APA 7 서지가 유지되는지만
읽기 전용으로 확인한다. 이 저장소는 아래 표준의 인증, 적합성 보증, SOC 2
attestation 또는 CSAP 인증을 주장하지 않는다.

## 적용 범위

| 근거 | 이 저장소에서의 적용 | 주장하지 않는 것 |
| --- | --- | --- |
| NIST SP 800-218 SSDF 1.1 | 변경 검토, 테스트, 비밀정보 미저장, 취약점 검사와 실패 시 중단 원칙 | NIST 인증 또는 완전한 SSDF 구현 |
| SLSA v1.2 | 보호된 PR, 재현 가능한 로컬 테스트 명령, 릴리스·변경 이력의 출발점 | SLSA provenance 또는 특정 level 달성 |
| SOC 2 2017 Trust Services Criteria (2022 points of focus) | 보안·가용성·처리무결성·기밀성·프라이버시 통제의 운영 증거를 분리해 기록 | SOC 2 감사보고서 또는 attestation |
| CSAP | 클라우드 서비스 제공자 경계와 인증 필요성을 식별 | 이 로컬 설치 도구 또는 사용자의 클라우드가 CSAP 인증을 받았다는 주장 |

이 프로젝트는 외부 서비스·데이터베이스를 운영하는 SaaS가 아니라 사용자
Mac에서 실행되는 설치·진단 도구다. 따라서 표준의 적용 여부는 배포 환경과
조직 통제의 소유자에게 남으며, 이 저장소의 문서 존재만으로 인증 상태가
변하지 않는다.

## 운영 증거

- `scripts/test`는 변경 후 셸 테스트, 문법 검사, ShellCheck를 실행한다.
- `doctor --json`은 패키지를 설치하거나 설정을 변경하지 않고 실패 증거를
  JSON으로 남긴다.
- 인증 토큰·API 키·OAuth 정보는 저장소와 로그에 기록하지 않는다.
- `CHANGELOG.md`, `VERSION`, 보호된 PR 흐름과 승인·체크 상태는 변경 이력의
  추적 지점이다.
- 공급망 스캔은 조직의 GitHub 필수 워크플로에 위임되며, 이 저장소는 스캔이
  통과했다고 로컬에서 대신 주장하지 않는다.

## 참고문헌 (APA 7th ed.)

American Institute of Certified Public Accountants. (2023). *2017 trust
services criteria (with revised points of focus—2022).* https://www.aicpa-cima.com/resources/download/2017-trust-services-criteria-with-revised-points-of-focus-2022

Korea Internet & Security Agency. (n.d.). *클라우드 보안인증제: 제도소개*.
Retrieved August 13, 2026, from https://isms.kisa.or.kr/main/csap/intro/index.jsp

National Institute of Standards and Technology. (2022). *Secure software
development framework (SSDF) version 1.1: Recommendations for mitigating the
risk of software vulnerabilities* (NIST Special Publication 800-218).
https://doi.org/10.6028/NIST.SP.800-218

SLSA Community. (2025). *SLSA specification version 1.2*.
https://slsa.dev/spec/v1.2/
