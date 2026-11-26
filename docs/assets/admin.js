(function(){
const {h,$,t,cfg} = ECO;
const S = {user:null, factories:[], reports:[], tab:'dash', f:{factory:'',status:'',sev:'',q:''}, refresh:null, exp:0};
const logoutBtn = h('button',{class:'iconbtn hide',onclick:logout},'');
logoutBtn.dataset.i='logout';
document.getElementById('top').replaceWith(ECO.topbar([logoutBtn]));
const root = document.getElementById('root');

// ---------- auth ----------
function saveSes(j){ S.exp=Date.now()+((j.expires_in||3600)*1000); ECO.token=j.access_token; S.refresh=j.refresh_token||S.refresh;
  localStorage.setItem('eco_ses',JSON.stringify({refresh:S.refresh,uid:j.user&&j.user.id||S.uid})); if(j.user)S.uid=j.user.id; }
async function ensureFresh(){
  if(!ECO.token) return false;
  if(S.exp-Date.now()>120000) return true;
  if(!S.refresh) return false;
  const r=await fetch(cfg.url+'/auth/v1/token?grant_type=refresh_token',{method:'POST',headers:{apikey:cfg.key,'Content-Type':'application/json'},body:JSON.stringify({refresh_token:S.refresh})});
  if(!r.ok) return false; saveSes(await r.json()); return true;
}
async function login(user,pw){
  const r=await fetch(cfg.url+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:cfg.key,'Content-Type':'application/json'},body:JSON.stringify({email:user.trim().toLowerCase()+'@'+cfg.userDomain,password:pw})});
  if(!r.ok) return t('badLogin');
  saveSes(await r.json()); return await loadProfile();
}
async function loadProfile(){
  const r=await ECO.rest(`/rest/v1/profiles?id=eq.${S.uid}&select=username,full_name,role,factory_id`);
  const rows=r.ok?await r.json():[]; const p=rows[0];
  if(!p||p.role!=='admin'){ logout(true); return t('adminsOnly'); }
  S.user=p; return null;
}
function logout(keepMsg){ ECO.token=null; S.user=null; S.refresh=null; localStorage.removeItem('eco_ses'); clearInterval(S.timer); renderLogin(); }
async function restore(){
  try{ const s=JSON.parse(localStorage.getItem('eco_ses')||'null'); if(!s||!s.refresh) return false; S.refresh=s.refresh; S.uid=s.uid; ECO.token='x'; S.exp=0;
    if(!await ensureFresh()){ ECO.token=null; return false; } return (await loadProfile())===null; }catch(_){ return false; }
}

// ---------- data ----------
async function fetchAll(path){
  const out=[]; for(let from=0;;from+=1000){
    const r=await ECO.rest(path,{headers:{Range:`${from}-${from+999}`,'Range-Unit':'items'}});
    if(!r.ok && r.status!==206) throw new Error(path+' '+r.status);
    const rows=await r.json(); out.push(...rows); if(rows.length<1000) break; }
  return out;
}
async function load(){
  await ensureFresh();
  const [fs,rs]=await Promise.all([fetchAll('/rest/v1/factories?select=id,name,logo_url&order=created_at.asc'),fetchAll('/rest/v1/reports?select=*&order=created_at.desc')]);
  S.factories=fs; S.reports=rs;
}
const fname = id => (S.factories.find(f=>f.id===id)||{}).name||'';
const isOverdue = r => r.status!=='Closed' && r.due_date && new Date(r.due_date) < new Date(new Date().toDateString());
const filtered = () => { const q=S.f.q.trim().toLowerCase(); return S.reports.filter(r=>
  (!S.f.factory||r.factory_id===S.f.factory)&&(!S.f.status||r.status===S.f.status)&&(!S.f.sev||r.severity===S.f.sev)&&
  (!q||[r.location,r.type,r.description,r.reporter,r.responsibility,ECO.optText('type',r.type),ECO.optText('location',r.location)].join(' ').toLowerCase().includes(q))); };
const count = (list,key) => { const m={}; for(const r of list){const k=typeof key==='function'?key(r):r[key]; if(k) m[k]=(m[k]||0)+1;} return Object.entries(m).sort((a,b)=>b[1]-a[1]); };

// ---------- views ----------
function renderLogin(msg){
  root.innerHTML=''; logoutBtn.classList.add('hide');
  const err=h('div',{class:'msg err'+(msg?'':' hide')},msg||'');
  const u=h('input',{autocomplete:'username',autocapitalize:'none'}), p=h('input',{type:'password',autocomplete:'current-password'});
  const go=h('button',{class:'btn',type:'submit',style:'width:100%'}); go.dataset.i='login';
  const form=h('form',{class:'card login',onsubmit:async e=>{e.preventDefault(); go.disabled=true; const m=await login(u.value,p.value); go.disabled=false; if(m){err.textContent=m;err.classList.remove('hide');} else start();}},
    h('h2',{'data-i':'adminLogin'}),
    h('div',{class:'field'},h('label',{'data-i':'username'}),u),h('div',{class:'field'},h('label',{'data-i':'password'}),p),err,go);
  root.append(form); ECO.applyLang();
}
async function start(){
  root.innerHTML='<div class="wrap" style="text-align:center"><span class="spin"></span></div>'; logoutBtn.classList.remove('hide');
  try{ await load(); }catch(e){ console.error(e); root.innerHTML=''; root.append(h('div',{class:'wrap'},h('div',{class:'msg err'},t('loadFail')))); return; }
  clearInterval(S.timer); S.timer=setInterval(async()=>{ try{ await load(); render(); }catch(_){} },120000);
  render();
}
function kpi(label,val,cls){ return h('div',{class:'kpi '+(cls||'')},h('b',{},String(val)),h('span',{},label)); }
function bars(entries,kind,max){ const mx=Math.max(1,...entries.map(e=>e[1]));
  const box=h('div'); if(!entries.length) box.append(h('p',{class:'muted'},t('noData')));
  for(const [k,n] of entries.slice(0,max||8)) box.append(h('div',{class:'bar-row'},h('span',{},kind==='factory'?k:ECO.optText(kind,k)||k),h('div',{class:'bar'},h('i',{style:`width:${n/mx*100}%`})),h('b',{},String(n))));
  return box; }
function donut(entries,colorOf,labelOf){ const total=entries.reduce((a,e)=>a+e[1],0)||1; let acc=0; const stops=[];
  for(const [k,n] of entries){ const a=acc/total*100; acc+=n; stops.push(`${colorOf(k)} ${a}% ${acc/total*100}%`); }
  const d=h('div',{style:`width:140px;height:140px;border-radius:50%;background:conic-gradient(${stops.join(',')||'var(--surface-2) 0 100%'});display:grid;place-items:center`},
    h('div',{style:'width:84px;height:84px;border-radius:50%;background:var(--surface);display:grid;place-items:center;font-weight:800;font-size:1.4rem'},String(entries.reduce((a,e)=>a+e[1],0))));
  const lg=h('div',{class:'legend'}); for(const [k,n] of entries) lg.append(h('div',{},h('i',{style:`background:${colorOf(k)}`}),`${labelOf(k)}: ${n}`));
  return h('div',{class:'donut-wrap'},d,lg); }
function monthly(list){ const now=new Date(), keys=[]; for(let i=5;i>=0;i--){ const d=new Date(now.getFullYear(),now.getMonth()-i,1); keys.push(d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')); }
  const m=Object.fromEntries(keys.map(k=>[k,0])); for(const r of list){ const d=new Date(r.created_at); const k=d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0'); if(k in m) m[k]++; }
  const mx=Math.max(1,...Object.values(m)); const box=h('div',{class:'months'});
  for(const k of keys) box.append(h('div',{},h('b',{},String(m[k])),h('i',{style:`height:${m[k]/mx*100}px`}),h('span',{class:'muted'},k.slice(5)+'/'+k.slice(2,4)))); return box; }

function filtersBar(){
  const fs=h('select',{onchange:e=>{S.f.factory=e.target.value;render();}},h('option',{value:'',selected:!S.f.factory},t('allFactories')),...S.factories.map(f=>h('option',{value:f.id,selected:S.f.factory===f.id},f.name)));
  const st=h('select',{onchange:e=>{S.f.status=e.target.value;render();}},h('option',{value:''},t('allStatus')),...ECO.opts.statuses.map(o=>h('option',{value:o.en,selected:S.f.status===o.en},ECO.lang==='en'?o.en:o.ar)));
  const sv=h('select',{onchange:e=>{S.f.sev=e.target.value;render();}},h('option',{value:''},t('allSev')),...ECO.opts.severities.map(o=>h('option',{value:o.en,selected:S.f.sev===o.en},ECO.lang==='en'?o.en:o.ar)));
  const q=h('input',{value:S.f.q,placeholder:t('search'),oninput:e=>{S.f.q=e.target.value; clearTimeout(S.qt); S.qt=setTimeout(()=>{render(); const i=$('#qbox'); if(i){i.focus(); i.setSelectionRange(i.value.length,i.value.length);} },350);},id:'qbox'});
  return h('div',{class:'filters'},fs,st,sv,q); }

function renderDash(list){
  const open=list.filter(r=>r.status==='Open').length, prog=list.filter(r=>r.status==='In progress').length, closed=list.filter(r=>r.status==='Closed').length, od=list.filter(isOverdue).length;
  const wrap=h('div');
  wrap.append(h('div',{class:'kpis'},kpi(t('total'),list.length),kpi(t('open'),open,'red'),kpi(t('inprog'),prog,'orange'),kpi(t('closed'),closed,'green'),kpi(t('overdue'),od,od?'red':'')));
  const topT=count(list,'type')[0], topL=count(list,'location')[0], rate=list.length?Math.round(closed/list.length*100):0;
  const ins=h('div',{class:'card',style:'margin-bottom:14px'},h('h2',{},t('insights')),
    h('p',{},`${t('closeRate')}: ${rate}%`), topT?h('p',{},`${t('topType')}: ${ECO.optText('type',topT[0])} (${topT[1]})`):null,
    topL?h('p',{},`${t('topLoc')}: ${ECO.optText('location',topL[0])} (${topL[1]})`):null, od?h('p',{},`${od} ${t('overdueN')}`):null);
  wrap.append(ins);
  const g=h('div',{class:'grid2'});
  g.append(h('div',{class:'card'},h('h2',{},t('byStatus')),donut(count(list,'status'),ECO.statusColor,k=>t(k))));
  g.append(h('div',{class:'card'},h('h2',{},t('bySeverity')),donut(count(list,'severity'),ECO.sevColor,k=>t(k))));
  g.append(h('div',{class:'card'},h('h2',{},t('monthly')),monthly(list)));
  g.append(h('div',{class:'card'},h('h2',{},t('byFactory')),bars(count(list,r=>fname(r.factory_id)),'factory')));
  g.append(h('div',{class:'card'},h('h2',{},t('byType')),bars(count(list,'type'),'type')));
  g.append(h('div',{class:'card'},h('h2',{},t('byLocation')),bars(count(list,'location'),'location')));
  wrap.append(g); return wrap; }

function badge(txt,color){ return h('span',{class:'badge',style:`background:${color}`},txt); }
function renderTable(list){
  const tb=h('tbody');
  for(const r of list.slice(0,500)){
    tb.append(h('tr',{onclick:()=>openDrawer(r)},
      h('td',{},r.image_url?h('img',{class:'thumb',src:r.image_url,loading:'lazy',alt:''}):''),
      h('td',{},r.factory_no?('#'+r.factory_no):t('newR')),
      h('td',{},ECO.fmtDate(r.created_at)),h('td',{},fname(r.factory_id)),
      h('td',{},ECO.optText('location',r.location)),h('td',{},ECO.optText('type',r.type)),
      h('td',{},badge(t(r.severity)||r.severity,ECO.sevColor(r.severity))),
      h('td',{},badge(t(r.status)||r.status,ECO.statusColor(r.status)),isOverdue(r)?h('span',{style:'color:var(--red);font-weight:700'},' ⚠ '+t('overdue')):null)));
  }
  const head=h('thead',{},h('tr',{},h('th'),...['id','date','factory','location','type','severity','status'].map(k=>h('th',{},t(k)))));
  return h('div',{class:'card tablewrap'},h('table',{},head,tb)); }

function exportCsv(list){
  const cols=['factory_no','created_at','factory','location','type','responsibility','severity','status','description','impacts','reporter','corrective_action','due_date','closed_at','lat','lng','image_url','closed_image_url'];
  const esc=v=>'"'+String(v==null?'':v).replace(/"/g,'""')+'"';
  const rows=[cols.join(',')].concat(list.map(r=>cols.map(c=>esc(c==='factory'?fname(r.factory_id):c==='impacts'?(r.impacts||[]).join('; '):r[c])).join(',')));
  const a=h('a',{href:URL.createObjectURL(new Blob(['\ufeff'+rows.join('\n')],{type:'text/csv;charset=utf-8'})),download:'reports.csv'}); document.body.append(a); a.click(); a.remove(); }

function render(){
  const list=filtered(); root.innerHTML='';
  const pub=location.href.replace(/admin\.html.*$/,'');
  const tabs=h('div',{class:'tabs'},
    h('button',{class:'btn '+(S.tab==='dash'?'':'tonal'),onclick:()=>{S.tab='dash';render();}},t('dashboard')),
    h('button',{class:'btn '+(S.tab==='list'?'':'tonal'),onclick:()=>{S.tab='list';render();}},t('reports')+' ('+list.length+')'),
    h('span',{style:'flex:1'}),
    h('button',{class:'btn outline',onclick:async()=>{await start();}},'⟳ '+t('refresh')),
    h('button',{class:'btn outline',onclick:()=>exportCsv(list)},t('export')));
  const linkBox=h('p',{class:'muted'},t('publicLink')+': ',h('a',{href:pub,target:'_blank'},pub));
  root.append(h('div',{class:'wrap'},tabs,filtersBar(),S.tab==='dash'?renderDash(list):renderTable(list),linkBox));
  ECO.applyLang();
}
document.addEventListener('langchange',()=>{ if(S.user) render(); else renderLogin(); });

// ---------- drawer ----------
function openDrawer(r){
  const st=h('select',{},...ECO.opts.statuses.map(o=>h('option',{value:o.en,selected:r.status===o.en},ECO.lang==='en'?o.en:o.ar)));
  const ca=h('textarea',{},r.corrective_action||''); const due=h('input',{type:'date',value:r.due_date?String(r.due_date).slice(0,10):''});
  const msg=h('div',{class:'msg ok hide'},t('saved')); const err=h('div',{class:'msg err hide'},t('sendFail'));
  const bg=h('div',{class:'drawer-bg',onclick:e=>{if(e.target===bg)bg.remove();}});
  const kv=(k,v)=>[h('b',{},k),h('span',{},v==null||v===''?'-':v)];
  const save=h('button',{class:'btn',onclick:async()=>{
    save.disabled=true; err.classList.add('hide'); msg.classList.add('hide');
    const now=new Date().toISOString(); const body={status:st.value,corrective_action:ca.value,due_date:due.value?new Date(due.value+'T00:00:00').toISOString():null,updated_at:now,closed_at:st.value==='Closed'?(r.closed_at||now):null};
    await ensureFresh();
    const res=await ECO.rest('/rest/v1/reports?id=eq.'+encodeURIComponent(r.id),{method:'PATCH',headers:{'Content-Type':'application/json',Prefer:'return=minimal'},body:JSON.stringify(body)});
    save.disabled=false; if(res.ok){ Object.assign(r,body); msg.classList.remove('hide'); render(); } else err.classList.remove('hide'); }},t('save'));
  const d=h('div',{class:'drawer'},
    h('div',{style:'display:flex;justify-content:space-between;align-items:center'},h('h2',{},(r.factory_no?'#'+r.factory_no+' ':'')+ECO.optText('type',r.type)),h('button',{class:'btn outline',onclick:()=>bg.remove()},t('close'))),
    r.image_url?h('div',{},h('b',{},t('before')),h('img',{class:'big',src:r.image_url,alt:''})):null,
    r.closed_image_url?h('div',{},h('b',{},t('after')),h('img',{class:'big',src:r.closed_image_url,alt:''})):null,
    h('div',{class:'kv'},...kv(t('factory'),fname(r.factory_id)),...kv(t('date'),ECO.fmtDate(r.created_at)),...kv(t('location'),ECO.optText('location',r.location)),
      ...kv(t('resp'),ECO.optText('resp',r.responsibility)),...kv(t('severity'),t(r.severity)),...kv(t('impacts'),(r.impacts||[]).map(i=>ECO.optText('impacts',i)).join('، ')),
      ...kv(t('reporter'),r.reporter),...kv(t('source'),r.submitted_via==='web'?t('srcWeb'):t('srcApp')),...kv(t('desc'),r.description)),
    r.lat!=null&&r.lng!=null?h('p',{},h('a',{href:`https://maps.google.com/?q=${r.lat},${r.lng}`,target:'_blank',rel:'noopener'},'📍 '+t('map'))):null,
    h('div',{class:'field'},h('label',{},t('status')),st),h('div',{class:'field'},h('label',{},t('due')),due),h('div',{class:'field'},h('label',{},t('corrective')),ca),msg,err,save);
  bg.append(d); document.body.append(bg); }

(async()=>{ ECO.applyLang(); if(await restore()) start(); else renderLogin(); })();
})();
