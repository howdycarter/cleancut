// RevenueCat → Supabase webhook handler (Deno)
// Deploy as a Supabase Edge Function. Set env SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.

// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const RC_API_KEY = Deno.env.get("REVENUECAT_API_KEY");

function mapProductToPlan(productId: string): "free" | "pro" | "premium" {
  switch (productId) {
    case "com.swiftkit.pro.monthly":
    case "com.swiftkit.pro.yearly":
      return "pro";
    case "com.swiftkit.premium.monthly":
    case "com.swiftkit.premium.yearly":
      return "premium";
    default:
      return "free";
  }
}

async function fetchEmailViaRevenueCat(appUserId: string): Promise<string | null> {
  if (!RC_API_KEY) return null;
  try {
    const resp = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`, {
      headers: { Authorization: `Bearer ${RC_API_KEY}` },
    });
    if (!resp.ok) return null;
    const data = await resp.json();
    const attrs = data?.subscriber_attributes ?? data?.attributes ?? {};
    const email = attrs?.email?.value ?? attrs?.email?.Value ?? null;
    return typeof email === "string" ? email : null;
  } catch {
    return null;
  }
}

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  try {
    const body = await req.json();
    const appUserId: string = body.app_user_id;
    const productId: string | undefined = body.product_id ?? body.product_identifier;
    const expirationMs: number | null = body.expiration_at_ms ?? body.expires_at_ms ?? null;
    const lastEvent: string = body.type ?? body.event ?? "update";
    // Attempt to pull subscriber email from webhook (if sent) or via RC API
    let email: string | null = null;
    const attrs = body.subscriber_attributes ?? body.attributes;
    if (attrs?.email?.value) email = attrs.email.value;
    if (!email) email = await fetchEmailViaRevenueCat(appUserId);

    const plan = productId ? mapProductToPlan(productId) : "free";
    const expires_at = expirationMs ? new Date(expirationMs).toISOString() : null;

    const { error } = await supabase
      .from("user_subscriptions")
      .upsert({ user_id: appUserId, email, plan, expires_at, product_id: productId, last_event: lastEvent, updated_at: new Date().toISOString() });

    if (error) return new Response(error.message, { status: 400 });
    return new Response("ok", { status: 200 });
  } catch (e: any) {
    return new Response(e?.message ?? "bad request", { status: 400 });
  }
});
