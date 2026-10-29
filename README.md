# SRM 모듈 패키징

> 하나의 org에 묶여 있던 구매 관리(SRM) 솔루션을 Salesforce 2GP 패키지 16개로 나눠, 고객이 필요한 모듈만 골라 설치할 수 있는 제품으로 만들었습니다.

| 항목 | 내용 |
|---|---|
| 기간 | 2026.09 – 2026.10 |
| 역할 | 패키지 구조 설계, 의존성 분리, 빌드 · 배포 스크립트, 설치 검증, 문서화 |
| 형태 | 회사 프로젝트 (사내 솔루션 팀) |
| 기술 | Salesforce 2GP (Managed · Unlocked), Apex, LWC, Custom Metadata, Platform Event, PowerShell, Salesforce CLI |

> 회사 프로젝트를 정리한 문서입니다. 회사 소스 코드와 고객 정보는 포함하지 않습니다.

## 배경

- 구매요청부터 세금계산서까지 모든 기능이 한 org에 섞여 있어서, 고객마다 필요 없는 모듈까지 함께 설치해야 했습니다.
- 모듈끼리 서로의 클래스와 화면을 직접 참조하고 있어 하나만 떼어 낼 수 없었습니다.

## 결과

- **Managed 패키지 7개** (조달구매, 포털, 리스크 · 지출, BOM, AI 회의록, AI 에이전트, 소싱)
- **Unlocked 연결 패키지 9개** (평가, PDF, 계약, 공급망, 포털 연동 등)
- 설치 조합 9가지와 역할별 권한, 구매요청 → 세금계산서 전체 업무 흐름을 설치 org에서 검증
- 테스트 커버리지: BOM 57.7% → 85.3%, 리스크 모듈 테스트 321개 통과 (90%)

## 구조

```mermaid
flowchart TB
    subgraph Core["Core (조달구매)"]
        SLOT[확장 슬롯 LWC<br/>레코드 페이지 · 액션 · 유틸리티 바]
        CMDT[(확장 등록<br/>Custom Metadata)]
        API[모듈용 공개 Apex<br/>NamespaceAccessible]
    end
    subgraph Modules["모듈 패키지"]
        RISK[리스크 · 지출]
        BOM[BOM]
        AGENT[AI 에이전트]
        PORTAL[포털]
    end
    RISK -- 등록 --> CMDT
    BOM -- 등록 --> CMDT
    AGENT -- 등록 --> CMDT
    CMDT --> SLOT
    PORTAL -- 위임 호출 --> API
    BOM -. describe · 동적 SOQL .-> Core
```

## 풀어낸 문제

### 1. Core가 모듈을 모르게 만들기 (확장 슬롯)
- Core 화면에 모듈 화면을 직접 넣는 대신, **Custom Metadata에 등록된 컴포넌트를 실행 시점에 끼워 넣는 슬롯 LWC**를 만들었습니다.
- 레코드 페이지 탭, 액션 버튼, 유틸리티 바 세 위치를 지원하고, 앱 빌더에서 표시할 항목을 고를 수 있게 했습니다.
- 설치되지 않은 모듈의 등록은 오류 없이 건너뜁니다. 모듈을 빼도 Core 화면이 깨지지 않습니다.

### 2. 순환 참조 끊기
- 모듈이 Core의 필드를 컴파일 시점에 참조하면 단독 설치가 불가능해집니다.
- **describe와 동적 SOQL**로 필드를 실행 시점에 확인하도록 바꿨고, 포털은 Core를 `@NamespaceAccessible` 위임 클래스를 통해서만 호출하게 했습니다.
- `@NamespaceAccessible`은 `@AuraEnabled` 메서드에 쓸 수 없다는 제약 때문에, 화면용 컨트롤러와 공개 API를 분리했습니다.

### 3. 패키지 위에 고객 소스 배포
- 설치된 패키지 위에 고객별 소스를 배포할 때 네임스페이스 접두어가 맞지 않는 문제가 있었습니다.
- 배포 전에 참조를 네임스페이스 형식으로 바꿔 주는 **PowerShell 배포 스크립트**와, LWC 참조 누락을 미리 찾는 사전 점검 스크립트를 만들었습니다.

### 4. 권한과 공유
- 검수 담당자에게 레코드를 공유하는 Apex 공유 배치를 만들고, 포털 사용자가 만든 요청은 **Platform Event**로 넘겨 권한 있는 컨텍스트에서 공유를 생성했습니다.
- 조직마다 다른 공유 설정은 패키지 밖 설치 후 소스로 분리했습니다.

### 5. 전자계약 연동
- 발주가 확정되면 계약을 자동 생성하고, 최종 서명 시점에 단가를 만들면서 기간이 겹치는 기존 단가는 종료합니다.

## 예제 코드

Core 가 모듈을 모르게 만드는 **확장 슬롯 구조를 독립적으로 다시 구현한 예제**입니다. 회사 코드가 아니며, 표준 Account 페이지에 예제 모듈 두 개가 탭으로 붙습니다.

| 파일 | 역할 |
|---|---|
| [`Page_Extension__mdt`](force-app/main/default/objects/Page_Extension__mdt) | 등록 정보: 오브젝트, 자리(slot), 컴포넌트, 순서, 속성 JSON, 활성 여부 |
| [`PageExtensionController.cls`](force-app/main/default/classes/PageExtensionController.cls) | 오브젝트 · 자리에 맞는 활성 등록을 순서대로 반환. 네임스페이스 유무를 모두 처리하고, 패키지가 등록한 컴포넌트는 그 패키지 네임스페이스로 모듈 경로를 만든다 |
| [`extensionSlot`](force-app/main/default/lwc/extensionSlot) | 등록된 컴포넌트를 **동적 import** 로 불러와 탭 또는 세로 배치로 그림. 설치되지 않은 컴포넌트는 건너뜀 |
| [`contactListExtension`](force-app/main/default/lwc/contactListExtension) · [`noteExtension`](force-app/main/default/lwc/noteExtension) | 예제 모듈. 슬롯이 `recordId` 와 등록 속성을 넘겨준다 |
| [`customMetadata`](force-app/main/default/customMetadata) | 예제 등록 두 건 (Account / Tabs) |

새 모듈을 붙일 때 Core 코드는 바꾸지 않습니다. 모듈 패키지가 컴포넌트와 `Page_Extension__mdt` 레코드 하나만 함께 배포하면 됩니다.

### 직접 실행

```bash
sf org create scratch -f config/project-scratch-def.json -a slot-demo
sf project deploy start -o slot-demo -d force-app --test-level RunLocalTests
```

배포 후 Account 레코드 페이지에 `Extension Slot` 컴포넌트를 놓으면 Contacts · Notes 탭이 나타납니다.
스크래치 org 에서 테스트 6개 통과, 커버리지 94% (2026-10-30 확인).

## 배운 점

- 패키지 경계는 기능이 아니라 **의존 방향**으로 나눠야 오래 버틴다는 것
- 설치 org에서 직접 시험하지 않으면 보이지 않는 문제(네임스페이스, 권한, 언어 설정에 따른 테스트 실패)가 많다는 것
