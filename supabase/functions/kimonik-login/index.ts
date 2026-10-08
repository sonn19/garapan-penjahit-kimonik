import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
};
const reply = (status: number, value: unknown) => new Response(JSON.stringify(value), { status, headers });
const invalid = () => reply(401, { error: "Username/email atau password salah" });
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers });
  if (req.method !== "POST") return reply(405, { error: "Metode tidak diizinkan" });
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !service) return reply(500, { error: "Konfigurasi server belum lengkap" });
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "Data tidak valid" }); }
  const identifier = String(body.identifier ?? "").trim().toLowerCase();
  const password = String(body.password ?? "");
  if (!identifier || identifier.length > 254 || !password || password.length > 1024) return invalid();
  let email = identifier;
  if (!identifier.includes("@")) {
    if (!/^[a-z0-9_]{3,30}$/.test(identifier)) return invalid();
    const admin = createClient(url, service, { auth: { autoRefreshToken: false, persistSession: false } });
    const { data: rows, error: lookupError } = await admin.from("profiles").select("id").eq("username", identifier).limit(1);
    if (lookupError) return reply(500, { error: "Login belum tersedia" });
    if (!rows?.length) return invalid();
    const { data: account, error: accountError } = await admin.auth.admin.getUserById(rows[0].id);
    if (accountError || !account.user?.email) return invalid();
    email = account.user.email;
  }
  const client = createClient(url, anon, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data, error } = await client.auth.signInWithPassword({ email, password });
  if (error || !data.session) return invalid();
  return reply(200, {
    access_token: data.session.access_token,
    refresh_token: data.session.refresh_token,
  });
});
