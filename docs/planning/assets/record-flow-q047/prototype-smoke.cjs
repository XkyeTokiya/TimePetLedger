'use strict';
// 新建记录原型（Q-047 底部面板版）流程检查
// 运行：JSDOM_PATH=/path/to/node_modules/jsdom node prototype-smoke.cjs
// （或先安装 jsdom：npm i jsdom，再直接 node prototype-smoke.cjs）
const fs = require('fs');
const path = require('path');

let JSDOM;
try { ({ JSDOM } = require('jsdom')); }
catch (e) {
  const p = process.env.JSDOM_PATH;
  if (!p) { console.error('需要 jsdom：npm i jsdom，或设置 JSDOM_PATH=/path/to/node_modules/jsdom'); process.exit(2); }
  ({ JSDOM } = require(p));
}

const html = fs.readFileSync(path.join(__dirname, '..', '..', 'record-flow-q047.html'), 'utf8');
const dom = new JSDOM(html, {
  runScripts: 'dangerously',
  pretendToBeVisual: true,
  beforeParse(window) { window.HTMLElement.prototype.scrollIntoView = function () {}; },
});
const { window } = dom;
const { document } = window;

let passed = 0;
const failures = [];
function ok(cond, msg) { if (cond) passed++; else failures.push(msg); }
function ev(expr) { return window.eval('(' + expr + ')'); }
function $(sel) { return document.querySelector(sel); }
function click(sel) {
  const el = typeof sel === 'string' ? $(sel) : sel;
  if (!el) throw new Error('no element: ' + sel);
  el.click();
}
function clickAction(action) { click('[data-action="' + action + '"]'); }
function scenario(id) { click('[data-action="scenario"][data-id="' + id + '"]'); }
function reset(id) { scenario(id); click('#reset'); }
function type(sel, value) {
  const el = $(sel); if (!el) throw new Error('no input: ' + sel);
  el.value = value;
  el.dispatchEvent(new window.Event('input', { bubbles: true }));
}
function change(sel, value) {
  const el = $(sel); if (!el) throw new Error('no input: ' + sel);
  el.value = value;
  el.dispatchEvent(new window.Event('change', { bubbles: true }));
}
function toggle(id, on) {
  const el = $('#' + id); el.checked = on;
  el.dispatchEvent(new window.Event('change', { bubbles: true }));
}
function cardOpen() { const u = $('#ucard'); return !!u && !u.hidden; }
function recordByTitle(t) { return ev("records().find(r=>r.title===" + JSON.stringify(t) + ")"); }
function flow(name, fn) {
  try { fn(); } catch (err) { failures.push(name + ': EXCEPTION ' + err.message); }
}

/* ---------- 初始渲染 ---------- */
flow('初始', () => {
  ok(document.querySelectorAll('.scenario').length === 5, '五个场景按钮');
  ok($('#head').textContent.includes('10月10日'), '日期行');
  ok($('.coverage').textContent.includes('已交代'), '覆盖统计行');
  ok(!!$('[data-action="new"]') && !!$('[data-action="sleep"]'), '底部两个记录按钮');
  ok(document.querySelectorAll('.tl-block').length === 9, '4 条记录 + 5 段空白');
  ok(!!$('[data-action="gap"][data-start="2026-10-10T14:10"]'), '14:10–15:40 空白可点');
});

/* ---------- A 最短路径：底部记录面板 ---------- */
flow('A 最短路径', () => {
  reset('A');
  click('[data-action="gap"][data-start="2026-10-10T14:10"]');
  const sheet = $('#overlay .sheet');
  ok(!!sheet && sheet.textContent.includes('补记活动'), '记录面板出现');
  const times = [...sheet.querySelectorAll('.ep-time')].map(x => x.textContent);
  ok(times.length === 2 && times[0] === '14:10' && times[1] === '15:40', '顶部直接显示开始 / 结束时间');
  type('#activity', '刷视频');
  clickAction('save');
  ok($('#overlay').innerHTML === '', '保存后面板关闭');
  ok(!$('#activity'), '不再有整页编辑器');
  ok(cardOpen(), '理解层浮层出现');
  ok(!!$('#ucard [data-action="card-close"]'), '目标阶段有 ×');
  clickAction('card-close');
  ok(!cardOpen(), '关闭后浮层消失');
  const r = recordByTitle('刷视频');
  ok(!!r && r.goalId === null && r.annotation === null, '无目标无状态，事实完整');
});

/* ---------- B 完整路径：补充默认折叠 ---------- */
flow('B 完整路径', () => {
  reset('B');
  click('[data-action="gap"][data-start="2026-10-10T14:10"]');
  type('#activity', '改论文');
  clickAction('save');
  ok($('#ucard').textContent.includes('和某个目标有关吗'), '保存后先问目标');
  click('[data-action="pick-goal"][data-id="g1"]');
  ok($('#ucard').textContent.includes('回头看'), '选目标后进入状态问题');
  ok(!$('#ucard [data-action="card-close"]'), '必选状态内部没有 ×');
  click('[data-action="pick-state"][data-value="stuck"]');
  ok(!$('#f-reason'), '“补充说明”默认折叠');
  ok(!$('#f-hint'), '“下次从哪儿接上”默认折叠');
  ok(!!$('[data-action="fold-reason"]') && !!$('[data-action="fold-hint"]'), '两行折叠入口存在');
  clickAction('fold-reason');
  ok(!!$('#f-reason'), '点按后展开补充说明');
  type('#f-reason', '数据库设计一直改来改去');
  clickAction('fold-hint');
  type('#f-hint', '下次先画字段关系图');
  clickAction('card-finish');
  ok(!cardOpen(), '完成后浮层收起');
  const r = recordByTitle('改论文');
  ok(r.goalId === 'g1' && r.annotation.state === 'stuck', '目标与状态写入');
  ok(r.annotation.reasonCode === null && r.annotation.reasonText === '数据库设计一直改来改去', '原因文字写入');
  ok(r.annotation.hint === '下次先画字段关系图', '接续点写入');
  ok($('#record-' + r.id).textContent.includes('毕业设计'), '时间轴行显示目标');
});

/* ---------- 必选边界：不拦截其他入口 ---------- */
flow('必选边界', () => {
  reset('B');
  click('[data-action="gap"][data-start="2026-10-10T14:10"]');
  type('#activity', '边界测试');
  clickAction('save');
  click('[data-action="pick-goal"][data-id="g1"]');
  clickAction('new');
  ok(!!$('#overlay .sheet'), '状态未选也能打开下一笔的记录面板');
  ok(ev('card === null'), '浮层自动收起，不拦截');
  clickAction('record-close');
  ok($('#overlay').innerHTML === '', '收起记录面板');
  const r = recordByTitle('边界测试');
  ok(r.goalId === 'g1' && r.annotation === null, '目标已存、解释未存，事实不受影响');
  click('#record-' + r.id);
  ok($('#head').textContent.includes('记录详情'), '打开详情');
  clickAction('open-card');
  ok(cardOpen() && $('#ucard').textContent.includes('回头看'), '可从详情重新进入状态问题');
  clickAction('card-close');
  ok(recordByTitle('边界测试').annotation === null, '取消不改动');
});

/* ---------- C 想不起来 ---------- */
flow('C 想不起来', () => {
  reset('C');
  click('[data-action="gap"][data-start="2026-10-10T14:10"]');
  clickAction('unknown');
  ok($('#activity').disabled, '选择后输入禁用');
  clickAction('save');
  ok(!cardOpen(), 'Unknown 不弹浮层');
  const r = ev("records().find(r=>r.unknown===true)");
  ok(!!r && r.unknown === true, '落库为 unknown');
});

/* ---------- D 不关联也判断 ---------- */
flow('D 不关联也判断', () => {
  reset('D');
  click('[data-action="gap"][data-start="2026-10-10T14:10"]');
  type('#activity', '整理房间');
  clickAction('save');
  clickAction('card-secondary');
  ok($('#ucard').textContent.includes('回头看') && !!$('#ucard [data-action="card-close"]'), '次级入口可关');
  click('[data-action="pick-state"][data-value="recovery"]');
  change('#f-method', '放空');
  change('#f-quality', '可以继续了');
  clickAction('card-finish');
  const r = recordByTitle('整理房间');
  ok(r.goalId === null && r.annotation.state === 'recovery', '无目标恢复写入');
  ok(r.annotation.method === '放空' && r.annotation.quality === '可以继续了', '方式与感受写入');
});

/* ---------- E 修改已有状态：edit / remove；编辑面板 ---------- */
flow('E 修改已有状态', () => {
  reset('E');
  ok($('#head').textContent.includes('记录详情'), '直接进入详情');
  clickAction('open-card');
  clickAction('card-close');
  ok(ev("findRecord('r2').annotation.state") === 'progress', '取消编辑不改状态');
  clickAction('open-card');
  click('[data-action="pick-state"][data-value="stuck"]');
  clickAction('card-finish');
  ok(ev("findRecord('r2').annotation.state") === 'stuck', '状态更正为卡住');
  clickAction('open-card');
  click('[data-action="pick-state"][data-value="unsure"]');
  const r = ev("findRecord('r2')");
  ok(r.annotation === null && r.goalId === 'g1', '暂时说不清=移除解释、保留事实与目标');
  clickAction('edit-entry');
  ok($('#overlay .sheet').textContent.includes('更正记录'), '详情可打开更正面板');
  clickAction('record-close');
  ok($('#overlay').innerHTML === '', '收起更正面板');
});

/* ---------- 失败路径 ---------- */
flow('失败路径', () => {
  reset('A');
  toggle('fail-save', true);
  click('[data-action="gap"][data-start="2026-10-10T14:10"]');
  type('#activity', '测试失败');
  clickAction('save');
  ok(!!$('#activity'), '事实保存失败留在面板');
  ok($('#form-error').textContent.includes('没有保存成功'), '面板内失败反馈');
  ok($('#activity').value === '测试失败', '输入保留');
  clickAction('save');
  ok($('#overlay').innerHTML === '', '重试成功');
  toggle('fail-anno', true);
  click('[data-action="pick-goal"][data-id="g2"]');
  ok(cardOpen() && $('#ucard').textContent.includes('和某个目标有关吗'), '目标写入失败停留');
  ok(!!$('#ucard .error'), '浮层内错误反馈');
  ok(recordByTitle('测试失败').goalId === null, '事实已保存、目标未写入');
  click('[data-action="pick-goal"][data-id="g2"]');
  ok($('#ucard').textContent.includes('回头看'), '重试后进入状态问题');
  click('[data-action="pick-state"][data-value="unsure"]');
  ok(!cardOpen(), '暂时说不清直接完成');
});

/* ---------- 时间：面板内改端点 + 滚轮 / 日历 ---------- */
flow('时间编辑', () => {
  reset('A');
  click('[data-action="gap"][data-start="2026-10-10T14:10"]');
  type('#activity', '改时间');
  clickAction('wheel-start');
  ok(!!$('[data-action="wheel-item"][data-kind="hour"][data-v="14"]'), '滚轮小时列');
  click('[data-action="wheel-item"][data-kind="hour"][data-v="14"]');
  click('[data-action="wheel-item"][data-kind="min"][data-v="20"]');
  clickAction('wheel-ok');
  const times = [...document.querySelectorAll('.ep-time')].map(x => x.textContent);
  ok(times[0] === '14:20', '滚轮改时间生效并回到记录面板');
  clickAction('wheel-end');
  click('[data-action="wheel-item"][data-kind="hour"][data-v="13"]');
  clickAction('wheel-ok');
  ok($('#sheet-error').textContent.includes('晚于'), '无效时间不应用');
  clickAction('wheel-cancel');
  ok(!!$('#overlay .sheet') && $('#overlay').textContent.includes('补记活动'), '取消滚轮回到记录面板');
  clickAction('cal-start');
  ok($('.cal-month').textContent.includes('2026年10月'), '日历当前月');
  clickAction('cal-prev');
  ok($('.cal-month').textContent.includes('2026年9月'), '上一月');
  clickAction('cal-next');
  click('[data-action="cal-day"][data-d="9"]');
  clickAction('cal-ok');
  ok([...document.querySelectorAll('.ep-date')].some(x => x.textContent === '10月9日'), '日历改日期生效');
  $('#overlay').click();
  ok($('#overlay').innerHTML === '', '点遮罩收起面板');
  click('[data-action="gap"][data-start="2026-10-10T14:10"]');
  const stored = [...document.querySelectorAll('.ep-time')].map(x => x.textContent);
  ok(stored[0] === '14:20', '再次进入恢复会话草稿');
  clickAction('save');
  ok($('#form-error').textContent.includes('重叠'), '跨日重叠在保存时拒绝');
  clickAction('record-close');
  ok($('#overlay').innerHTML === '', '收起草稿面板');
});

/* ---------- 输出 ---------- */
console.log('passed:', passed);
if (failures.length) {
  console.log('FAILURES:');
  failures.forEach(f => console.log(' -', f));
  process.exit(1);
}
console.log('all assertions OK');
