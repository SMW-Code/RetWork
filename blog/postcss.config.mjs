// Tailwind/PostCSS plugin 자동 감지 우회 (plain CSS 사용)
// Next.js 15.5 가 기본적으로 @tailwindcss/postcss 를 찾으려고 시도하는데
// 이 파일이 있으면 Next.js 가 명시된 plugins 만 사용함.
const config = {
  plugins: {},
};
export default config;
