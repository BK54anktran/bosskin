import { AbsoluteFill, Img, Sequence, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from 'remotion';

// Video quảng cáo BossKin 9:16, 25 giây. Nội dung khớp landing (mục Bảng giá) và poster giá.
const FPS = 30;
const S = (sec: number) => Math.round(sec * FPS);
export const DURATION = S(25);

const C = { navy: '#0b1630', navy2: '#16306a', blue: '#2563eb', sky: '#7cc4ff', amber: '#f59e0b', green: '#10b981', white: '#fff' };

const FONT = `
@font-face{font-family:'BVP';font-weight:600;src:url(${staticFile('be-vietnam-pro-vietnamese-600-normal.woff2')})}
@font-face{font-family:'BVP';font-weight:800;src:url(${staticFile('be-vietnam-pro-vietnamese-800-normal.woff2')})}
@font-face{font-family:'BVP';font-weight:600;src:url(${staticFile('be-vietnam-pro-latin-600-normal.woff2')});unicode-range:U+0000-00FF}
@font-face{font-family:'BVP';font-weight:800;src:url(${staticFile('be-vietnam-pro-latin-800-normal.woff2')});unicode-range:U+0000-00FF}
@font-face{font-family:'BVP';font-weight:600;src:url(${staticFile('be-vietnam-pro-latin-ext-600-normal.woff2')});unicode-range:U+0100-02AF,U+1E00-1EFF}
@font-face{font-family:'BVP';font-weight:800;src:url(${staticFile('be-vietnam-pro-latin-ext-800-normal.woff2')});unicode-range:U+0100-02AF,U+1E00-1EFF}`;

// Hiện dần + trượt lên (spring), dùng cho từng khối chữ.
const useIn = (delay = 0) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: f - delay, fps, config: { damping: 18, stiffness: 120 } });
  return { opacity: p, transform: `translateY(${(1 - p) * 60}px)` };
};

const Title = ({ children, delay = 0, size = 92 }: { children: React.ReactNode; delay?: number; size?: number }) => (
  <div style={{ ...useIn(delay), fontSize: size, fontWeight: 800, lineHeight: 1.15, color: C.white, textAlign: 'center', padding: '0 70px', letterSpacing: -2 }}>{children}</div>
);
const Em = ({ children, color = C.sky }: { children: React.ReactNode; color?: string }) => <span style={{ color }}>{children}</span>;

// Mỗi cảnh: mờ vào / mờ ra, nền navy
const Scene = ({ children, len }: { children: React.ReactNode; len: number }) => {
  const f = useCurrentFrame();
  const o = interpolate(f, [0, 8, len - 8, len], [0, 1, 1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  return <AbsoluteFill style={{ opacity: o, alignItems: 'center', justifyContent: 'center', gap: 60 }}>{children}</AbsoluteFill>;
};

const Phone = ({ src, delay = 6 }: { src: string; delay?: number }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: f - delay, fps, config: { damping: 16, stiffness: 90 } });
  return (
    <div style={{ transform: `translateY(${(1 - p) * 300}px) scale(${0.9 + p * 0.1})`, opacity: p, border: '14px solid #070d1d', borderRadius: 64, overflow: 'hidden', boxShadow: '0 40px 90px rgba(0,0,0,.55)', width: 520 }}>
      <Img src={staticFile(src)} style={{ width: '100%', display: 'block' }} />
    </div>
  );
};

const Screen = ({ src, delay = 6 }: { src: string; delay?: number }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: f - delay, fps, config: { damping: 16, stiffness: 90 } });
  const z = interpolate(f, [0, 150], [1, 1.06], { extrapolateRight: 'clamp' });
  return (
    <div style={{ transform: `translateY(${(1 - p) * 300}px) scale(${z})`, opacity: p, borderRadius: 28, overflow: 'hidden', boxShadow: '0 40px 90px rgba(0,0,0,.55)', width: 960 }}>
      <Img src={staticFile(src)} style={{ width: '100%', display: 'block' }} />
    </div>
  );
};

const Pill = ({ children, bg, color = C.white, delay = 0 }: { children: React.ReactNode; bg: string; color?: string; delay?: number }) => (
  <div style={{ ...useIn(delay), background: bg, color, fontSize: 46, fontWeight: 800, padding: '22px 44px', borderRadius: 999 }}>{children}</div>
);

const Price = () => {
  const f = useCurrentFrame();
  const n = Math.round(interpolate(f, [10, 55], [0, 5000], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }));
  const txt = n.toLocaleString('de-DE'); // 5.000
  return (
    <div style={{ ...useIn(0), textAlign: 'center', color: C.white }}>
      <div style={{ fontSize: 54, fontWeight: 600, color: '#b9cdf3' }}>Chỉ từ</div>
      <div style={{ fontSize: 230, fontWeight: 800, lineHeight: 1, letterSpacing: -8 }}>{txt}đ</div>
      <div style={{ fontSize: 56, fontWeight: 600, color: '#d7e3fb' }}>/ nhân viên / tháng</div>
    </div>
  );
};

export const Quangcao = () => {
  const f = useCurrentFrame();
  const drift = interpolate(f, [0, DURATION], [0, 100]);
  return (
    <AbsoluteFill style={{ fontFamily: 'BVP, sans-serif', background: `radial-gradient(120% 70% at ${30 + drift * 0.4}% 0%, #2a56b8 0%, ${C.navy2} 40%, ${C.navy} 85%)` }}>
      <style>{FONT}</style>

      {/* Logo cố định */}
      <div style={{ position: 'absolute', top: 70, left: 0, right: 0, display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 20, color: C.white, fontSize: 54, fontWeight: 800 }}>
        <Img src={staticFile('logo-192.png')} style={{ width: 76, height: 76, borderRadius: 38, background: '#fff' }} />BossKin
      </div>

      {/* 1. Mở đầu 0–3,5s */}
      <Sequence from={0} durationInFrames={S(3.5)}>
        <Scene len={S(3.5)}>
          <Title size={104}>Cuối tháng vẫn <Em color={C.amber}>ngồi đối chiếu Excel</Em>?</Title>
          <Title delay={14} size={64}><Em>BossKin</Em> làm hết cho bạn.</Title>
        </Scene>
      </Sequence>

      {/* 2. Chấm công 3,5–8s */}
      <Sequence from={S(3.5)} durationInFrames={S(4.5)}>
        <Scene len={S(4.5)}>
          <Title>Chấm công bằng <Em>điện thoại</Em></Title>
          <Phone src="dt-cham-cong.webp" />
          <Title delay={20} size={46}>GPS + đúng một máy, không chấm hộ</Title>
        </Scene>
      </Sequence>

      {/* 3. Xếp ca 8–12s */}
      <Sequence from={S(8)} durationInFrames={S(4)}>
        <Scene len={S(4)}>
          <Title>Xếp ca cả xưởng <Em>trong vài phút</Em></Title>
          <Screen src="man-xep-ca.webp" />
          <Title delay={20} size={46}>Ca đêm · ca gãy · xoay ca · đổi ca</Title>
        </Scene>
      </Sequence>

      {/* 4. Duyệt công 12–16s */}
      <Sequence from={S(12)} durationInFrames={S(4)}>
        <Scene len={S(4)}>
          <Title>Biết ngay hôm nay <Em>ai đi làm</Em></Title>
          <Screen src="man-tong-quan.webp" />
          <Title delay={20} size={46}>Duyệt công cả kỳ chỉ một chạm</Title>
        </Scene>
      </Sequence>

      {/* 5. Lương 16–20s */}
      <Sequence from={S(16)} durationInFrames={S(4)}>
        <Scene len={S(4)}>
          <Title>Tính lương <Em color={C.green}>tự động</Em></Title>
          <Phone src="dt-phieu-luong.webp" />
          <Title delay={20} size={46}>BHXH, thuế TNCN đúng quy định</Title>
        </Scene>
      </Sequence>

      {/* 6. Giá + ưu đãi + CTA 20–25s */}
      <Sequence from={S(20)} durationInFrames={S(5)}>
        <Scene len={S(5)}>
          <Price />
          <Pill bg={C.amber} color={C.navy} delay={20}>Dùng thử miễn phí 1 tháng</Pill>
          <Title delay={32} size={50}>Hỗ trợ cài đặt · xử lý sự cố <Em>24/24</Em></Title>
          <div style={{ ...useIn(44), display: 'flex', alignItems: 'center', gap: 40, color: C.white }}>
            <div style={{ background: '#fff', padding: 14, borderRadius: 20 }}><Img src={staticFile('qr-web.svg')} style={{ width: 190, height: 190 }} /></div>
            <div style={{ fontSize: 52, fontWeight: 800, lineHeight: 1.3 }}>bosskin.io.vn<br /><span style={{ color: C.sky, fontSize: 44, fontWeight: 600 }}>Zalo 0865 854 002</span></div>
          </div>
        </Scene>
      </Sequence>
    </AbsoluteFill>
  );
};
