import { createClient } from "npm:@supabase/supabase-js@2.95.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-command-secret, x-device-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

function safeEqual(actual: string | null, expected: string | undefined): boolean {
  if (!actual || !expected) return false;
  const a = new TextEncoder().encode(actual);
  const b = new TextEncoder().encode(expected);
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const commandSecret = Deno.env.get("REMOTE_UNLOCK_COMMAND_SECRET");
  const deviceSecret = Deno.env.get("REMOTE_UNLOCK_DEVICE_SECRET");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!commandSecret || !deviceSecret || !supabaseUrl || !serviceKey) {
    console.error("RemoteUnlock function is missing required environment variables.");
    return json({ error: "relay_not_configured" }, 503);
  }

  let payload: Record<string, unknown>;
  try {
    const raw = await req.text();
    if (raw.length > 2048) return json({ error: "payload_too_large" }, 413);
    payload = JSON.parse(raw || "{}");
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  if (payload.operation === "command") {
    if (!safeEqual(req.headers.get("x-command-secret"), commandSecret)) {
      return json({ error: "unauthorized" }, 401);
    }
    // Clean up expired rows only after authenticating the caller.
    await supabase.from("remoteunlock_commands").delete().lt("expires_at", new Date().toISOString());
    if (payload.action !== "lock") {
      return json({ error: "unsupported_action", allowed: ["lock"] }, 400);
    }

    const expiresAt = new Date(Date.now() + 120_000).toISOString();
    const { data, error } = await supabase
      .from("remoteunlock_commands")
      .insert({ action: "lock", expires_at: expiresAt })
      .select("id")
      .single();

    if (error || !data) {
      console.error("Could not queue lock command:", error?.message);
      return json({ error: "queue_failed" }, 500);
    }
    return json({ ok: true, queued: true, commandId: data.id, expiresAt }, 202);
  }

  if (payload.operation === "poll") {
    if (!safeEqual(req.headers.get("x-device-secret"), deviceSecret)) {
      return json({ error: "unauthorized" }, 401);
    }

    const now = new Date().toISOString();
    const { data: pending, error: selectError } = await supabase
      .from("remoteunlock_commands")
      .select("id, action")
      .is("claimed_at", null)
      .gt("expires_at", now)
      .order("created_at", { ascending: true })
      .limit(1)
      .maybeSingle();

    if (selectError) {
      console.error("Could not read command queue:", selectError.message);
      return json({ error: "queue_read_failed" }, 500);
    }
    if (!pending) return json({ command: null });

    // Conditional claim prevents two agents from receiving the same command.
    const { data: claimed, error: claimError } = await supabase
      .from("remoteunlock_commands")
      .update({ claimed_at: now })
      .eq("id", pending.id)
      .is("claimed_at", null)
      .select("id, action")
      .maybeSingle();

    if (claimError) {
      console.error("Could not claim command:", claimError.message);
      return json({ error: "queue_claim_failed" }, 500);
    }
    if (!claimed) return json({ command: null });

    return json({ command: { id: claimed.id, action: claimed.action } });
  }

  return json({ error: "unsupported_operation" }, 400);
});
