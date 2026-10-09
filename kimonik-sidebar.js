(function(){
'use strict';
const links=[
['dashboard-admin.html','⌂','Dashboard','all'],
['admin-order.html','▣','Order','all'],
['master-katalog.html','◇','Master Produk','all'],
['penjahit.html','♧','Penjahit','all'],
['master-hpp.html','✂','Master HPP','owner'],
['hpp-massal.html','▦','HPP Massal','owner'],
['hpp-shopee.html','◈','HPP Shopee','owner'],
['pembukuan.html','▤','Pembukuan','owner'],
['manajemen-akun.html','♙','Manajemen Akun','owner'],
['dashboard-admin.html#audit','⌕','Audit Data','all']
];
const css=`
#km-page-loader{position:fixed;top:0;left:0;right:0;height:3px;z-index:10000;background:transparent;opacity:0;pointer-events:none;transition:opacity .1s ease}
#km-page-loader.km-active{opacity:1;background:linear-gradient(90deg,#cbbba4,#292621,#cbbba4);background-size:200% 100%;animation:km-progress 1s linear infinite}
@keyframes km-progress{to{background-position:-200% 0}}
@media(prefers-reduced-motion:reduce){#km-page-loader{transition:none}#km-page-loader.km-active{animation:none;background:#292621}}
body.km-with-sidebar{margin-left:228px!important}
#km-sidebar{position:fixed!important;z-index:9990;left:0!important;top:0!important;bottom:0!important;width:228px;background:#292621;color:#fff;box-shadow:2px 0 12px #0002;overflow-y:auto;font-family:Arial,sans-serif}
#km-sidebar *{box-sizing:border-box}
#km-sidebar .km-brand{padding:24px 18px 22px;border-bottom:1px solid #ffffff24;font-weight:800;font-size:18px;letter-spacing:1px}
#km-sidebar .km-brand small{display:block;font-size:11px;font-weight:400;letter-spacing:0;color:#c4b9ac;margin-top:6px}
#km-sidebar nav{display:flex;flex-direction:column;padding:16px 10px;gap:5px}
#km-sidebar a{display:flex;align-items:center;gap:12px;padding:13px 12px;border-radius:9px;text-decoration:none;color:#e7e0d8;font-size:14px;font-weight:600}
#km-sidebar a:hover,#km-sidebar a[aria-current=page]{background:#fff2;color:#fff}
#km-sidebar .km-icon{font-size:19px;width:22px;text-align:center}
#km-sidebar .km-bottom{padding:12px 18px;font-size:12px;color:#bfb3a7;border-top:1px solid #ffffff24}
#km-menu-toggle{display:none;position:fixed;z-index:9992;left:12px;bottom:14px;border:0;border-radius:999px;padding:13px 17px;background:#292621;color:#fff;font:700 14px Arial;box-shadow:0 3px 14px #0004;cursor:pointer}
#km-menu-shade{display:none}
@media(max-width:850px){
body.km-with-sidebar{margin-left:0!important}
#km-sidebar{transform:translateX(-105%);transition:transform .16s}
body.km-menu-open #km-sidebar{transform:translateX(0)}
#km-menu-toggle{display:block}
body.km-menu-open #km-menu-shade{display:block;position:fixed;inset:0;background:#0007;z-index:9989}
}`;
function setupTransitions(){
 if(document.getElementById('km-page-loader'))return;
 const loader=document.createElement('div');loader.id='km-page-loader';loader.setAttribute('role','progressbar');loader.setAttribute('aria-label','Memuat halaman');document.body.appendChild(loader);
 let pending=null;
 const reset=()=>{if(pending!==null)clearTimeout(pending);pending=null;loader.classList.remove('km-active')};
 document.addEventListener('click',e=>{
  const a=e.target.closest('a[href]');
  if(!a||e.defaultPrevented||e.button!==0||e.ctrlKey||e.metaKey||e.shiftKey||e.altKey||a.target==='_blank'||a.hasAttribute('download'))return;
  const u=new URL(a.href,location.href);
  if(!['http:','https:'].includes(u.protocol)||u.origin!==location.origin||u.pathname===location.pathname&&u.search===location.search)return;
  reset();
  pending=setTimeout(()=>{loader.classList.add('km-active');pending=null},350);
 });
 window.addEventListener('pageshow',reset);
 window.addEventListener('focus',()=>{if(document.visibilityState==='visible')reset()});
}
async function init(){
if(typeof supabase==='undefined')return;
const client=supabase.createClient('https://ilxahxzrtzpzhnlskfns.supabase.co','sb_publishable_eetxbGhYGFLhJdXhiU2W0A_qG63dTyU');
const {data:{session}}=await client.auth.getSession();
if(!session?.user)return;
const {data:profile,error}=await client.from('profiles').select('role').eq('id',session.user.id).single();
if(error||!['owner','admin'].includes(String(profile?.role||'').toLowerCase()))return;
const role=String(profile.role).toLowerCase();
const style=document.createElement('style');style.textContent=css;document.head.appendChild(style);
const sidebar=document.createElement('aside');sidebar.id='km-sidebar';sidebar.setAttribute('aria-label','Navigasi Admin Kimonik');
const brand=document.createElement('div');brand.className='km-brand';brand.textContent='KIMONIK';const subtitle=document.createElement('small');subtitle.textContent='MENU '+role.toUpperCase();brand.appendChild(subtitle);sidebar.appendChild(brand);
const nav=document.createElement('nav');const current=location.pathname.split('/').pop()||'index.html';
for(const [href,icon,label,permission] of links){
if(permission==='owner'&&role!=='owner')continue;
const a=document.createElement('a');a.href=href;if(href.split('#')[0]===current&&!href.includes('#'))a.setAttribute('aria-current','page');
const symbol=document.createElement('span');symbol.className='km-icon';symbol.textContent=icon;a.appendChild(symbol);a.appendChild(document.createTextNode(label));nav.appendChild(a);
}
sidebar.appendChild(nav);const bottom=document.createElement('div');bottom.className='km-bottom';bottom.textContent='Navigasi cepat · Kimonik';sidebar.appendChild(bottom);
const shade=document.createElement('div');shade.id='km-menu-shade';shade.addEventListener('click',()=>document.body.classList.remove('km-menu-open'));
const toggle=document.createElement('button');toggle.id='km-menu-toggle';toggle.type='button';toggle.textContent='☰ Menu Admin';toggle.setAttribute('aria-label','Buka atau tutup menu admin');toggle.addEventListener('click',()=>document.body.classList.toggle('km-menu-open'));
document.body.append(sidebar,shade,toggle);document.body.classList.add('km-with-sidebar');setupTransitions();
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>{init().catch(console.warn)});else init().catch(console.warn);
})();