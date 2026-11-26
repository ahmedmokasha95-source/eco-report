(function(){
const C = window.ECO_CONFIG, O = window.ECO_OPTIONS;
const I18N = {
 ar:{app:'رصد المخالفات البيئية',tag:'معًا للحفاظ على البيئة',lang:'English',theme:'الوضع',
  submitTitle:'تقديم بلاغ',submitSub:'سجّل مخالفة بيئية في دقيقة، من غير تسجيل دخول',
  chooseFactory:'اختر المصنع',location:'المكان',type:'نوع المخالفة',resp:'الجهة المسؤولة',severity:'الخطورة',
  impacts:'التأثيرات',desc:'الوصف',reporter:'اسمك',photo:'صورة المخالفة',addPhoto:'اضغط لالتقاط صورة أو اختيارها',
  getLoc:'تحديد موقعي',locSet:'تم تحديد الموقع',send:'إرسال البلاغ',sending:'جاري الإرسال...',select:'اختر...',
  other:'أخرى (اكتب)',required:'املأ الحقول المطلوبة: المصنع والمكان والنوع والصورة',
  thanks:'تم استلام بلاغك. شكرًا لمساهمتك',another:'بلاغ جديد',
  sendFail:'تعذّر الإرسال. حاول مرة أخرى',tooBig:'الصورة كبيرة، اختر صورة أصغر',
  adminLogin:'دخول المدير',username:'اسم المستخدم',password:'كلمة المرور',login:'دخول',logout:'خروج',
  badLogin:'اسم المستخدم أو كلمة المرور غلط',adminsOnly:'الحساب ده مش مدير. لوحة التحكم للمديرين بس',
  dashboard:'لوحة التحكم',reports:'البلاغات',total:'الإجمالي',open:'مفتوحة',inprog:'جاري المعالجة',closed:'مغلقة',overdue:'متأخرة',
  allFactories:'كل المصانع',allStatus:'كل الحالات',allSev:'كل الدرجات',search:'بحث...',refresh:'تحديث',export:'تصدير CSV',
  byStatus:'حسب الحالة',byType:'حسب النوع',byLocation:'حسب المكان',bySeverity:'حسب الخطورة',monthly:'شهريًا',byFactory:'حسب المصنع',
  insights:'ملخص ذكي',noData:'مفيش بيانات',id:'رقم',date:'التاريخ',factory:'المصنع',status:'الحالة',due:'موعد المعالجة',
  corrective:'الإجراء التصحيحي',before:'قبل المعالجة',after:'بعد المعالجة',save:'حفظ',saved:'تم الحفظ',close:'إغلاق',
  map:'الموقع على الخريطة',source:'المصدر',srcWeb:'الويب',srcApp:'التطبيق',newR:'جديد',loadFail:'تعذّر تحميل البيانات',
  topType:'أكثر نوع تكرارًا',topLoc:'أكثر مكان تكرارًا',overdueN:'بلاغات متأخرة عن موعدها',closeRate:'نسبة الإغلاق',
  publicLink:'رابط صفحة تقديم البلاغ',copied:'تم النسخ',
  Open:'مفتوح','In progress':'جاري المعالجة',Closed:'مغلق',Low:'منخفضة',Medium:'متوسطة',High:'عالية'},
 en:{app:'Environmental Violation Monitoring',tag:'Together for the environment',lang:'العربية',theme:'Theme',
  submitTitle:'Submit a report',submitSub:'Report an environmental violation in a minute, no login needed',
  chooseFactory:'Choose the factory',location:'Location',type:'Violation type',resp:'Responsible party',severity:'Severity',
  impacts:'Impacts',desc:'Description',reporter:'Your name',photo:'Photo of the violation',addPhoto:'Tap to take or choose a photo',
  getLoc:'Use my location',locSet:'Location captured',send:'Send report',sending:'Sending...',select:'Select...',
  other:'Other (type)',required:'Fill the required fields: factory, location, type and photo',
  thanks:'Your report was received. Thank you',another:'New report',
  sendFail:'Could not send. Please try again',tooBig:'Photo is too large, choose a smaller one',
  adminLogin:'Admin sign in',username:'Username',password:'Password',login:'Sign in',logout:'Sign out',
  badLogin:'Wrong username or password',adminsOnly:'This account is not an admin. The dashboard is for admins only',
  dashboard:'Dashboard',reports:'Reports',total:'Total',open:'Open',inprog:'In progress',closed:'Closed',overdue:'Overdue',
  allFactories:'All factories',allStatus:'All statuses',allSev:'All severities',search:'Search...',refresh:'Refresh',export:'Export CSV',
  byStatus:'By status',byType:'By type',byLocation:'By location',bySeverity:'By severity',monthly:'Monthly',byFactory:'By factory',
  insights:'Smart summary',noData:'No data',id:'No.',date:'Date',factory:'Factory',status:'Status',due:'Due date',
  corrective:'Corrective action',before:'Before',after:'After',save:'Save',saved:'Saved',close:'Close',
  map:'Open on map',source:'Source',srcWeb:'Web',srcApp:'App',newR:'New',loadFail:'Could not load data',
  topType:'Most frequent type',topLoc:'Most frequent location',overdueN:'reports past their due date',closeRate:'Closure rate',
  publicLink:'Public report page link',copied:'Copied',
  Open:'Open','In progress':'In progress',Closed:'Closed',Low:'Low',Medium:'Medium',High:'High'}
};
const E = {};
E.cfg = C; E.opts = O;
E.lang = localStorage.getItem('eco_lang') || ((navigator.language||'ar').startsWith('en') ? 'en' : 'ar');
E.t = k => (I18N[E.lang][k] ?? I18N.ar[k] ?? k);
E.optText = (kind, en) => { const o=(O[kind]||[]).find(x=>x.en===en); return o ? (E.lang==='en'?o.en:o.ar) : (en||''); };
E.applyLang = () => {
  document.documentElement.lang = E.lang; document.documentElement.dir = E.lang==='ar'?'rtl':'ltr';
  document.querySelectorAll('[data-i]').forEach(n=>n.textContent=E.t(n.dataset.i));
  document.querySelectorAll('[data-ph]').forEach(n=>n.placeholder=E.t(n.dataset.ph));
  document.title = E.t('app');
};
E.setLang = l => { E.lang=l; localStorage.setItem('eco_lang',l); E.applyLang(); document.dispatchEvent(new Event('langchange')); };
E.theme = localStorage.getItem('eco_theme') || (matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light');
E.applyTheme = () => document.documentElement.dataset.theme = E.theme;
E.toggleTheme = () => { E.theme = E.theme==='dark'?'light':'dark'; localStorage.setItem('eco_theme',E.theme); E.applyTheme(); };
E.applyTheme();
E.$ = (s,r=document)=>r.querySelector(s);
E.h = (tag, attrs={}, ...kids) => { const n=document.createElement(tag);
  for(const [k,v] of Object.entries(attrs||{})){ if(k==='class')n.className=v; else if(k.startsWith('on'))n.addEventListener(k.slice(2),v); else if(v!==false&&v!=null)n.setAttribute(k,v===true?'':v); }
  for(const c of kids.flat()){ if(c==null||c===false)continue; n.append(c.nodeType?c:document.createTextNode(c)); } return n; };
E.sevColor = s => s==='High'?'#C62828':s==='Medium'?'#EF6C00':'#2E7D32';
E.statusColor = s => s==='Closed'?'#2E7D32':s==='In progress'?'#EF6C00':'#C62828';
E.fmtDate = d => { if(!d) return ''; const x=new Date(d); return x.getFullYear()+'/'+String(x.getMonth()+1).padStart(2,'0')+'/'+String(x.getDate()).padStart(2,'0'); };
E.uuid = () => crypto.randomUUID ? crypto.randomUUID() : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g,c=>{const r=Math.random()*16|0;return (c==='x'?r:(r&3|8)).toString(16)});
E.logo = `<svg viewBox="0 0 64 64" aria-hidden="true"><circle cx="32" cy="32" r="28" fill="#fff" opacity=".95"/><path d="M14 36c6-14 24-18 36-10-4 16-20 24-36 10z" fill="#2E7D32"/><path d="M20 40c8-6 16-10 26-12" stroke="#C8E6C9" stroke-width="3" fill="none" stroke-linecap="round"/></svg>`;
E.topbar = (extra) => { const bar=E.h('header',{class:'topbar'});
  bar.innerHTML = `<div class="brand">${E.logo}<span data-i="app"></span></div>`;
  const lang=E.h('button',{class:'iconbtn',onclick:()=>E.setLang(E.lang==='ar'?'en':'ar')}); lang.dataset.i='lang';
  const th=E.h('button',{class:'iconbtn',title:'theme',onclick:E.toggleTheme},'◐');
  bar.append(...(extra||[]),lang,th); return bar; };
// REST
E.token = null;
E.headers = (extra) => ({apikey:C.key, ...(E.token?{Authorization:'Bearer '+E.token}:{}), ...extra});
E.rest = async (path, opts={}) => { const r = await fetch(C.url+path,{...opts,headers:E.headers(opts.headers)}); return r; };
window.ECO = E;
})();
