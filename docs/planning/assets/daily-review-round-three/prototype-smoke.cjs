const { spawn } = require('child_process');
const fs = require('fs');
const http = require('http');

const CHROME = process.env.CHROME || 'chromium';
const PORT = 9334;
const FILE = 'file://' + require('path').resolve(__dirname, 'prototype.html');
const OUT = process.env.RV_SHOT_DIR || require('os').tmpdir() + '/timepet-review-r3-shots';
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
    const bodyText = async () => evalJs('document.querySelector(".rv-body").innerText');

    for (let i = 0; i < 50; i++) {
      const ready = await evalJs('!!document.querySelector(".rv-h1")');
      if (ready) break;
      await sleep(100);
    }

    /* ---------------- 第 1 步 ---------------- */
    check('boot: 第 1 步标题', (await text()).includes('整理今天'));
    check('第 1 步：3 个 Gap', (await evalJs('document.querySelectorAll(".rv-gap").length')) === 3);
    check('第 1 步：Gap 三个操作齐全', (await evalJs('document.querySelectorAll(".rv-gap-actions .rv-chip").length')) === 9);
    check('第 1 步：时间线含 早餐 / 睡眠 / 散步', (await text()).includes('早餐') && (await text()).includes('睡眠') && (await text()).includes('散步'));
    await shot('01-step1');

    await click('[data-action="open-record"][data-id="r12"]');
    check('记录 Sheet：查 Drift 文档 / 15:20 – 16:30', (await text()).includes('查 Drift 文档') && (await text()).includes('15:20 – 16:30'));
    await shot('02-record-sheet');
    await click('[data-action="sheet-mode"][data-mode="time"]');
    check('记录 Sheet：修改时间输入框', await evalJs('!!document.querySelector("#rv-edit-start")'));
    await click('[data-action="sheet-mode"][data-mode="view"]');
    await click('[data-action="sheet-close"]');

    await click('[data-action="gap-new"][data-start="520"][data-end="565"]');
    check('补记 Sheet：预填 08:40 – 09:25', (await text()).includes('08:40 – 09:25'));
    await shot('03-new-record-sheet');
    await click('[data-action="sheet-close"]');

    /* ---------------- 第 2 步：目标优先 + 无目标记录轴 ---------------- */
    await click('[data-action="next"]');
    check('第 2 步：标题与提问', (await text()).includes('今天关心过的事情') && (await text()).includes('回头看，这些时间整体是什么状态？'));
    check('第 2 步：两个目标分组（毕业设计 / 英语，按目标列表顺序）',
      (await evalJs('document.querySelectorAll(".rv-goal").length')) === 2 &&
      (await evalJs('document.querySelectorAll(".rv-goal-name")[0].innerText')) === '毕业设计' &&
      (await evalJs('document.querySelectorAll(".rv-goal-name")[1].innerText')) === '英语');
    check('第 2 步：毕业设计分组 3 笔 / 3h40m，组内按时间排序',
      (await evalJs('document.querySelectorAll(\'.rv-goal[data-goal="g1"] .rv-goal-row\').length')) === 3 &&
      (await evalJs('document.querySelector(\'.rv-goal[data-goal="g1"] .rv-goal-total\').innerText')) === '3h40m' &&
      (await evalJs('document.querySelector(\'.rv-goal[data-goal="g1"] .rv-title\').innerText')) === '写数据库' &&
      (await evalJs('document.querySelectorAll(\'.rv-goal[data-goal="g1"] .rv-title\')[2].innerText')) === '修改首页');
    check('第 2 步：看英文视频 在英语分组且为 不判断',
      (await evalJs('document.querySelector(\'.rv-goal[data-goal="g2"] .rv-title\').innerText')) === '看英文视频' &&
      (await evalJs('document.querySelector(\'[data-action="set-rhythm"][data-id="r18"][data-value="none"]\').getAttribute("aria-checked")')) === 'true');
    check('第 2 步：无目标区使用记录轴呈现（20:10 调整数据库结构 + 弱关联入口）',
      (await evalJs('document.querySelector(".rv-no-goal-label").innerText')) === '没有关联目标的记录' &&
      (await evalJs('document.querySelector(\'.rv-focus[data-id="r17"] .rv-focus-time\').innerText')) === '20:10' &&
      (await evalJs('!!document.querySelector(\'.rv-focus[data-id="r17"] [data-action="link-goal"]\')')));
    check('第 2 步：四个选项 × 5 条 = 20 个按钮', (await evalJs('document.querySelectorAll(".rv-seg button").length')) === 20);
    check('第 2 步：整体推进按钮已删除', (await evalJs('!document.querySelector(\'[data-action="bulk-progress"]\')')));
    await shot('04-step2-goals');
    await evalJs('document.querySelector(".rv-body").scrollTop = 99999');
    await sleep(150);
    await shot('04b-step2-no-goal');
    await evalJs('document.querySelector(".rv-body").scrollTop = 0');
    await sleep(120);

    // 无 Goal 记录点推进 → 询问目标（取消不改变状态）
    await click('[data-action="set-rhythm"][data-id="r17"][data-value="progress"]');
    check('推进询问：标题 推进了哪个目标？', (await text()).includes('推进了哪个目标？'));
    check('推进询问：列出三个目标', (await evalJs('document.querySelectorAll(\'[data-action="goal-pick-set"]\').length')) === 3);
    await shot('05-goal-picker');
    await click('[data-action="sheet-close"]');
    check('推进询问：取消后仍为卡住', (await evalJs('document.querySelector(\'[data-action="set-rhythm"][data-id="r17"][data-value="stuck"]\').getAttribute("aria-checked")')) === 'true');
    check('推进询问：取消后未关联目标', (await evalJs('document.querySelector(\'.rv-focus[data-id="r17"] .rv-focus-goal\')')) === null);

    // 弱关联入口
    await click('[data-action="link-goal"][data-id="r17"]');
    check('弱关联：标题 关联目标', (await text()).includes('关联目标'));
    await click('[data-action="sheet-close"]');

    // 从其他记录中选择 → 散步 → 恢复
    await click('[data-action="open-add-focus"]');
    check('选择记录：面板列出普通记录', (await text()).includes('从今天其他记录中选择') && (await text()).includes('看纪录片'));
    await shot('06-add-focus');
    await click('[data-action="add-focus"][data-id="r11"]');
    check('选择记录：散步加入无目标区（无目标 2 条、总计 6 条关注）',
      (await evalJs('document.querySelectorAll(".rv-focus").length')) === 2 &&
      (await evalJs('document.querySelectorAll(".rv-goal-row").length + document.querySelectorAll(".rv-focus").length')) === 6 &&
      (await bodyText()).includes('散步'));
    await click('[data-action="set-rhythm"][data-id="r11"][data-value="recovery"]');
    check('散步：直接标为恢复（不追问目标）', (await evalJs('document.querySelector(\'[data-action="set-rhythm"][data-id="r11"][data-value="recovery"]\').getAttribute("aria-checked")')) === 'true');
    check('散步：仍无 Goal', (await evalJs('document.querySelector(\'.rv-focus[data-id="r11"] .rv-focus-goal\')')) === null);
    await shot('07-step2-recovery');

    /* ---------------- 第 3 步 ---------------- */
    await click('[data-action="next"]');
    check('第 3 步：标题 今天哪里最难继续', (await text()).includes('今天哪里最难继续'));
    check('第 3 步：两条卡住 + 无选项', (await evalJs('document.querySelectorAll(".rv-choice").length')) === 3);
    check('第 3 步：卡住原因已填', (await evalJs('document.querySelector("#rv-reason").value')) === '不确定 migration 到底应该怎么测试');
    await shot('08-step3-stuck');
    await click('[data-action="stuck-pick"][data-id="none"]');
    check('第 3 步：选“没有特别想记的”隐藏原因框', await evalJs('!document.querySelector("#rv-reason")'));
    await click('[data-action="stuck-pick"][data-id="r12"]');

    /* ---------------- 第 4 步 ---------------- */
    await click('[data-action="next"]');
    let t4 = await bodyText();
    check('第 4 步：今天记录 20h20m / 睡眠 7h05m / 未知 45m / 仍未整理 1h50m',
      t4.includes('20h20m') && t4.includes('7h05m') && t4.includes('45m') && t4.includes('1h50m'));
    check('第 4 步：目标时长 毕业设计 3h40m / 英语 40m', t4.includes('3h40m') && t4.includes('40m'));
    check('第 4 步：推进 写数据库 · 修改首页', t4.includes('写数据库 · 修改首页'));
    check('第 4 步：卡住包含无 Goal 的 调整数据库结构', t4.includes('查 Drift 文档 · 调整数据库结构'));
    check('第 4 步：恢复 散步', t4.includes('散步'));
    check('第 4 步：下次从这里继续', t4.includes('先写一个最小 migration test'));
    await shot('09-step4-summary');
    await evalJs('document.querySelector(".rv-body").scrollTop = 99999');
    await sleep(150);
    await shot('09b-step4-bottom');

    /* ---------------- 完成 → Detail ---------------- */
    await click('[data-action="finish"]');
    let td = await bodyText();
    check('Detail：不再有 Goal 分组卡', (await evalJs('document.querySelectorAll(".rv-goal").length')) === 0);
    check('Detail：扁平记录轴 6 条', (await evalJs('document.querySelectorAll(".rv-detail-focus").length')) === 6);
    check('Detail：写数据库 · 毕业设计 · 推进', td.includes('写数据库') && td.includes('毕业设计 · 推进'));
    check('Detail：调整数据库结构 · 卡住（无 Goal）', td.includes('调整数据库结构') && td.includes('卡住'));
    check('Detail：散步 · 恢复', td.includes('散步') && td.includes('恢复'));
    check('Detail：看英文视频 · 英语 · 不判断', td.includes('看英文视频') && td.includes('英语 · 不判断'));
    check('Detail：单一 编辑节奏 入口', (await evalJs('document.querySelectorAll(\'[data-action="jump"]\').length')) === 3); // 编辑节奏 + 卡住/下一步编辑
    check('Detail：当时卡在哪里 / 下次从这里继续', td.includes('当时卡在哪里') && td.includes('下次从这里继续'));
    await shot('10-detail');
    await evalJs('document.querySelector(".rv-body").scrollTop = 99999');
    await sleep(150);
    await shot('10b-detail-bottom');

    await click('[data-action="menu"]');
    check('Detail：••• 菜单', (await text()).includes('重新整理今天') && (await text()).includes('删除这次回顾'));
    await shot('11-detail-menu');
    await click('[data-action="menu-delete"]');
    check('删除确认对话框', (await text()).includes('删除这次回顾？'));
    await shot('12-delete-confirm');
    await click('[data-action="dialog-cancel"]');
    check('取消删除后 Detail 仍在', (await evalJs("!!document.querySelector('[data-action=\"menu\"]')")));

    await click('[data-action="menu"]');
    await click('[data-action="menu-reflow"]');
    check('重新整理：回到第 1 步且带提示', (await text()).includes('整理今天') && (await text()).includes('正在重新整理'));
    await click('[data-action="back"]');
    check('重新整理：返回 Detail', (await evalJs("!!document.querySelector('[data-action=\"menu\"]')")));

    await click('[data-width="320"]');
    await sleep(200);
    const overflow = await evalJs('(()=>{const b=document.querySelector(".rv-body"); return b.scrollWidth - b.clientWidth;})()');
    check('320 宽：无横向溢出', overflow <= 0, 'overflow ' + overflow);
    await shot('13-detail-320');

    /* ---------------- 第二遍：修改类交互 ---------------- */
    await send('Page.reload', { ignoreCache: true });
    await sleep(1200);
    await evalJs('document.querySelector(".rv-h1")');

    // 推进 → 选目标（完整路径）
    await click('[data-action="next"]');
    await click('[data-action="set-rhythm"][data-id="r17"][data-value="progress"]');
    await click('[data-action="goal-pick-set"][data-goal="g1"]');
    check('推进：选目标后进入毕业设计分组并选中推进',
      (await evalJs('!!document.querySelector(\'.rv-goal[data-goal="g1"] .rv-goal-row[data-id="r17"]\')')) === true &&
      (await evalJs('!!document.querySelector(\'.rv-focus[data-id="r17"]\')')) === false &&
      (await evalJs('document.querySelector(\'[data-action="set-rhythm"][data-id="r17"][data-value="progress"]\').getAttribute("aria-checked")')) === 'true');
    await click('[data-action="set-rhythm"][data-id="r17"][data-value="none"]');
    check('不判断：移除节奏但保留目标（仍在毕业设计分组）',
      (await evalJs('document.querySelector(\'[data-action="set-rhythm"][data-id="r17"][data-value="none"]\').getAttribute("aria-checked")')) === 'true' &&
      (await evalJs('!!document.querySelector(\'.rv-goal[data-goal="g1"] .rv-goal-row[data-id="r17"]\')')) === true);
    await click('[data-action="set-rhythm"][data-id="r17"][data-value="stuck"]');

    // 新建目标 + 推进
    await click('[data-action="open-add-focus"]');
    await click('[data-action="add-focus"][data-id="r19"]');
    await click('[data-action="set-rhythm"][data-id="r19"][data-value="progress"]');
    await click('[data-action="goal-pick-new"]');
    await evalJs("(()=>{document.querySelector('#rv-new-goal-name').value='整理生活';})()");
    await click('[data-action="goal-pick-create"]');
    check('新建目标：整理生活分组 + 推进',
      (await bodyText()).includes('整理生活') &&
      (await evalJs('!!document.querySelector(\'.rv-goal .rv-goal-row[data-id="r19"]\')')) === true &&
      (await evalJs('document.querySelector(\'[data-action="set-rhythm"][data-id="r19"][data-value="progress"]\').getAttribute("aria-checked")')) === 'true');

    // 推进记录的取消关联被拦截
    await click('[data-action="back"]');
    await click('[data-action="open-record"][data-id="r5"]');
    await click('[data-action="sheet-mode"][data-mode="goal"]');
    await click('[data-action="sheet-goal-set"][data-goal=""]');
    check('取消关联：推进记录被拦截并给出说明', (await text()).includes('推进需要目标'));
    await click('[data-action="sheet-mode"][data-mode="view"]');
    await click('[data-action="sheet-close"]');

    // 卡住记录可以自由取消关联
    await click('[data-action="open-record"][data-id="r17"]');
    await click('[data-action="sheet-mode"][data-mode="goal"]');
    await click('[data-action="sheet-goal-set"][data-goal=""]');
    check('取消关联：卡住记录允许（Sheet 回到不关联）', (await evalJs('document.querySelector(".rv-sheet .rv-sheet-kv .rv-muted").innerText')).includes('不关联'));
    await click('[data-action="sheet-close"]');
    await click('[data-action="next"]');
    check('取消关联后：第 2 步回到无目标区（记录轴 + 弱关联入口）',
      (await evalJs('!!document.querySelector(\'.rv-focus[data-id="r17"] [data-action="link-goal"]\')')) === true &&
      (await evalJs('!!document.querySelector(\'.rv-goal .rv-goal-row[data-id="r17"]\')')) === false);

    // 第 2 步弱关联 → 阅读
    await click('[data-action="link-goal"][data-id="r17"]');
    await click('[data-action="goal-pick-set"][data-goal="g3"]');
    check('弱关联：进入阅读分组 + 卡住保持',
      (await evalJs('!!document.querySelector(\'.rv-goal[data-goal="g3"] .rv-goal-row[data-id="r17"]\')')) === true &&
      (await evalJs('document.querySelector(\'[data-action="set-rhythm"][data-id="r17"][data-value="stuck"]\').getAttribute("aria-checked")')) === 'true');

    // Gap 操作
    await click('[data-action="back"]');
    await click('[data-action="gap-unknown"][data-start="670"][data-end="705"]');
    check('Gap 想不起来：缺口 3 → 2', (await evalJs('document.querySelectorAll(".rv-gap").length')) === 2);
    await click('[data-action="gap-later"]');
    check('Gap 先留着：收起', (await evalJs('document.querySelectorAll(".rv-gap-tag").length')) === 1);
    await click('.rv-gap-head');
    check('Gap 先留着：点按再处理', (await evalJs('document.querySelectorAll(".rv-gap-tag").length')) === 0);
    await click('[data-action="gap-new"][data-start="520"][data-end="565"]');
    await evalJs("(()=>{document.querySelector('#rv-new-title').value='整理照片';})()");
    await click('[data-action="sheet-new-save"]');
    check('补记：整理照片进入时间线', (await text()).includes('整理照片'));

    // 记录编辑校验
    await click('[data-action="open-record"][data-id="r12"]');
    await click('[data-action="sheet-mode"][data-mode="time"]');
    await evalJs("(()=>{document.querySelector('#rv-edit-start').value='16:00';document.querySelector('#rv-edit-end').value='15:30';})()");
    await click('[data-action="sheet-time-save"]');
    check('时间编辑：先后颠倒报错', (await text()).includes('开始时间需要早于结束时间'));
    await evalJs("(()=>{document.querySelector('#rv-edit-start').value='14:00';document.querySelector('#rv-edit-end').value='14:30';})()");
    await click('[data-action="sheet-time-save"]');
    check('时间编辑：重叠报错', (await text()).includes('重叠'));
    await click('[data-action="sheet-mode"][data-mode="view"]');
    await click('[data-action="sheet-mode"][data-mode="title"]');
    await evalJs("(()=>{document.querySelector('#rv-edit-title').value='查 Drift 迁移文档';})()");
    await click('[data-action="sheet-title-save"]');
    check('修改事项生效', (await text()).includes('查 Drift 迁移文档'));
    await click('[data-action="sheet-mode"][data-mode="delete"]');
    await click('[data-action="sheet-record-delete"]');
    check('删除记录后从时间线消失', !(await text()).includes('查 Drift 迁移文档'));

    // 无卡住场景
    await evalJs("(()=>{document.querySelector('#rv-nostuck').click();})()");
    await click('[data-action="next"]');
    await click('[data-action="next"]');
    check('无 Stuck 场景：第 3 步空态', (await text()).includes('有什么想留给下次的？'));
    await shot('14-step3-no-stuck');
    await click('[data-action="skip"]');
    const b4 = await bodyText();
    check('无 Stuck 场景：第 4 步无卡住分组', !b4.includes('卡住') && b4.includes('推进'));
    await click('[data-action="finish"]');
    check('第二遍：Detail 生成', (await evalJs("!!document.querySelector('[data-action=\"menu\"]')")));
    await click('[data-action="menu"]');
    await click('[data-action="menu-delete"]');
    await click('[data-action="dialog-confirm"]');
    check('删除回顾：回到第 1 步', (await text()).includes('整理今天'));
    check('删除回顾：时间记录保留', (await bodyText()).includes('早餐'));
    check('全程：整体推进按钮始终不存在', (await evalJs('!document.querySelector(\'[data-action="bulk-progress"]\')')));
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
