(function(){
const {h,$,t,cfg,opts} = ECO;
document.getElementById('top').replaceWith(ECO.topbar());
let factory=null, sev='Medium', imps=new Set(), lat=null, lng=null, blob=null, factories=[];

function fillSelect(id, kind){
  const s=$('#'+id), cur=s.value; s.innerHTML='';
  s.append(h('option',{value:''},t('select')));
  for(const o of opts[kind]) s.append(h('option',{value:o.en},ECO.lang==='en'?o.en:o.ar));
  s.append(h('option',{value:'__other'},t('other')));
  s.value=cur;
}
function renderStatic(){
  fillSelect('location','location'); fillSelect('type','type'); fillSelect('resp','resp');
  const sc=$('#sev'); sc.innerHTML='';
  for(const o of opts.severities) sc.append(h('span',{class:'chip'+(sev===o.en?' on':''),onclick:()=>{sev=o.en;renderStatic();}},ECO.lang==='en'?o.en:o.ar));
  const ic=$('#imp'); ic.innerHTML='';
  for(const o of opts.impacts) ic.append(h('span',{class:'chip'+(imps.has(o.en)?' on':''),onclick:()=>{imps.has(o.en)?imps.delete(o.en):imps.add(o.en);renderStatic();}},ECO.lang==='en'?o.en:o.ar));
  renderFactories(); ECO.applyLang();
}
function renderFactories(){
  const g=$('#factories'); g.innerHTML='';
  for(const f of factories){
    g.append(h('div',{class:'factory-tile'+(factory===f.id?' on':''),onclick:()=>{factory=f.id;renderFactories();}},
      f.logo_url?h('img',{src:f.logo_url,alt:''}):h('span',{class:'logo-ph'}), f.name));
  }
}
for(const id of ['location','type','resp']){
  $('#'+id).addEventListener('change',e=>$('#'+id+'_o').classList.toggle('hide',e.target.value!=='__other'));
}
document.addEventListener('langchange',renderStatic);
renderStatic();
ECO.rest('/rest/v1/factories?select=id,name,logo_url&order=created_at.asc').then(r=>r.json()).then(j=>{factories=Array.isArray(j)?j:[];if(factories.length===1)factory=factories[0].id;renderFactories();}).catch(()=>{$('#factories').textContent=t('loadFail');});

$('#photo').addEventListener('change',async e=>{
  const f=e.target.files[0]; if(!f) return;
  try{ blob=await shrink(f); const url=URL.createObjectURL(blob); $('#prev').src=url; $('#prev').classList.remove('hide'); $('#dropTxt').classList.add('hide'); }
  catch(_){ blob=null; showErr(t('sendFail')); }
});
function shrink(file){ return new Promise((res,rej)=>{
  const img=new Image(); img.onload=()=>{
    const max=1600, k=Math.min(1,max/Math.max(img.width,img.height));
    const c=document.createElement('canvas'); c.width=Math.round(img.width*k); c.height=Math.round(img.height*k);
    c.getContext('2d').drawImage(img,0,0,c.width,c.height);
    c.toBlob(b=>b?res(b):rej(new Error('blob')),'image/jpeg',0.82); };
  img.onerror=rej; img.src=URL.createObjectURL(file); }); }
$('#geo').addEventListener('click',()=>{
  if(!navigator.geolocation) return;
  $('#geoMsg').textContent=' ...';
  navigator.geolocation.getCurrentPosition(p=>{lat=p.coords.latitude;lng=p.coords.longitude;$('#geoMsg').textContent=' '+t('locSet');},()=>{$('#geoMsg').textContent='';},{enableHighAccuracy:true,timeout:15000});
});
function showErr(m){const e=$('#err');e.textContent=m;e.classList.remove('hide');}
function val(id){ const v=$('#'+id).value; return v==='__other'?$('#'+id+'_o').value.trim():v; }

$('#f').addEventListener('submit',async ev=>{
  ev.preventDefault(); $('#err').classList.add('hide');
  const location=val('location'), type=val('type'), resp=val('resp');
  if(!factory||!location||!type||!blob){ showErr(t('required')); return; }
  if(blob.size>9*1024*1024){ showErr(t('tooBig')); return; }
  const btn=$('#send'); btn.disabled=true; btn.textContent=t('sending');
  try{
    const id=ECO.uuid(), name=`web_${id}_before_${Date.now()}.jpg`;
    const up=await ECO.rest('/storage/v1/object/report-photos/'+name,{method:'POST',headers:{'Content-Type':'image/jpeg'},body:blob});
    if(!up.ok) throw new Error('upload '+up.status);
    const image_url=`${cfg.url}/storage/v1/object/public/report-photos/${name}`;
    const r=await ECO.rest('/rest/v1/rpc/submit_web_report',{method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({p:{id,factory_id:factory,location,type,responsibility:resp,severity:sev,description:$('#desc').value.trim(),impacts:[...imps],reporter:$('#reporter').value.trim(),lat,lng,image_url}})});
    if(!r.ok) throw new Error('rpc '+r.status);
    const no=await r.json();
    $('#f').classList.add('hide'); $('#done').classList.remove('hide');
    $('#doneMsg').textContent=t('thanks'); $('#doneNo').textContent=no?('#'+no):'';
  }catch(e){ showErr(t('sendFail')); console.error(e); }
  finally{ btn.disabled=false; btn.textContent=t('send'); }
});
$('#again').addEventListener('click',()=>{ location.reload(); });
})();
