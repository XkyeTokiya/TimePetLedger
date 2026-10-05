const ICONS={"target": "<svg\n  xmlns=\"http://www.w3.org/2000/svg\"\n  width=\"24\"\n  height=\"24\"\n  viewBox=\"0 0 24 24\"\n  fill=\"none\"\n  stroke=\"currentColor\"\n  stroke-width=\"2\"\n  stroke-linecap=\"round\"\n  stroke-linejoin=\"round\"\n>\n  <circle cx=\"12\" cy=\"12\" r=\"10\" />\n  <circle cx=\"12\" cy=\"12\" r=\"6\" />\n  <circle cx=\"12\" cy=\"12\" r=\"2\" />\n</svg>\n", "activity": "<svg\n  xmlns=\"http://www.w3.org/2000/svg\"\n  width=\"24\"\n  height=\"24\"\n  viewBox=\"0 0 24 24\"\n  fill=\"none\"\n  stroke=\"currentColor\"\n  stroke-width=\"2\"\n  stroke-linecap=\"round\"\n  stroke-linejoin=\"round\"\n>\n  <path d=\"M22 12h-2.48a2 2 0 0 0-1.93 1.46l-2.35 8.36a.25.25 0 0 1-.48 0L9.24 2.18a.25.25 0 0 0-.48 0l-2.35 8.36A2 2 0 0 1 4.49 12H2\" />\n</svg>\n", "chevron-right": "<svg\n  xmlns=\"http://www.w3.org/2000/svg\"\n  width=\"24\"\n  height=\"24\"\n  viewBox=\"0 0 24 24\"\n  fill=\"none\"\n  stroke=\"currentColor\"\n  stroke-width=\"2\"\n  stroke-linecap=\"round\"\n  stroke-linejoin=\"round\"\n>\n  <path d=\"m9 18 6-6-6-6\" />\n</svg>\n", "chevron-up": "<svg\n  xmlns=\"http://www.w3.org/2000/svg\"\n  width=\"24\"\n  height=\"24\"\n  viewBox=\"0 0 24 24\"\n  fill=\"none\"\n  stroke=\"currentColor\"\n  stroke-width=\"2\"\n  stroke-linecap=\"round\"\n  stroke-linejoin=\"round\"\n>\n  <path d=\"m18 15-6-6-6 6\" />\n</svg>\n", "check": "<svg\n  xmlns=\"http://www.w3.org/2000/svg\"\n  width=\"24\"\n  height=\"24\"\n  viewBox=\"0 0 24 24\"\n  fill=\"none\"\n  stroke=\"currentColor\"\n  stroke-width=\"2\"\n  stroke-linecap=\"round\"\n  stroke-linejoin=\"round\"\n>\n  <path d=\"M20 6 9 17l-5-5\" />\n</svg>\n", "clock": "<svg\n  xmlns=\"http://www.w3.org/2000/svg\"\n  width=\"24\"\n  height=\"24\"\n  viewBox=\"0 0 24 24\"\n  fill=\"none\"\n  stroke=\"currentColor\"\n  stroke-width=\"2\"\n  stroke-linecap=\"round\"\n  stroke-linejoin=\"round\"\n>\n  <circle cx=\"12\" cy=\"12\" r=\"10\" />\n  <path d=\"M12 6v6l4 2\" />\n</svg>\n"};
function icon(name,className="icon"){return ICONS[name].replace("<svg",`<svg class="${className}" aria-hidden="true"`)}
const $=id=>document.getElementById(id),esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const reasons=['任务太大','不知道下一步','困','脑雾','焦虑','被打断','说不清','其他'],ways=['散步','吃饭','洗澡','放空','娱乐','切换任务','拆小任务','寻求帮助','其他'],feelings=['没缓过来','缓过来一些','可以继续了'];
const seedGoals=()=>[{id:'g1',name:'阅读与写作',meta:'创建于 10月1日'},{id:'g2',name:'读书',meta:'创建于 9月12日'},{id:'g3',name:'读书',meta:'创建于 8月20日 · 已归档',archived:true},{id:'g5',name:'读书',meta:'创建于 10月2日'},{id:'g4',name:'整理关于城市、散步与日常生活的长篇阅读笔记，留下一些自己的观察',meta:'创建于 9月30日'}];
let d,goals,expanded='rhythm',status='',modal='',temp,errors={},goalName='',goalError='',pendingGoal=null,busy=false,kb=0,saved=false,candidates=false,clockEnd='',screen='edit',draftText='草稿仅保存在此浏览器';let saveTimer=null,revision=0;
const base=()=>({memory:'记得',title:'',start:'2026-10-05 10:30',end:'2026-10-05 11:15',sp:'大约',ep:'大约',goal:null,rhythm:'',reason:'',reasonText:'',way:'',feeling:'',continuation:'',note:''});
function normalizeDraft(value) {
  const result = base();
  if (!value || typeof value !== 'object') return result;
  for (const key of Object.keys(result)) {
    if (key !== 'goal' && typeof value[key] === 'string') result[key] = value[key];
  }
  result.memory = value.memory === '想不起来' ? '想不起来' : '记得';
  if (value.goal && typeof value.goal.id === 'string' && typeof value.goal.name === 'string') result.goal = value.goal;
  if (!['推进','卡住','恢复'].includes(result.rhythm)) result.rhythm = '';
  return result;
}
function persist(){if(saved)return;try{localStorage.setItem('tpl-editor-v2-demo',JSON.stringify(d));draftText='演示草稿已保存在此浏览器'}catch{draftText='草稿保存失败 · 请勿关闭页面'}let e=$('draftStatus');if(e)e.textContent=draftText}
function update(key,value){d[key]=value;persist()}
function field(key,label,placeholder='',type='textarea'){return `<label class="field" for="${key}">${label}<span class="optional">选填</span></label><${type} id="${key}" oninput="update('${key}',this.value)" placeholder="${placeholder}">${type==='textarea'?esc(d[key]):''}</${type}>`}
function chips(values, key) {
  return `<div class="chips ${key === 'rhythm' ? 'rhythm-choices' : ''}">${values.map(value =>
    `<button aria-pressed="${d[key] === value}" class="${d[key] === value ? 'selected' : ''}"
      onclick="toggle('${key}','${value}')">${d[key] === value ? icon('check') : ''}${value}</button>`
  ).join('')}</div>`;
}
function toggle(key,v){d[key]=d[key]===v?'':v;persist();render()}
function expand(which){expanded=expanded===which?'':which;render()}
function timeText(){return d.start&&d.end?`${esc(d.start.slice(11))} → ${esc(d.end.slice(11))}`:'填写开始与结束'}
function parse(v){let m=/^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})$/.exec(v);if(!m)return null;let [y,mo,da,h,mi]=m.slice(1).map(Number),dt=new Date(y,mo-1,da,h,mi);return dt.getFullYear()===y&&dt.getMonth()===mo-1&&dt.getDate()===da&&h<24&&mi<60?dt:null}
function duration(){let s=parse(d.start),e=parse(d.end);return s&&e?`${Math.round((e-s)/60000)}分钟`:''}
function overlap(){let s=parse(d.start),e=parse(d.end);return s&&e?Math.max(0,(Math.min(+e,+parse('2026-10-05 11:30'))-Math.max(+s,+parse('2026-10-05 11:00')))/60000):0}
function notice(){if(status==='conflict')return `<div class="notice" role="alert"><b>这段时间与已有记录重叠</b><p>阅读设计资料<br>10月5日 11:00–11:30<br>重叠：${overlap()}分钟</p><button onclick="openTime()">调整当前记录时间</button></div>`;if(status==='failure')return `<div class="notice" role="alert"><b>未能保存记录</b><p>输入已保留。可以再次尝试。</p></div>`;return ''}
function render() {
  const scroll = $('app').querySelector('main')?.scrollTop || 0;
  if (screen === 'exit') {
    $('app').innerHTML = `<header><h2>时间账本</h2></header><main class="success">
      <div class="eyebrow">最小返回背景</div><h2>${saved ? '这段时间，记下了。' : '稍后再记也可以。'}</h2>
      <p>${saved ? esc(d.memory === '记得' ? d.title : '想不起来') : '活动编辑已退出'}</p>
      <button class="primary" onclick="resume()">${saved ? '新建另一条活动' : '返回活动编辑'}</button></main>`;
    return;
  }
  if (status === 'missing') {
    $('app').innerHTML = `<header><h2>无法继续更正</h2></header><main>
      <div class="notice"><b>原记录已不存在</b><p>这份编辑草稿无法再保存到原记录。</p></div>
      <p>你可以退出，或清理这份编辑草稿。</p>
      <button class="goal" onclick="persist();leave()">保留草稿并退出</button>
      <button class="goal" onclick="clearDraft()">清理编辑草稿并退出</button><div id="clearError" role="alert"></div></main>`;
    return;
  }
  if (saved) {
    $('app').innerHTML = `<header><h2>记录已保存</h2></header><main class="success">
      <div class="eyebrow">${esc(d.start)} — ${esc(d.end)}</div>
      <h2>${esc(d.memory === '记得' ? d.title : '想不起来')}</h2>
      <p>${status === 'finalize' ? '已保存，等待刷新账本。' : status === 'cleanup' ? '已保存，等待清理编辑草稿。' : '这段时间已记入账本。'}</p>
      ${status ? `<div class="notice">不会重复创建记录。<button onclick="finish()">${status === 'cleanup' ? '重试清理草稿' : '重试刷新账本'}</button></div>` : ''}
      </main><div class="footer"><button class="primary" onclick="leave()">返回账本</button></div>`;
    return;
  }
  const unknown = d.memory === '想不起来';
  $('app').innerHTML = `<header class="editor-header">
    <button class="plain" onclick="openExit()">取消</button><h2>记录活动</h2><span aria-hidden="true"></span>
  </header><main class="editor-body">
    <div class="segment memory-choices" aria-label="记忆状态">${['记得','想不起来'].map(value =>
      `<button aria-pressed="${d.memory === value}" class="${d.memory === value ? 'selected' : ''}"
        onclick="update('memory','${value}');render()">${d.memory === value ? icon('check') : ''}${value}</button>`
    ).join('')}</div>
    <div class="activity-field ${unknown ? 'is-unknown' : ''}">
      <label class="field" for="title">我做了什么</label>
      <div class="activity-input"><textarea id="title" rows="1" ${unknown ? 'disabled aria-label="活动内容已保留，切回记得后可编辑"' : ''}
        placeholder="写下这段时间的活动" oninput="update('title',this.value);sizeActivity()">${esc(d.title)}</textarea></div>
      ${errors.title && !unknown ? `<div class="error" role="alert">${errors.title}</div>` : ''}
    </div>
    ${timeSummary()}
    ${errors.time ? `<div class="error" role="alert">${errors.time}</div>` : ''}${notice()}
    <section class="section goal-section">
      <button class="section-trigger" aria-expanded="${expanded === 'goal'}" onclick="expand('goal')">
        ${icon('target','section-icon')}<span class="section-label">目标<span class="optional">选填</span></span>
        <span class="inline-summary">${d.goal ? esc(d.goal.name) + (d.goal.archived ? ' · 已归档' : '') : ''}</span>
        ${icon(expanded === 'goal' ? 'chevron-up' : 'chevron-right','chevron')}
      </button>${expanded === 'goal' ? goalDetails() : ''}
    </section>
    <section class="section rhythm-section">
      <button class="section-trigger" aria-expanded="${expanded === 'rhythm'}" onclick="expand('rhythm')">
        ${icon('activity','section-icon')}<span class="section-label">节奏<span class="optional">选填</span></span>
        <span class="inline-summary">${expanded !== 'rhythm' ? esc([d.rhythm,d.continuation ? '有接续点' : ''].filter(Boolean).join(' · ')) : ''}</span>
        ${icon(expanded === 'rhythm' ? 'chevron-up' : 'chevron-right','chevron')}
      </button>${expanded === 'rhythm' ? rhythmDetails() : ''}
    </section>
    <div class="note-field">${field('note','补充内容','还有想记下的事')}</div>
    <div id="textError" class="error" role="alert">${errors.text || ''}</div>
  </main><div class="footer">
    <button class="primary" ${busy ? 'disabled' : ''} onclick="save()">${busy ? '正在保存…' : status === 'failure' ? '重试保存' : '保存活动'}</button>
    <div class="draft" id="draftStatus">${draftText}</div>
  </div>`;
  sizeActivity();$('app').querySelector('main').scrollTop = scroll;
}

function sizeActivity() {
  const input = $('title');
  if (!input) return;
  input.style.height = '48px';
  const height = Math.max(48, input.scrollHeight);
  input.style.height = height + 'px';
  input.closest('.activity-field').style.height = (height + 36) + 'px';
}

function timeSummary() {
  const date = d.start ? shortDate(d.start) + (d.start.slice(0,10) !== d.end.slice(0,10) ? ' → ' + shortDate(d.end) : '') : '日期与时间';
  const content = `<span class="date">${date}</span><div class="time-values"><strong>${candidates ? '选择时间区间' : timeText()}</strong><span class="duration">${duration()}</span></div>`;
  return `<div class="time">${status === 'conflict' ? `<div class="time-static">${content}</div>` :
    `<button class="time-trigger" aria-label="编辑日期与时间" onclick="${candidates ? 'openCandidates()' : 'openTime()'}">${content}</button>`}</div>`;
}

function shortDate(value) {
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(value);
  return match ? `${Number(match[2])}月${Number(match[3])}日` : esc(value);
}

function goalDetails() {
  return `<div class="detail">
    ${d.goal ? `<button class="goal" onclick="d.goal=null;persist();render()">解除当前关联</button>` : ''}
    ${goals.length ? goals.filter(goal => !goal.archived || d.goal?.id === goal.id).map(goal =>
      `<button class="goal ${d.goal?.id === goal.id ? 'selected' : ''}" onclick="selectGoal('${goal.id}')">
        ${d.goal?.id === goal.id ? icon('check') : ''}${esc(goal.name)}<small>${esc(goal.meta)}</small></button>`
    ).join('') : `<div class="empty"><h3>还没有目标</h3><p>给想投入时间的事起个名字。</p></div>`}
    <button class="goal" onclick="openCreate()">创建目标</button></div>`;
}

function rhythmDetails() {
  return `<div class="detail">
    ${chips(['推进','卡住','恢复'],'rhythm')}
    ${d.rhythm === '卡住' ? `<label class="field">卡在哪里<span class="optional">选填 · 单选</span></label>
      ${chips(reasons,'reason')}${field('reasonText','具体发生了什么','只写文字也可以')}` : ''}
    ${d.rhythm === '恢复' ? `<label class="field">做了什么<span class="optional">选填 · 单选</span></label>
      ${chips(ways,'way')}<label class="field">恢复感受<span class="optional">选填 · 单选</span></label>
      ${chips(feelings,'feeling')}` : ''}
    ${d.rhythm ? field('continuation','接续点','下次回来，可以从哪里接上？') : ''}</div>`;
}

function selectGoal(id){d.goal=goals.find(g=>g.id===id);persist();expanded='rhythm';render()}
function shell(title,content,action,label='应用'){ $('app').inert=true; $('overlay').innerHTML=`<div class="scrim" onclick="if(event.target===this)closeModal()"><section class="sheet" role="dialog" aria-modal="true" aria-label="${title}"><div class="handle"></div><header><button class="plain" onclick="closeModal()">返回</button><h2>${title}</h2><button class="plain" onclick="closeModal()">取消</button></header><div class="sheet-content">${content}</div>${action?`<div class="footer"><button class="primary" onclick="${action}">${label}</button></div>`:''}</section></div>`;applyKeyboard()}
function openTime(){temp={start:d.start,end:d.end,sp:d.sp,ep:d.ep};errors={};modal='time';renderTime()}
const clockIcon=icon('clock');
function renderTime(){shell('日期与时间',`<p class="small">日期可直接修改 · 时钟只选择时分</p>${[['start','开始','sp'],['end','结束','ep']].map(([key,label,p])=>`<div class="endpoint"><label class="field" for="${key}">${label}</label><div class="row"><input id="${key}" aria-invalid="${!!errors[key]}" placeholder="年-月-日 时:分" value="${esc(temp[key])}" oninput="temp.${key}=this.value"><button class="clock" aria-label="选择${label}时分" onclick="openClock('${key}')">${clockIcon}</button></div>${errors[key]?`<div class="error" role="alert">${errors[key]}</div>`:''}<div class="segment precision">${['准确','大约'].map(v=>`<button aria-pressed="${temp[p]===v}" class="${temp[p]===v?'selected':''}" onclick="temp.${p}='${v}';renderTime()">${temp[p]===v?icon('check'):''}${v}</button>`).join('')}</div></div>`).join('')}`,'applyTime()')}
function applyTime(){errors={};let s=parse(temp.start),e=parse(temp.end);if(!s)errors.start='请输入有效日期和时间，例如 2026-10-05 10:30';if(!e)errors.end='请输入有效日期和时间，例如 2026-10-05 11:15';if(s&&e&&e<=s)errors.end='结束时间需要晚于开始时间';if(Object.keys(errors).length){renderTime();return}Object.assign(d,temp);candidates=false;if(status==='conflict'){if(!overlap())$('response').value='success';status=''}persist();closeModal();render()}
function openClock(key){clockEnd=key;modal='clock';let m=/(\d{2}):(\d{2})$/.exec(temp[key]);shell('选择'+(key==='start'?'开始':'结束')+'时分',`<p class="small">日期保持 ${esc(temp[key].slice(0,10)||'未填写')}；日期可返回手动填写。</p><div class="picker"><label>时<select id="hour">${Array.from({length:24},(_,i)=>`<option ${Number(m?.[1]||0)===i?'selected':''}>${String(i).padStart(2,'0')}</option>`).join('')}</select></label><label>分<select id="minute">${Array.from({length:60},(_,i)=>`<option ${Number(m?.[2]||0)===i?'selected':''}>${String(i).padStart(2,'0')}</option>`).join('')}</select></label></div>`,'applyClock()','确定时分')}
function applyClock(){temp[clockEnd]=(temp[clockEnd].slice(0,10)||'')+' '+$('hour').value+':'+$('minute').value;modal='time';renderTime()}
function closeModal(){if(modal==='clock'){modal='time';renderTime();return}modal='';$('app').inert=false;$('overlay').innerHTML='';setKeyboard(0)}
function openCandidates(){modal='candidates';shell('选择时间区间',`<p>10月5日 · 请确认要记录的区间</p>${[['09:00','09:40'],['10:30','11:15']].map(([s,e])=>`<button class="goal" onclick="d.start='2026-10-05 ${s}';d.end='2026-10-05 ${e}';candidates=false;persist();closeModal();render()">${s} → ${e}</button>`).join('')}<button class="goal" onclick="openTime()">手动填写时间</button>`)}
function openCreate(){if(!pendingGoal){goalName='';goalError='';}modal='create';renderCreate()}
function renderCreate(){shell('创建目标',`<label class="field" for="goalName">目标名称</label><textarea id="goalName" ${pendingGoal?'readonly':''} placeholder="例如：整理阅读笔记" oninput="goalName=this.value">${esc(goalName)}</textarea><p class="small">目标只表示时间归属，不需要设置进度。</p>${goalError?`<div class="notice" role="alert">${goalError}</div>`:''}`,pendingGoal?'retryGoalRead()':'createGoal()',pendingGoal?'重试读取并关联':'创建并关联')}
function createGoal(){if(!goalName.trim()||[...goalName.trim()].length>200){goalError='请输入 1–200 字的目标名称';renderCreate();return}if($('goalResponse').value==='failure'){goalError='创建失败，名称已保留，请重试。';$('goalResponse').value='success';renderCreate();return}pendingGoal={id:'g'+Date.now(),name:goalName.trim(),meta:'刚刚创建'};goals.push(pendingGoal);try{localStorage.setItem('tpl-editor-v2-goals',JSON.stringify(goals));localStorage.setItem('tpl-editor-v2-pending-goal',JSON.stringify(pendingGoal))}catch{}if($('goalResponse').value==='readfail'){goalError='目标已创建，暂时无法读取。关联意图已保留，重试不会再次创建。';renderCreate();return}retryGoalRead()}
function retryGoalRead(){if(!pendingGoal)return;d.goal=pendingGoal;pendingGoal=null;try{localStorage.removeItem('tpl-editor-v2-pending-goal')}catch{}persist();closeModal();expanded='rhythm';render()}
function save() {
  if (busy || saved) return;
  errors = {};
  if (d.memory === '记得' && !d.title.trim()) errors.title = '写下活动内容，或选择“想不起来”';
  if (!parse(d.start) || !parse(d.end) || parse(d.end) <= parse(d.start)) errors.time = '请补全有效的开始与结束时间';
  const longKeys = ['note', ...(d.rhythm ? ['continuation'] : []), ...(d.rhythm === '卡住' ? ['reasonText'] : [])];
  if ((d.memory === '记得' && [...d.title.trim()].length > 200) || longKeys.some(key => [...d[key].trim()].length > 2000)) errors.text = '活动内容最多200字，其他文字最多2000字。';
  if (Object.keys(errors).length) {
    if (errors.text && d.rhythm) expanded = 'rhythm';
    render(); $('app').querySelector('main').scrollTop = 0; return;
  }
  busy = true;
  const token = revision, response = $('response').value;
  render();
  saveTimer = setTimeout(() => {
    if (token !== revision) return;
    busy = false; saveTimer = null; status = response;
    if (status === 'conflict' && !overlap()) status = 'success';
    if (status === 'failure') $('response').value = 'success';
    if (['success','finalize','cleanup'].includes(status)) {
      saved = true; status = status === 'success' ? '' : status;
      try {
        localStorage.setItem('tpl-editor-v2-finalize',JSON.stringify({d,status}));
        localStorage.setItem('tpl-editor-v2-saved',JSON.stringify(d));
        if (status !== 'cleanup') localStorage.removeItem('tpl-editor-v2-demo');
      } catch { status = 'cleanup'; }
    }
    render(); $('app').querySelector('main').scrollTop = 0;
  },650);
}

function finish() {
  status = '';
  try {
    localStorage.removeItem('tpl-editor-v2-finalize');
    localStorage.removeItem('tpl-editor-v2-demo');
  } catch { status = 'cleanup'; }
  render();
}

function openExit(){modal='exit';shell('离开活动编辑？',`<p>可以保留草稿，稍后继续。</p><button class="goal" onclick="persist();closeModal();leave()">保留草稿并退出</button><button class="goal" onclick="clearDraft()">放弃草稿并退出</button><div id="clearError" role="alert"></div>`)}
function clearDraft(){if($('clearFail').checked){$('clearError').innerHTML='<div class="notice">草稿清理失败，输入仍保留。<button onclick="document.getElementById(\'clearFail\').checked=false;clearDraft()">重试清理</button></div>';return}try{localStorage.removeItem('tpl-editor-v2-demo')}catch{$('clearError').textContent='浏览器无法清理草稿，请重试';return}closeModal();d=base();status='';saved=false;leave()}
function leave(){screen='exit';render()}function resume(){screen='edit';if(saved){try{localStorage.removeItem('tpl-editor-v2-finalize')}catch{}reset('simple')}else render()}
function setKeyboard(n){kb=Number(n);$('keyboard').value=String(kb);applyKeyboard()}
function applyKeyboard(){$('mockKeyboard').hidden=!kb;$('mockKeyboard').style.height=kb+'px';$('overlay').style.bottom=kb+'px';$('app').style.paddingBottom=modal?'0':kb+'px'}
function reset(scene){revision++;clearTimeout(saveTimer);temp=null;pendingGoal=null;goalError='';draftText='草稿仅保存在此浏览器';d=base();goals=seedGoals();expanded='rhythm';status='';saved=false;busy=false;modal='';screen='edit';errors={};candidates=false;closeModal();$('response').value='conflict';if(scene!=='simple'&&!['none','candidates','empty'].includes(scene))d.title='整理阅读笔记';if(['goal','stuck','recovery'].includes(scene))d.goal=goals[0];if(['stuck','recovery'].includes(scene)){expanded='rhythm';d.rhythm=scene==='stuck'?'卡住':'恢复';d.reason='不知道下一步';d.reasonText='资料很多，还没找到组织顺序。';d.continuation='下次先列出三个小标题。';d.way='散步';d.feeling='缓过来一些'}if(scene==='unknown'){d.memory='想不起来';d.title='整理阅读笔记'}if(scene==='visual')d.title='整理阅读笔记';if(scene==='archived'){d.goal=goals[2];expanded='goal'}if(scene==='empty'){goals=[];expanded='goal'}if(['none','candidates'].includes(scene)){d.start='';d.end='';candidates=scene==='candidates'}if(['conflict','failure','missing'].includes(scene))status=scene;if(scene==='failure')$('response').value='success';if(scene==='finalize'){saved=true;status='finalize'}if(scene==='draft'){try{d=normalizeDraft(JSON.parse(localStorage.getItem('tpl-editor-v2-demo')))||{...base(),memory:'想不起来',start:'2026-10-04 23:30',end:'2026-10-05 00:10'}}catch{d=base()}draftText='已恢复草稿 · 新建议未覆盖'}render();if($('app').querySelector('main'))$('app').querySelector('main').scrollTop=0;if(['time','keyboard'].includes(scene))openTime();if(scene==='keyboard')setKeyboard(220)}
$('scene').onchange=e=>{try{localStorage.removeItem('tpl-editor-v2-finalize')}catch{}try{localStorage.removeItem('tpl-editor-v2-pending-goal')}catch{}reset(e.target.value)};$('width').onchange=e=>{$('phone').style.width=e.target.value+'px';document.querySelector('.caption').textContent=`活动编辑 / ${e.target.value} × 800`};$('keyboard').onchange=e=>setKeyboard(e.target.value);document.addEventListener('keydown',e=>{if(e.key==='Escape'&&modal)closeModal();if(e.key==='Tab'&&modal){let nodes=[...$('overlay').querySelectorAll('button,input,textarea,select')],first=nodes[0],last=nodes.at(-1);if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus()}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus()}}});reset('simple');try{let existing=localStorage.getItem('tpl-editor-v2-demo');if(existing){d=normalizeDraft(JSON.parse(existing));draftText='已恢复上次演示草稿';render()}}catch{}

try{let record=JSON.parse(localStorage.getItem('tpl-editor-v2-finalize'));if(record){d=normalizeDraft(record.d);saved=true;status=record.status;render()}}catch{}

document.addEventListener('focusin',e=>{if(modal&&e.target.matches('input,textarea,select'))e.target.scrollIntoView({block:'nearest'})});

// URL scene parameters are only development controls for exact viewport QA.
const query = new URLSearchParams(location.search);
if (query.has('scene')) reset(query.get('scene'));
if (query.has('keyboard')) setKeyboard(query.get('keyboard'));

try {
  const storedGoals = JSON.parse(localStorage.getItem('tpl-editor-v2-goals'));
  if (Array.isArray(storedGoals)) goals = storedGoals.filter(goal => goal && typeof goal.id === 'string' && typeof goal.name === 'string');
  const pending = JSON.parse(localStorage.getItem('tpl-editor-v2-pending-goal'));
  if (pending && typeof pending.id === 'string' && typeof pending.name === 'string' && !saved) {
    pendingGoal = pending; goalName = pending.name;
    goalError = '目标已创建，暂时无法读取。关联意图已保留，重试不会再次创建。';
    modal = 'create'; renderCreate();
  }
} catch {}
