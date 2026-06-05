'use client';

import { useEffect } from 'react';

type Props = {
  slot?: string;
  format?: 'auto' | 'rectangle' | 'horizontal' | 'vertical';
  responsive?: boolean;
  style?: React.CSSProperties;
  className?: string;
};

declare global {
  interface Window { adsbygoogle?: unknown[]; }
}

/**
 * AdSense 슬롯 컴포넌트
 *   .env: NEXT_PUBLIC_ADSENSE_CLIENT=ca-pub-XXXXXXXXXXXX
 *   slot prop 으로 광고 단위 ID 지정
 *   심사 통과 전이면 placeholder 표시 (광고 호출 시도)
 */
export default function AdSlot({
  slot,
  format = 'auto',
  responsive = true,
  style,
  className,
}: Props) {
  const client = process.env.NEXT_PUBLIC_ADSENSE_CLIENT;

  useEffect(() => {
    if (!client) return;
    try {
      (window.adsbygoogle = window.adsbygoogle || []).push({});
    } catch (e) {
      console.warn('[AdSlot] push failed', e);
    }
  }, [client]);

  if (!client) {
    return (
      <div className={`ad-slot ${className || ''}`} style={style}>
        広告スロット（AdSense未設定）<br />
        NEXT_PUBLIC_ADSENSE_CLIENT を設定すると広告が表示されます。
      </div>
    );
  }

  return (
    <ins
      className={`adsbygoogle ${className || ''}`}
      style={{ display: 'block', ...style }}
      data-ad-client={client}
      data-ad-slot={slot || ''}
      data-ad-format={format}
      data-full-width-responsive={responsive ? 'true' : 'false'}
    />
  );
}
