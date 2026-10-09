/* Kimonik unified username/email login. Supabase Auth persists sessions across same-origin pages. */
async function kimonikLogin(db, identifier, password) {
  const response = await fetch('https://ilxahxzrtzpzhnlskfns.supabase.co/functions/v1/kimonik-login', {
    method: 'POST',
    headers: {'Content-Type':'application/json','apikey':'sb_publishable_eetxbGhYGFLhJdXhiU2W0A_qG63dTyU'},
    body: JSON.stringify({identifier:String(identifier||'').trim(),password})
  });
  const body = await response.json();
  if (!response.ok) throw Error(body.error || 'Login gagal');
  const {data,error} = await db.auth.setSession({access_token:body.access_token,refresh_token:body.refresh_token});
  if(error || !data.user) throw Error(error?.message || 'Gagal menyimpan sesi login');
  return data.user;
}

function kimonikAccessDenied(){
 const main=document.querySelector('main')||document.body;
 main.innerHTML='<section style="max-width:560px;margin:50px auto;padding:28px;background:white;border:1px solid #ddd;border-radius:14px;text-align:center;font-family:Arial"><h2>Akses Ditolak</h2><p>Akun Anda tidak memiliki izin membuka halaman ini. Anda tetap login.</p><a href="dashboard-admin.html" style="display:inline-block;background:#292621;color:white;padding:12px 20px;border-radius:9px;text-decoration:none">Kembali ke Dashboard Admin</a></section>';
}
