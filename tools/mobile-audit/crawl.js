const L = require('./lib');
const fs = require('fs');
const USER = process.env.USER_EMAIL || 'admin@anphat.local', PW = process.env.USER_PW || 'AnPhat2026demo';
const TAG = process.env.TAG || 'deep';
const ROUTES = (process.env.ROUTES || '/dashboard,/employees,/attendance,/attendance-requests,/payroll,/departments,/shifts,/leaves,/company-settings,/profile,/excel,/reports,/audit-logs,/org-chart,/contracts,/documents,/roles,/shift-swaps,/team-approvals').split(',');
const MAXBTN = +(process.env.MAXBTN || 14);
const OVER = /overflowed|EXCEPTION CAUGHT|RenderBox was not laid out|non-zero flex|unbounded|Another exception/;
const DANGER = /xoá|xóa|delete|duyệt|approve|từ chối|reject|khoá|khóa|lock|đăng xuất|logout|nghỉ việc|reset|gỡ|hủy yêu cầu|trả lương|chốt|đánh dấu|xác nhận|đồng ý|^lưu$|ghi nhận|cấp phép$|gửi$|menu|thông báo|notification|^a$|^t$/i;
const slug = s => s.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-zA-Z0-9]+/g, '-').slice(0, 24).toLowerCase();
const report = [];
(async () => {
  const { browser, page, logs } = await L.launch();
  await page.goto(L.BASE + '/', { waitUntil: 'domcontentloaded' });
  await L.waitApp(page, 200000); await page.waitForTimeout(6000);
  await page.mouse.click(195, 453); await page.keyboard.type(USER, { delay: 15 });
  await page.mouse.click(195, 517); await page.keyboard.type(PW, { delay: 15 });
  await page.keyboard.press('Enter'); await page.waitForTimeout(9000);
  const go = async r => { for (let k=0;k<3;k++){ await page.keyboard.press('Escape'); await page.waitForTimeout(250);} await page.evaluate(route => { history.pushState({}, '', route); window.dispatchEvent(new PopStateEvent('popstate')); }, r); await page.waitForTimeout(4000); };
  const issuesSince = i => logs.slice(i).filter(l => OVER.test(l)).map(l => l.replace(/\s+/g, ' ').slice(0, 900));
  const click = async e => { await page.mouse.click(e.x + e.w / 2, e.y + e.h / 2); };
  const interactive = async role => (await L.labels(page)).filter(e => e.role === role && e.y > 52 && e.y + e.h < L.H - 66 && e.w > 8 && e.x >= 0 && e.x < L.W);
  for (const route of ROUTES) {
    const name = route.replace(/\//g, '_').replace(/^_/, '');
    await go(route);
    const tabs = await interactive('tab');
    const states = [{ tab: null }, ...tabs.map((t, i) => ({ tab: i, label: t.label }))];
    for (const st of states) {
      if (st.tab !== null) { await go(route); const tt = await interactive('tab'); if (!tt[st.tab]) continue; await click(tt[st.tab]); await page.waitForTimeout(2500);
        const i0 = logs.length; await page.screenshot({ path: `${process.env.OUT||'shots'}/${TAG}-${name}-tab${st.tab}.png` });
      }
      const prefix = `${name}-s${st.tab === null ? 'x' : st.tab}`;
      const tstart = logs.length;
      const tabIssues = issuesSince(tstart - 1);
      let btns = (await interactive('button')).filter(b => !DANGER.test(b.label));
      const seen = new Set(); btns = btns.filter(b => { const k = b.label + '|' + b.y; if (seen.has(k)) return false; seen.add(k); return true; }).slice(0, MAXBTN);
      for (let bi = 0; bi < btns.length; bi++) {
        // dựng lại trạng thái (tab) trước mỗi nút để tránh lệch vị trí
        if (bi > 0 || st.tab !== null) { await go(route); if (st.tab !== null) { const tt = await interactive('tab'); if (tt[st.tab]) { await click(tt[st.tab]); await page.waitForTimeout(2000); } } }
        const cur = (await interactive('button')).filter(b => !DANGER.test(b.label));
        const b = cur.find(x => x.label === btns[bi].label && Math.abs(x.y - btns[bi].y) < 60) || cur.find(x => x.label === btns[bi].label);
        if (!b) continue;
        const i1 = logs.length; const url0 = page.url();
        await click(b); await page.waitForTimeout(1800);
        const iss = issuesSince(i1);
        const f = `${process.env.OUT||'shots'}/${TAG}-${prefix}-b${bi}-${slug(b.label)}.png`;
        await page.screenshot({ path: f });
        report.push({ route, tab: st.label || null, button: b.label, url: page.url() !== url0 ? page.url() : '', shot: f, issues: iss });
        console.log(route, st.label || '-', '|', b.label, '| issues', iss.length);
        await page.keyboard.press('Escape'); await page.waitForTimeout(500); await page.keyboard.press('Escape'); await page.waitForTimeout(500);
      }
      report.push({ route, tab: st.label || null, button: '(trang)', issues: tabIssues });
    }
    fs.writeFileSync(`report-${TAG}.json`, JSON.stringify(report, null, 1));
  }
  fs.writeFileSync(`alllogs-${TAG}.txt`, logs.join('\n---\n'));
  await browser.close();
})();
