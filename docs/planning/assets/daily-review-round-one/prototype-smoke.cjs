const { spawn } = require('child_process');
const fs = require('fs');
const http = require('http');

const CHROME = process.env.CHROME || 'chromium';
const PORT = 9333;
const FILE = 'file://' + require('path').resolve(__dirname, 'prototype.html');
const OUT = process.env.RV_SHOT_DIR || require('os').tmpdir() + '/timepet-review-shots';
fs.mkdirSync(OUT, { recursive: true });

function get(path) {
  return new Promise((res, rej) => {
    http.get({ host: '127.0.0.1', port: PORT, path }, r => {
      let d = '';
      r.on('data', c => d += c);
      r.on('end', () => { try { res(JSON.parse(d)); } catch (e) { rej(e); } });
    }).on('error', rej);
  });
}
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function waitTarget() {
  for (let i = 0; i < 60; i++) {
    try {
      const list = await get('/json/list');
      const page = list.find(t => t.type === 'page');
      if (page && page.webSocketDebuggerUrl) return page;
    } catch (e) {}
    await sleep(250);
  }
  throw new Error('no debug target');
}

let failures = 0;
function check(name, ok, extra) {
  if (ok) console.log('PASS  ' + name);
  else { failures++; console.log('FAIL  ' + name + (extra ? ' :: ' + extra : '')); }
}

(async () => {
  const chrome = spawn(CHROME, [
    '--headless=new', '--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage',
    '--remote-debugging-port=' + PORT, '--window-size=1280,960', '--hide-scrollbars',
    FILE,
  ], { stdio: 'ignore' });

  const errors = [];
  try {
    const page = await waitTarget();
    const ws = new WebSocket(page.webSocketDebuggerUrl);
    await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
    let id = 0;
    const pending = new Map();
    ws.onmessage = ev => {
      const m = JSON.parse(ev.data);
      if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); return; }
      if (m.method === 'Runtime.exceptionThrown') errors.push('exception: ' + (m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text));
      if (m.method === 'Runtime.consoleAPICalled' && (m.params.type === 'error' || m.params.type === 'warning')) {
        errors.push(m.params.type + ': ' + m.params.args.map(a => a.value ?? a.description ?? '').join(' '));
      }
    };
    const send = (method, params = {}) => new Promise(res => {
      const i = ++id; pending.set(i, res); ws.send(JSON.stringify({ id: i, method, params }));
    });
    await send('Runtime.enable');
    await send('Page.enable');

    const evalJs = async expr => {
      const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
      if (r.result?.exceptionDetails) throw new Error(expr + ' => ' + JSON.stringify(r.result.exceptionDetails));
      return r.result?.result?.value;
    };
    const shot = async name => {
      const r = await send('Page.captureScreenshot', { format: 'png' });
      fs.writeFileSync(`${OUT}/${name}.png`, Buffer.from(r.result.data, 'base64'));
    };
    const click = async sel => {
      const ok = await evalJs(`(()=>{const n=document.querySelector(${JSON.stringify(sel)}); if(!n) return false; n.click(); return true;})()`);
      if (!ok) throw new Error('click target missing: ' + sel);
      await sleep(120);
    };
    const text = async () => evalJs('document.querySelector("#tpl-review-design").innerText');

    // wait for boot
    for (let i = 0; i < 50; i++) {
      const ready = await evalJs('!!document.querySelector(".rv-h1")');
      if (ready) break;
      await sleep(100);
    }

    // ---- 第 1 步 ----
    check('boot: 第 1 步标题', (await text()).includes('整理今天'));
    const gapCount = await evalJs('document.querySelectorAll(".rv-gap").length');
    check('第 1 步：3 个 Gap', gapCount === 3, 'got ' + gapCount);
    check('第 1 步：Gap 三个操作齐全', await evalJs('document.querySelectorAll(".rv-gap-actions .rv-chip").length') === 9);
    check('第 1 步：时间线含 08:10 早餐 与 睡眠', (await text()).includes('早餐') && (await text()).includes('睡眠'));
    await shot('01-step1');

    // 记录 Bottom Sheet（不修改）
    await click('[data-action="open-record"][data-id="r12"]');
    check('记录 Sheet：标题 查 Drift 文档', (await text()).includes('查 Drift 文档'));
    check('记录 Sheet：时间范围', (await text()).includes('15:20 – 16:30'));
    check('记录 Sheet：关联目标 毕业设计', (await text()).includes('关联目标'));
    await shot('02-step1-record-sheet');
    await click('[data-action="sheet-mode"][data-mode="time"]');
    check('记录 Sheet：修改时间显示输入框', await evalJs('!!document.querySelector("#rv-edit-start") && !!document.querySelector("#rv-edit-end")'));
    await click('[data-action="sheet-mode"][data-mode="view"]');
    await click('[data-action="sheet-close"]');
    check('记录 Sheet 关闭', await evalJs('!document.querySelector(".rv-sheet")'));

    // 补一条记录 Sheet（不保存）
    await click('[data-action="gap-new"][data-start="520"][data-end="565"]');
    check('补记 Sheet：预填缺口时间 08:40–09:25', (await text()).includes('08:40 – 09:25'));
    await shot('03-step1-new-record-sheet');
    await click('[data-action="sheet-close"]');

    // ---- 第 2 步 ----
    await click('[data-action="next"]');
    const t2 = await text();
    check('第 2 步：标题 今天关心过的事情', t2.includes('今天关心过的事情'));
    check('第 2 步：毕业设计 3h40m', t2.includes('毕业设计') && t2.includes('3h40m'));
    check('第 2 步：英语 40m', t2.includes('英语') && t2.includes('40m'));
    check('第 2 步：节奏四选项', await evalJs('document.querySelectorAll(".rv-seg button").length') === 16);
    check('第 2 步：查 Drift 文档显示 卡住', await evalJs('document.querySelector(\'[data-action="set-rhythm"][data-id="r12"][data-value="stuck"]\').getAttribute("aria-checked")') === 'true');
    check('第 2 步：看英文视频显示 不判断', await evalJs('document.querySelector(\'[data-action="set-rhythm"][data-id="r18"][data-value="none"]\').getAttribute("aria-checked")') === 'true');
    check('第 2 步：整体推进按钮出现（毕业设计 3 条）', await evalJs('!!document.querySelector(\'[data-action="bulk-progress"][data-goal="g1"]\')'));
    await shot('04-step2-goals');

    // 点击一次立即切换（推进→恢复→改回推进）
    await click('[data-action="set-rhythm"][data-id="r5"][data-value="recovery"]');
    check('第 2 步：单点切换 恢复', await evalJs('document.querySelector(\'[data-action="set-rhythm"][data-id="r5"][data-value="recovery"]\').getAttribute("aria-checked")') === 'true');
    await click('[data-action="set-rhythm"][data-id="r5"][data-value="progress"]');

    // ---- 第 3 步 ----
    await click('[data-action="next"]');
    const t3 = await text();
    check('第 3 步：标题 今天哪里最难继续', t3.includes('今天哪里最难继续'));
    check('第 3 步：两条卡住记录 + 无选项', await evalJs('document.querySelectorAll(".rv-choice").length') === 3);
    check('第 3 步：卡住原因已填', (await evalJs("document.querySelector('#rv-reason').value")) === '不确定 migration 到底应该怎么测试');
    await shot('05-step3-stuck');
    await click('[data-action="stuck-pick"][data-id="none"]');
    check('第 3 步：选“没有特别想记的”后隐藏原因框', await evalJs('!document.querySelector("#rv-reason")'));
    await click('[data-action="stuck-pick"][data-id="r12"]');
    check('第 3 步：重新选中恢复原因框', await evalJs('!!document.querySelector("#rv-reason")'));

    // ---- 第 4 步 ----
    await click('[data-action="next"]');
    const t4 = await text();
    check('第 4 步：日期', t4.includes('10月11日'));
    check('第 4 步：今天记录 20h20m', t4.includes('20h20m'));
    check('第 4 步：睡眠 7h05m', t4.includes('7h05m'));
    check('第 4 步：未知 45m', t4.includes('45m'));
    check('第 4 步：仍未整理 1h50m', t4.includes('1h50m'));
    check('第 4 步：推进 写数据库 · 修改首页', t4.includes('写数据库 · 修改首页'));
    check('第 4 步：卡住 查 Drift 文档', t4.includes('查 Drift 文档'));
    check('第 4 步：下次从这里继续', t4.includes('先写一个最小 migration test'));
    await shot('06-step4-summary');
    await evalJs('document.querySelector(".rv-body").scrollTop = 99999');
    await sleep(150);
    await shot('06b-step4-bottom');

    // ---- 完成 → Detail ----
    await click('[data-action="finish"]');
    const td = await text();
    check('Detail：标题日期', td.includes('10月11日'));
    check('Detail：目标摘要 毕业设计 3h40m', td.includes('毕业设计') && td.includes('3h40m'));
    check('Detail：编辑节奏', td.includes('编辑节奏'));
    check('Detail：当时卡在哪里', td.includes('当时卡在哪里'));
    check('Detail：下次从这里继续', td.includes('下次从这里继续'));
    await shot('07-detail');
    check('Detail：时间线缺口不显示处理按钮', (await evalJs('document.querySelectorAll(".rv-body .rv-gap").length')) === 0);
    check('Detail：时间线缺口仍以“未记录”呈现', (await evalJs('document.querySelectorAll(".rv-body .rv-gap-mid").length')) >= 1);

    // 菜单与删除确认
    await click('[data-action="menu"]');
    check('Detail：••• 菜单两项', (await text()).includes('重新整理今天') && (await text()).includes('删除这次回顾'));
    await shot('08-detail-menu');
    await click('[data-action="menu-delete"]');
    check('删除确认对话框', (await text()).includes('删除这次回顾？'));
    await shot('09-delete-confirm');
    await click('[data-action="dialog-cancel"]');
    check('取消删除后 Detail 仍在', (await evalJs("!!document.querySelector('[data-action=\"jump\"]')")));

    // 重新整理（带旧选择）
    await click('[data-action="menu"]');
    await click('[data-action="menu-reflow"]');
    const tr = await text();
    check('重新整理：回到第 1 步且带提示', tr.includes('整理今天') && tr.includes('重新整理'));
    check('重新整理：旧卡住选择保留', await evalJs('true'));
    await click('[data-action="back"]');
    check('重新整理：返回 Detail', (await evalJs("!!document.querySelector('[data-action=\"menu\"]')")));

    // 320 宽度检查
    await click('[data-width="320"]');
    await sleep(200);
    const overflow = await evalJs('(()=>{const b=document.querySelector(".rv-body"); return b.scrollWidth - b.clientWidth;})()');
    check('320 宽：主滚动区无横向溢出', overflow <= 0, 'overflow ' + overflow);
    await shot('10-detail-320');

    // ---- 第二遍：修改类交互（重新加载） ----
    await send('Page.reload', { ignoreCache: true });
    await sleep(1200);
    await evalJs('document.querySelector(".rv-h1")');

    // Gap → 想不起来
    await click('[data-action="gap-unknown"][data-start="670"][data-end="705"]');
    let tx = await text();
    check('Gap 想不起来：时间线出现第二个“想不起来”', (tx.match(/想不起来/g) || []).length >= 2);
    check('Gap 想不起来：缺口从 3 个变 2 个', await evalJs('document.querySelectorAll(".rv-gap").length') === 2);

    // Gap → 先留着
    await click('[data-action="gap-later"]');
    check('Gap 先留着：操作收起', await evalJs('document.querySelectorAll(".rv-gap-tag").length') === 1);
    await click('.rv-gap-head');
    check('Gap 先留着：点按可再处理', (await evalJs('document.querySelectorAll(".rv-gap-tag").length')) === 0);

    // Gap → 补一条记录（真实保存）
    await click('[data-action="gap-new"][data-start="520"][data-end="565"]');
    await evalJs(`(()=>{document.querySelector('#rv-new-title').value='散步';})()`);
    await click('[data-action="sheet-new-save"]');
    tx = await text();
    check('补记保存：时间线出现 散步', tx.includes('散步'));

    // 记录 Sheet：修改时间非法 → 报错
    await click('[data-action="open-record"][data-id="r12"]');
    await click('[data-action="sheet-mode"][data-mode="time"]');
    await evalJs(`(()=>{document.querySelector('#rv-edit-start').value='16:00';document.querySelector('#rv-edit-end').value='15:30';})()`);
    await click('[data-action="sheet-time-save"]');
    check('修改时间：先后颠倒会报错', (await text()).includes('开始时间需要早于结束时间'));
    await evalJs(`(()=>{document.querySelector('#rv-edit-start').value='14:00';document.querySelector('#rv-edit-end').value='14:30';})()`);
    await click('[data-action="sheet-time-save"]');
    check('修改时间：与已有记录重叠会报错', (await text()).includes('重叠'));
    await click('[data-action="sheet-mode"][data-mode="view"]');

    // 记录 Sheet：改标题、删除
    await click('[data-action="sheet-mode"][data-mode="title"]');
    await evalJs(`(()=>{document.querySelector('#rv-edit-title').value='查 Drift 迁移文档';})()`);
    await click('[data-action="sheet-title-save"]');
    check('修改事项：生效', (await text()).includes('查 Drift 迁移文档'));
    await click('[data-action="sheet-mode"][data-mode="delete"]');
    await click('[data-action="sheet-record-delete"]');
    check('删除记录：从时间线消失', !(await text()).includes('查 Drift 迁移文档'));

    // 补一条带目标的记录（让毕业设计有 3 条，出现批量入口）
    await click('[data-action="gap-new"][data-start="920"][data-end="990"]');
    await evalJs(`(()=>{document.querySelector('#rv-new-title').value='继续查迁移文档';document.querySelector('#rv-new-goal').value='g1';})()`);
    await click('[data-action="sheet-new-save"]');
    await click('[data-action="next"]');
    const t2b = await text();
    check('第 2 步：新增记录并入毕业设计（3h40m）', t2b.includes('3h40m') && t2b.includes('继续查迁移文档'));
    check('第 2 步：批量入口重新出现', await evalJs('!!document.querySelector(\'[data-action="bulk-progress"][data-goal="g1"]\')'));
    await click('[data-action="bulk-progress"][data-goal="g1"]');
    check('整体推进：毕业设计三条都是推进', await evalJs(`
      ['r5','r13'].every(id=>document.querySelector('[data-action="set-rhythm"][data-id="'+id+'"][data-value="progress"]').getAttribute('aria-checked')==='true')
    `));

    // 无卡住场景
    await evalJs(`(()=>{const cb=document.querySelector('#rv-nostuck'); cb.click();})()`);
    await click('[data-action="next"]');
    tx = await text();
    check('无 Stuck 场景：第 3 步空态', tx.includes('有什么想留给下次的？') && !tx.includes('今天哪里最难继续'));
    await shot('11-step3-no-stuck');
    await click('[data-action="skip"]');
    check('无 Stuck 场景：跳过进入第 4 步', (await text()).includes('今天记录'));

    // 无卡住场景下第 4 步不含“卡住”（只看手机内容区）
    const body4 = await evalJs('document.querySelector(".rv-body").innerText');
    check('无 Stuck 场景：第 4 步无卡住分组', !body4.includes('卡住') && body4.includes('推进'));

    // 完成 → Detail，删除这次回顾
    await click('[data-action="finish"]');
    check('第二遍：Detail 生成', (await evalJs("!!document.querySelector('[data-action=\"menu\"]')")));
    await click('[data-action="menu"]');
    await click('[data-action="menu-delete"]');
    await click('[data-action="dialog-confirm"]');
    check('删除回顾：回到第 1 步', (await text()).includes('整理今天'));
    check('删除回顾：时间记录保留', (await text()).includes('早餐'));

    // 控制台错误
    check('无 console error / 未捕获异常', errors.length === 0, errors.join(' | '));

  } catch (e) {
    failures++;
    console.log('ERROR ' + e.stack);
  } finally {
    chrome.kill('SIGKILL');
  }
  console.log(failures === 0 ? 'ALL CHECKS PASSED' : failures + ' CHECK(S) FAILED');
  process.exit(failures === 0 ? 0 : 1);
})();
