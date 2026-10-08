import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
const respond = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: cors });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") return respond(405, { error: "Metode tidak diizinkan" });
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !service) return respond(500, { error: "Konfigurasi server belum lengkap" });
  const bearer = req.headers.get("Authorization") || "";
  if (!bearer.startsWith("Bearer ")) return respond(401, { error: "Silakan login sebagai Owner" });
  const userClient = createClient(url, anon, { global: { headers: { Authorization: bearer } } });
  const { data: auth, error: authError } = await userClient.auth.getUser(bearer.slice(7));
  if (authError || !auth.user) return respond(401, { error: "Sesi tidak valid" });
  const admin = createClient(url, service, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data: profile, error: profileError } = await admin.from("profiles").select("role").eq("id", auth.user.id).single();
  if (profileError || profile?.role !== "owner") return respond(403, { error: "Hanya Owner yang boleh membuat akun" });
  let payload: Record<string, unknown>;
  try { payload = await req.json(); } catch { return respond(400, { error: "Data tidak valid" }); }
  if (payload.action === "update_username") {
    const userId = String(payload.user_id ?? "");
    const newUsername = String(payload.username ?? "").trim().toLowerCase();
    if (!/^[0-9a-f-]{36}$/i.test(userId) || !/^[a-z0-9_]{3,30}$/.test(newUsername))
      return respond(400, { error: "ID atau username tidak valid" });
    const { data: target, error: targetError } = await admin.from("profiles")
      .select("id,role,nama").eq("id", userId).single();
    if (targetError || !target || !["admin","penjahit"].includes(target.role))
      return respond(403, { error: "Akun tidak dapat diubah" });
    const { data: used, error: usedError } = await admin.from("profiles")
      .select("id").eq("username", newUsername).neq("id", userId).limit(1);
    if (usedError) return respond(500, { error: "Gagal memeriksa username" });
    if (used?.length) return respond(409, { error: "Username sudah digunakan" });
    const { error: updateError } = await admin.from("profiles")
      .update({ username: newUsername }).eq("id", userId);
    if (updateError) return respond(updateError.code === "23505" ? 409 : 500,
      { error: updateError.code === "23505" ? "Username sudah digunakan" : "Gagal menyimpan username" });
    return respond(200, { ok: true, nama: target.nama, username: newUsername });
  }
  const nama = String(payload.nama ?? "").trim();
  const username = String(payload.username ?? "").trim().toLowerCase();
  const password = String(payload.password ?? "");
  const role = String(payload.role ?? "");
  const email = String(payload.email ?? "").trim().toLowerCase();
  if (nama.length < 2 || nama.length > 100 || !/^[a-z0-9_]{3,30}$/.test(username) ||
      password.length < 10 || !["admin", "penjahit"].includes(role) ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return respond(400, { error: "Periksa nama, username, email, peran dan password (minimal 10 karakter)" });
  }
  const { data: existing, error: existingError } = await admin.from("profiles").select("id").ilike("username", username).limit(1);
  if (existingError) return respond(500, { error: "Gagal memeriksa username" });
  if (existing?.length) return respond(409, { error: "Username sudah digunakan" });
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email, password, email_confirm: true,
    user_metadata: { nama, username },
  });
  if (createError || !created.user) return respond(400, { error: createError?.message || "Gagal membuat akun" });
  const { error: insertError } = await admin.from("profiles").upsert({
    id: created.user.id, nama, username, role,
  }, { onConflict: "id" });
  if (insertError) {
    await admin.auth.admin.deleteUser(created.user.id);
    return respond(500, { error: "Profil gagal dibuat: " + insertError.message });
  }
  return respond(201, { ok: true, nama, username, role });
});
