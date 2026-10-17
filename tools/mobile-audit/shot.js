const L=require('./lib');
(async()=>{const {browser,page,logs}=await L.launch();
await page.goto(L.BASE+'/',{waitUntil:'domcontentloaded'});await L.waitApp(page,200000);await page.waitForTimeout(6000);
await page.mouse.click(195,453);await page.keyboard.type('admin@anphat.local',{delay:15});
await page.mouse.click(195,517);await page.keyboard.type('AnPhat2026demo',{delay:15});await page.keyboard.press('Enter');await page.waitForTimeout(9000);
for(const r of ['/payroll','/leaves','/attendance','/employees','/company-settings']){
await page.evaluate(x=>{history.pushState({},'',x);window.dispatchEvent(new PopStateEvent('popstate'))},r);await page.waitForTimeout(4500);
await page.screenshot({path:`${process.env.OUT||'shots'}/fin-${r.slice(1)}.png`});}
console.log(logs.filter(l=>/overflowed/.test(l)).length);await browser.close();})();
