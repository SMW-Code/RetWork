import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'jp.retwork.app',
  appName: 'RetWork',
  webDir: 'public',
  // 네이티브 앱은 라이브 사이트를 그대로 로드 → 웹 배포만 하면 앱에도 즉시 반영.
  // 네이티브 브리지(AdMob 등 플러그인)는 이 원격 페이지에서도 window.Capacitor.Plugins 로 사용 가능.
  server: {
    url: 'https://retwork.jp',
    cleartext: false
  }
};

export default config;
