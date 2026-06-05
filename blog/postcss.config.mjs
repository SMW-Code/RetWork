// Next.js 15.5 가 자동으로 @tailwindcss/postcss 를 plugin 으로 등록함.
// 우리는 Tailwind directives 를 안 쓰므로 plain CSS 그대로 통과됨.
const config = {
  plugins: {
    '@tailwindcss/postcss': {},
  },
};
export default config;
