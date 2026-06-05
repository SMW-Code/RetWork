// Plain CSS pipeline — Tailwind 없음
// Next.js 15.5 가 기본으로 @tailwindcss/postcss 를 찾는 것을
// 이 명시적 config 로 override 함.
const config = {
  plugins: {
    'postcss-import': {},
    'autoprefixer': {},
  },
};
export default config;
