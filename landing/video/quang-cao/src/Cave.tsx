import { AbsoluteFill, Img, Sequence, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from 'remotion';
import timings from './cave-timings.json';

// Video "Cãi vã chuyện thiếu lương → BossKin là giải pháp". Hoạt hình tự vẽ (không dùng clip có bản quyền).
// Thời điểm từng đoạn lấy từ cave-timings.json do make_cave_voice.py sinh (theo độ dài giọng thoại).
const FPS = 30;
export const CAVE_DURATION = Math.ceil(timings.total * FPS);
const seg = timings.segments;
const F = (sec: number) => Math.round(sec * FPS);
const C = { navy: '#0b1630', navy2: '#16306a', blue: '#2563eb', sky: '#7cc4ff', amber: '#f59e0b', green: '#10b981', red: '#ef4444', white: '#fff' };
const FONT = `
@font-face{font-family:'BVP';font-weight:600;src:url(${staticFile('be-vietnam-pro-vietnamese-600-normal.woff2')})}
@font-face{font-family:'BVP';font-weight:800;src:url(${staticFile('be-vietnam-pro-vietnamese-800-normal.woff2')})}
@font-face{font-family:'BVP';font-weight:600;src:url(${staticFile('be-vietnam-pro-latin-600-normal.woff2')});unicode-range:U+0000-00FF}
@font-face{font-family:'BVP';font-weight:800;src:url(${staticFile('be-vietnam-pro-latin-800-normal.woff2')});unicode-range:U+0000-00FF}
@font-face{font-family:'BVP';font-weight:600;src:url(${staticFile('be-vietnam-pro-latin-ext-600-normal.woff2')});unicode-range:U+0100-02AF,U+1E00-1EFF}
@font-face{font-family:'BVP';font-weight:800;src:url(${staticFile('be-vietnam-pro-latin-ext-800-normal.woff2')});unicode-range:U+0100-02AF,U+1E00-1EFF}`;

const useIn = (delay = 0) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: f - delay, fps, config: { damping: 16, stiffness: 130 } });
  return { opacity: p, transform: `translateY(${(1 - p) * 50}px) scale(${0.92 + p * 0.08})` };
};

type Mood = 'angry' | 'sad' | 'happy' | 'talk';
// Nhân vật: đầu tròn + mặt đổi theo tâm trạng + thân áo. talking → nhún nhảy, angry → rung.
const Person = ({ role, mood, talking, frame }: { role: 'nv' | 'sep'; mood: Mood; talking: boolean; frame: number }) => {
  const shirt = role === 'sep' ? '#334155' : C.blue;
  const hair = role === 'sep' ? '#1f2937' : '#5b3a1e';
  const bounce = talking ? Math.sin(frame / 2.2) * 10 : 0;
  const shake = talking && mood === 'angry' ? Math.sin(frame * 1.9) * 7 : 0;
  const mouth =
    mood === 'happy' ? <path d="M70 118 Q90 138 110 118" stroke="#7a1f1f" strokeWidth="6" fill="none" strokeLinecap="round" /> :
    mood === 'sad' ? <path d="M72 128 Q90 112 108 128" stroke="#7a1f1f" strokeWidth="6" fill="none" strokeLinecap="round" /> :
    talking ? <ellipse cx="90" cy="122" rx="14" ry={7 + Math.abs(Math.sin(frame / 1.6)) * 9} fill="#7a1f1f" /> :
    <path d="M74 122 H106" stroke="#7a1f1f" strokeWidth="6" strokeLinecap="round" />;
  const brows = mood === 'angry'
    ? <><path d="M56 78 L82 90" stroke="#1f2937" strokeWidth="7" strokeLinecap="round" /><path d="M124 78 L98 90" stroke="#1f2937" strokeWidth="7" strokeLinecap="round" /></>
    : mood === 'sad'
    ? <><path d="M56 90 L82 78" stroke="#1f2937" strokeWidth="6" strokeLinecap="round" /><path d="M124 90 L98 78" stroke="#1f2937" strokeWidth="6" strokeLinecap="round" /></>
    : null;
  return (
    <svg width="470" height="582" viewBox="0 0 180 223" style={{ transform: `translate(${shake}px, ${bounce}px)` }}>
      <rect x="10" y="150" width="160" height="90" rx="40" fill={shirt} />
      {role === 'sep' && <path d="M90 148 L78 170 L90 205 L102 170 Z" fill="#dc2626" />}
      {role === 'nv' && <rect x="112" y="168" width="34" height="22" rx="4" fill="#fff" />}
      <rect x="76" y="132" width="28" height="26" rx="10" fill="#f1c9a5" />
      <circle cx="90" cy="88" r="58" fill="#f1c9a5" />
      <path d={role === 'sep' ? 'M32 80 Q36 22 90 24 Q144 22 148 80 Q120 52 90 56 Q60 52 32 80Z' : 'M30 84 Q30 20 92 24 Q150 26 150 84 Q128 46 92 52 Q56 46 30 84Z'} fill={hair} />
      <circle cx="68" cy="92" r="7" fill="#1f2937" /><circle cx="112" cy="92" r="7" fill="#1f2937" />
      {brows}{mouth}
      {mood === 'sad' && <ellipse cx="62" cy="112" rx="5" ry="9" fill="#7cc4ff" />}
    </svg>
  );
};

const Bubble = ({ who, text, shake, size = 66 }: { who: 'nv' | 'sep'; text: string; shake?: boolean; size?: number }) => {
  const f = useCurrentFrame();
  const sx = shake ? Math.sin(f * 1.7) * 6 : 0;
  return (
    <div style={{ ...useIn(0), position: 'absolute', top: 330, left: who === 'nv' ? 50 : 150, width: 880, background: '#fff', color: C.navy, borderRadius: 48, padding: '40px 50px', fontSize: size, fontWeight: 800, lineHeight: 1.25, boxShadow: '0 20px 60px rgba(0,0,0,.45)', marginLeft: sx }}>
      <div style={{ fontSize: 38, fontWeight: 600, color: who === 'nv' ? C.blue : '#b91c1c', marginBottom: 10 }}>{who === 'nv' ? 'Nhân viên' : 'Sếp'}</div>
      {text}
      <div style={{ position: 'absolute', bottom: -34, [who === 'nv' ? 'left' : 'right']: 150, width: 0, height: 0, borderLeft: '34px solid transparent', borderRight: '34px solid transparent', borderTop: '40px solid #fff' } as React.CSSProperties} />
    </div>
  );
};

const Payslip = () => (
  <div style={{ ...useIn(6), position: 'absolute', top: 810, left: 0, right: 0, display: 'flex', justifyContent: 'center' }}>
    <div style={{ background: '#fffbe6', color: C.navy, borderRadius: 24, padding: '22px 40px', fontSize: 44, fontWeight: 800, boxShadow: '0 14px 40px rgba(0,0,0,.4)', transform: 'rotate(-3deg)', textAlign: 'center' }}>
      Lương tháng 9 <span style={{ color: C.red }}>— thiếu 2 công?!</span>
    </div>
  </div>
);

const Title = ({ children, size = 84, delay = 0 }: { children: React.ReactNode; size?: number; delay?: number }) => (
  <div style={{ ...useIn(delay), fontSize: size, fontWeight: 800, lineHeight: 1.15, color: '#fff', textAlign: 'center', padding: '0 70px', letterSpacing: -2 }}>{children}</div>
);
const Em = ({ children, color = C.sky }: { children: React.ReactNode; color?: string }) => <span style={{ color }}>{children}</span>;

const Fade = ({ len, children }: { len: number; children: React.ReactNode }) => {
  const f = useCurrentFrame();
  const o = interpolate(f, [0, 6, len - 6, len], [0, 1, 1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  return <AbsoluteFill style={{ opacity: o }}>{children}</AbsoluteFill>;
};

const Phone = ({ src }: { src: string }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: f - 4, fps, config: { damping: 16, stiffness: 90 } });
  return (
    <div style={{ transform: `translateY(${(1 - p) * 300}px)`, opacity: p, border: '14px solid #070d1d', borderRadius: 64, overflow: 'hidden', boxShadow: '0 40px 90px rgba(0,0,0,.55)', width: 500 }}>
      <Img src={staticFile(src)} style={{ width: '100%', display: 'block' }} />
    </div>
  );
};

const Price = () => {
  const f = useCurrentFrame();
  const n = Math.round(interpolate(f, [6, 45], [0, 5000], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }));
  return (
    <div style={{ ...useIn(0), textAlign: 'center', color: '#fff' }}>
      <div style={{ fontSize: 50, fontWeight: 600, color: '#b9cdf3' }}>Chỉ từ</div>
      <div style={{ fontSize: 220, fontWeight: 800, lineHeight: 1, letterSpacing: -8 }}>{n.toLocaleString('de-DE')}đ</div>
      <div style={{ fontSize: 52, fontWeight: 600, color: '#d7e3fb' }}>/ nhân viên / tháng</div>
    </div>
  );
};

export const Cave = () => {
  const f = useCurrentFrame();
  const t = f / FPS;
  const solveAt = seg[5].start; // từ đoạn 6 trở đi là phần giải pháp
  const k = interpolate(t, [seg[4].start, seg[5].start], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  // nền: xám đỏ căng thẳng → xanh navy của BossKin
  const bg = k < 0.5
    ? `radial-gradient(120% 70% at 50% 0%, #5b2430 0%, #2a1520 45%, #120b14 90%)`
    : `radial-gradient(120% 70% at 40% 0%, #2a56b8 0%, ${C.navy2} 40%, ${C.navy} 85%)`;
  const argue = t < seg[4].start;
  const cur = seg.findIndex((s, i) => t >= s.start && (i === seg.length - 1 || t < seg[i + 1].start));
  const talk = (who: string) => cur >= 0 && cur < 4 && seg[cur].who === who && t < seg[cur].start + seg[cur].voice;
  const mood = (role: 'nv' | 'sep'): Mood => (cur >= 4 ? 'sad' : talk(role) ? 'angry' : 'talk');

  return (
    <AbsoluteFill style={{ fontFamily: 'BVP, sans-serif', background: bg }}>
      <style>{FONT}</style>

      {/* Phần 1: cãi vã (đoạn 1–4) + hậu quả (đoạn 5) */}
      {t < seg[5].start && (
        <AbsoluteFill style={{ opacity: interpolate(t, [seg[4].start + seg[4].len - 0.3, seg[5].start], [1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }) }}>
          <div style={{ position: 'absolute', bottom: 200, left: 0 }}><Person role="nv" mood={mood('nv')} talking={talk('nv')} frame={f} /></div>
          <div style={{ position: 'absolute', bottom: 200, right: 0, transform: 'scaleX(-1)' }}><Person role="sep" mood={mood('sep')} talking={talk('sep')} frame={f} /></div>
          {seg.slice(0, 4).map((s, i) => (
            <Sequence key={i} from={F(s.start)} durationInFrames={F(s.len + 0.25)}>
              <Bubble who={s.who as 'nv' | 'sep'} text={s.text} shake={true} />
            </Sequence>
          ))}
          {t >= seg[0].start + 1 && t < seg[4].start && <Payslip />}
          <Sequence from={F(seg[4].start)} durationInFrames={F(seg[4].len + 0.4)}>
            <AbsoluteFill style={{ background: 'rgba(10,6,12,.72)', alignItems: 'center', justifyContent: 'center' }}>
              <Title size={92}>Không có số liệu<br /><Em color={C.amber}>chỉ còn cãi nhau</Em> 😞</Title>
            </AbsoluteFill>
          </Sequence>
        </AbsoluteFill>
      )}

      {/* Logo xuất hiện từ phần giải pháp */}
      {t >= solveAt - 0.1 && (
        <div style={{ position: 'absolute', top: 70, left: 0, right: 0, display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 20, color: '#fff', fontSize: 54, fontWeight: 800, opacity: interpolate(t, [solveAt - 0.1, solveAt + 0.3], [0, 1], { extrapolateRight: 'clamp' }) }}>
          <Img src={staticFile('logo-192.png')} style={{ width: 76, height: 76, borderRadius: 38, background: '#fff' }} />BossKin
        </div>
      )}

      {/* Phần 2: giải pháp */}
      <Sequence from={F(seg[5].start)} durationInFrames={F(seg[5].len + 0.2)}>
        <Fade len={F(seg[5].len + 0.2)}>
          <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', gap: 50 }}>
            <Title>Chấm công bằng <Em>điện thoại</Em></Title>
            <Phone src="dt-cham-cong.webp" />
            <Title delay={14} size={50}>Công và lương <Em color={C.green}>tự tính</Em></Title>
          </AbsoluteFill>
        </Fade>
      </Sequence>
      <Sequence from={F(seg[6].start)} durationInFrames={F(seg[6].len + 0.2)}>
        <Fade len={F(seg[6].len + 0.2)}>
          <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', gap: 50 }}>
            <Title>Nhân viên tự xem <Em>công &amp; lương</Em></Title>
            <Phone src="dt-phieu-luong.webp" />
            <Title delay={14} size={50}>Minh bạch cho <Em color={C.green}>cả hai bên</Em> ✓</Title>
          </AbsoluteFill>
        </Fade>
      </Sequence>
      <Sequence from={F(seg[7].start)} durationInFrames={CAVE_DURATION - F(seg[7].start)}>
        <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', gap: 56 }}>
          <Price />
          <div style={{ ...useIn(22), background: C.amber, color: C.navy, fontSize: 46, fontWeight: 800, padding: '22px 44px', borderRadius: 999 }}>Dùng thử miễn phí 1 tháng</div>
          <Title delay={34} size={48}>Hỗ trợ cài đặt · xử lý sự cố <Em>24/24</Em></Title>
          <div style={{ ...useIn(46), display: 'flex', alignItems: 'center', gap: 40, color: '#fff' }}>
            <div style={{ background: '#fff', padding: 14, borderRadius: 20 }}><Img src={staticFile('qr-web.svg')} style={{ width: 190, height: 190 }} /></div>
            <div style={{ fontSize: 52, fontWeight: 800, lineHeight: 1.3 }}>bosskin.io.vn<br /><span style={{ color: C.sky, fontSize: 44, fontWeight: 600 }}>Zalo 0865 854 002</span></div>
          </div>
        </AbsoluteFill>
      </Sequence>
    </AbsoluteFill>
  );
};
