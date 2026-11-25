// Supabase Edge Function: verify-razorpay-payment
// Verifies the Razorpay payment signature server-side, then marks the
// matching order as paid. Only "artwork_orders" and "digital_product_orders"
// are allowed, and only the order's own buyer can verify it.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const ALLOWED_TABLES: Record<string, string> = {
  artwork_orders: "Payment Verified",
  digital_product_orders: "Paid",
  course_enrollments: "Paid",
};

async function hmacSha256Hex(message: string, secret: string) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signatureBuffer = await crypto.subtle.sign(
    "HMAC",
    key,
    enc.encode(message)
  );
  return Array.from(new Uint8Array(signatureBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") || "";

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: "Not authenticated" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const {
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature,
      order_table,
      order_id,
    } = await req.json();

    if (
      !razorpay_order_id || !razorpay_payment_id || !razorpay_signature ||
      !order_table || !order_id
    ) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing fields" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const newStatus = ALLOWED_TABLES[order_table];
    if (!newStatus) {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid order table" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ---- Verify the Razorpay signature ----
    const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET")!;
    const expectedSignature = await hmacSha256Hex(
      `${razorpay_order_id}|${razorpay_payment_id}`,
      keySecret
    );

    if (expectedSignature !== razorpay_signature) {
      return new Response(
        JSON.stringify({ success: false, error: "Payment signature mismatch" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ---- Use the service role to check ownership + update the order ----
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    console.log("Has service role key:", !!serviceRoleKey);
    console.log("Looking up order:", { order_table, order_id, type: typeof order_id });

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      serviceRoleKey!
    );

    const { data: orderRow, error: fetchError } = await supabaseAdmin
      .from(order_table)
      .select("id, buyer_id")
      .eq("id", order_id)
      .maybeSingle();

    if (fetchError) {
      console.error("fetchError:", fetchError);
      return new Response(
        JSON.stringify({ success: false, error: "Lookup failed: " + fetchError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!orderRow) {
      console.error("No order row found for", order_table, order_id);
      return new Response(
        JSON.stringify({ success: false, error: "Order not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (orderRow.buyer_id !== user.id) {
      return new Response(
        JSON.stringify({ success: false, error: "This order does not belong to you" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { error: updateError } = await supabaseAdmin
      .from(order_table)
      .update({
        status: newStatus,
        razorpay_order_id,
        razorpay_payment_id,
      })
      .eq("id", order_id);

    if (updateError) throw updateError;

    return new Response(
      JSON.stringify({ success: true, status: newStatus }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("verify-razorpay-payment error:", error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
