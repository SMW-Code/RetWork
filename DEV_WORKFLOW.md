# RetWork dev/prod 개발 가이드

> 베타 테스터는 **안정된 production**을 쓰고, 개발은 **dev 환경**에서 따로 진행하기 위한 분리 구조.
> 작성: 2026-06-07

---

## 1. 큰 그림

```
[ 개발 (나) ]                          [ 테스터 ]
   dev 브랜치                             main 브랜치
      │                                     │
      ▼                                     ▼
 Vercel 미리보기                       retwork.jp (production)
 ret-work-git-dev-…vercel.app          ret-work.vercel.app
      │                                     │
      ▼                                     ▼
   dev Supabase                         prod Supabase
 (ljxkqxjhrahzvnodqlqt)               (fkvfbxfgidrvymoftkdd)
```

- **dev에서 마음껏 개발/실험** → 미리보기로 확인 → 문제없으면 **main으로 merge** → 그때 테스터한테 반영됨
- dev DB와 prod DB는 **완전히 별개** → dev에서 데이터 막 만들어도 테스터한테 영향 없음

---

## 2. 두 환경 정보

| 구분 | DB (Supabase) | URL | 누가 씀 |
|------|---------------|-----|---------|
| **prod** | `fkvfbxfgidrvymoftkdd` | https://fkvfbxfgidrvymoftkdd.supabase.co | 테스터 (retwork.jp, ret-work.vercel.app) |
| **dev** | `ljxkqxjhrahzvnodqlqt` | https://ljxkqxjhrahzvnodqlqt.supabase.co | 개발 (미리보기, localhost 등) |

- **고정 dev 미리보기 주소** (북마크 추천, 항상 최신 dev):
  `https://ret-work-git-dev-ret-work-s-projects.vercel.app`

---

## 3. 환경 분기는 어떻게 되나 (코드)

`public/index.html` 상단 Supabase 초기화 부분이 **접속한 도메인(hostname)**을 보고 자동으로 DB를 고름:

```js
const _PROD_HOSTS = ['retwork.jp', 'www.retwork.jp', 'ret-work.vercel.app'];
const _IS_PROD_ENV = _PROD_HOSTS.indexOf(location.hostname) !== -1;
// prod 도메인 → prod DB / 그 외(dev 미리보기 등) → dev DB
```

- prod 도메인 목록에 있으면 → prod DB
- 그 외 모든 주소 → dev DB (모르는 주소는 prod 데이터 보호를 위해 dev로 폴백)
- 브라우저 콘솔(F12)에 `[ReceiptIQ] DB env: dev` / `prod` 가 찍혀서 **지금 어느 DB 쓰는지 바로 확인 가능**

> ⚠️ 새 production 도메인이 생기면 `_PROD_HOSTS` 배열에 추가해야 함.

---

## 4. 평소 개발 흐름 (제일 자주 하는 것)

```bash
# 1) dev 브랜치에서 작업 중인지 확인
git branch --show-current      # → dev 여야 함

# 2) public/index.html 등 수정...

# 3) 빌드 번호 올리기 (캐시 갱신용) — 두 곳 같이!
#    public/index.html : window.__APP_BUILD__ = 429;  → 430
#    public/sw.js      : CACHE_NAME = '...-b429';      → b430

# 4) 커밋 & 푸시 → Vercel이 dev 미리보기 자동 빌드 (~40초)
git add -A
git commit -m "작업 내용"
git push origin dev

# 5) 미리보기에서 확인
#    https://ret-work-git-dev-ret-work-s-projects.vercel.app
#    F12 콘솔에서 'DB env: dev' 확인
```

### 베타 시작 / 테스터한테 반영할 때 (dev → main)

```bash
git checkout main
git pull origin main
git merge dev
git push origin main          # → production(retwork.jp) 자동 빌드
git checkout dev              # 다시 dev로 돌아와서 계속 개발
```

---

## 5. 다른 컴퓨터에서 처음 시작할 때

```bash
# 1) 클론 (또는 이미 있으면 pull)
git clone https://github.com/SMW-Code/RetWork.git
cd RetWork

# 2) dev 브랜치로 전환
git checkout dev
git pull origin dev

# 3) 끝. 개발은 public/index.html 수정 → push 하면 됨.
#    (별도 빌드 도구 필요 없음 — 정적 PWA라 push만 하면 Vercel이 빌드)
```

> **PostgreSQL 클라이언트(psql/pg_dump)**는 *DB 스키마를 다시 복제/동기화*할 때만 필요.
> 평소 개발(코드 수정→push)엔 git + 브라우저만 있으면 됨.
> 필요하면: `winget install -e --id PostgreSQL.PostgreSQL.17`

---

## 6. DB 스키마를 prod → dev 로 다시 맞출 때 (가끔)

prod에 새 테이블/정책을 추가했고 dev에도 똑같이 넣고 싶을 때:

```powershell
# (1) prod 스키마 덤프  — <prod비번>은 prod DB 비밀번호 (본인만 앎, 문서에 안 적음)
$env:PGPASSWORD = '<prod비번>'
& "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe" --schema-only --schema=public --no-owner --no-privileges -h aws-1-ap-northeast-1.pooler.supabase.com -p 5432 -U postgres.fkvfbxfgidrvymoftkdd -d postgres -f prod_schema.sql
$env:PGPASSWORD = ''

# (2) prod_schema.sql 정리:
#     \restrict / \unrestrict 줄 삭제, "CREATE SCHEMA public;" 삭제,
#     "COMMENT ON SCHEMA public" 삭제 (이미 dev에 public 스키마 있음)

# (3) dev 에 적용  — <dev비번>은 dev DB 비밀번호
$env:PGPASSWORD = '<dev비번>'
& "C:\Program Files\PostgreSQL\17\bin\psql.exe" -h aws-1-ap-northeast-1.pooler.supabase.com -p 5432 -U postgres.ljxkqxjhrahzvnodqlqt -d postgres -v ON_ERROR_STOP=0 -f prod_schema.sql
$env:PGPASSWORD = ''
```

- 스토리지(버킷/정책)는 `dev_storage.sql` 참고 (이미 dev에 적용됨)
- ⚠️ 비밀번호는 **절대 코드/문서에 적지 말 것**. 명령 실행 시 본인 터미널에만 입력.
- ⚠️ 비번에 기호(`!#$` 등) 있으면 URL/PowerShell에서 깨짐 → DB 비번은 **영문+숫자**로.

---

## 7. 자주 막히는 것

| 증상 | 원인 / 해결 |
|------|-------------|
| 미리보기 `manifest.json 401` | Vercel 미리보기 보호(Deployment Protection). 개발엔 지장 없음. 폰/PWA 테스트하려면 Settings→Deployment Protection→Vercel Authentication 끄기 |
| dev 미리보기에서 **지도 안 뜸** | Google Maps 키 리퍼러 제한. 키에 `https://*-ret-work-s-projects.vercel.app/*` 추가 (prod 패턴은 그대로 두고 추가만) |
| 콘솔에 `DB env: prod`인데 dev여야 함 | 접속 주소가 `_PROD_HOSTS`에 들어있는지 확인 |
| 빌드해도 화면 안 바뀜 | 빌드 번호(`__APP_BUILD__` + `CACHE_NAME`) 안 올렸는지 확인. 둘 다 올려야 캐시 갱신됨 |

---

## 8. 베타 정식 오픈 전 체크리스트 (나중에)

- [ ] `_BYPASS_ADS = true` → `false` (광고 우회 끄기)
- [ ] `security_patch_v3.sql` 재실행 확인
- [ ] `ct_comment_count_sync.sql` 등 SQL 파일들 prod에 적용됐는지 확인
- [ ] Maps 키에 production 도메인만 남기고 점검
- [ ] Supabase 사용량 쿼터 상한 설정 (예산 알림은 이미 ¥10,000)

---

## 9. 주요 파일

| 파일 | 용도 |
|------|------|
| `public/index.html` | 앱 본체 (단일 파일 PWA) |
| `public/sw.js` | 서비스워커 (캐시) |
| `prod_schema.sql` | prod 전체 스키마 덤프 (49 테이블) |
| `dev_storage.sql` | dev 스토리지 버킷/정책 복제본 |
| `*.sql` (루트) | 기능별 DB 마이그레이션 (ct_post_likes, ct_notices, receipt_images 등) |
