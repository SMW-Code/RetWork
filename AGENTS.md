<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

# i18n (필수 규칙)

새 페이지·카드·모달·토스트·버튼·placeholder 등 **모든 사용자 대면 UI는 처음부터 4개국어(ja/ko/en/zh)로 i18n** 한다. 하드코딩 금지. 키는 `public/index.html`의 `var I18N` 4블록 **모두**에 추가(어드민 "언어시트"에 자동 노출됨). 예외: **어드민=한국어 고정, SEO 랜딩/블로그=일본어 고정**. 작업 전 **`I18N_GUIDE.md`** 를 읽을 것(방법·재사용 키·체크리스트·함정).

# 영수증 파싱 (필수 규칙)

영수증 OCR→파싱(전처리·Vision·좌표 파서·GPT 프롬프트·검증)을 수정하기 전에 **반드시 `PARSING.md`** 를 읽을 것. 파이프라인·프롬프트 전문·모델 전략·해결한 문제·함수 위치가 정리돼 있다. 파서/프롬프트를 고치면 **`PARSING.md` 와 `public/table-proto.html`(실험장)도 함께 갱신**한다.
