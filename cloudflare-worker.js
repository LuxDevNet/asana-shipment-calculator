import { Hono } from "hono";
import { cors } from "hono/cors";
import { createClient } from "@supabase/supabase-js";

const app = new Hono();

// 1. Enable CORS for Asana (https://developers.asana.com/docs/security)
app.use(
  "*",
  cors({
    origin: "https://app.asana.com",
    allowMethods: ["GET", "POST", "OPTIONS"],
    allowHeaders: ["Content-Type", "X-Asana-Request-Signature"],
  })
);

// 2. Timeliness Middleware (https://developers.asana.com/docs/timeliness)
app.use("*", async (c, next) => {
  const url = new URL(c.req.url);
  const expirationDate = url.searchParams.get("expires_at");

  if (expirationDate) {
    const currentDate = new Date();
    if (currentDate.getTime() > new Date(expirationDate).getTime()) {
      console.log("Request expired.");
      return c.text("Request expired.", 400);
    }
  }
  await next();
});

// Helper: Get base URL dynamically
const getBaseUrl = (reqUrl) => {
  const url = new URL(reqUrl);
  return `${url.protocol}//${url.host}`;
};

// 3. Supabase Client Setup (Injects into context for every request)
app.use("*", async (c, next) => {
  const supabaseUrl = c.env.SUPABASE_URL || "";
  const supabaseAnonKey = c.env.SUPABASE_ANON_KEY || "";
  c.set("supabase", createClient(supabaseUrl, supabaseAnonKey));
  await next();
});

// -------------------- Auth endpoint --------------------
app.get("/auth", (c) => {
  return c.html(`
<!DOCTYPE html>
<html>
<head><title>Asana Auth</title></head>
<body>
    <script>
        function finish() {
            window.opener.postMessage("success", "https://app.asana.com");
            window.close();
        };
    </script>
    <button onclick="finish()">Connect to Supabase</button>
</body>
</html>
  `);
});

// -------------------- API Endpoints --------------------

// Widget Metadata: https://developers.asana.com/docs/get-widget-metadata
// This returns the COGS dynamically to the Asana Task card
app.get("/widget", async (c) => {
  const supabase = c.get("supabase");
  const resourceUrl = c.req.query("resource_url") || "";

  console.log("Fetching widget for resource:", resourceUrl);

  // Extract shipment ID from the URL (e.g. https://domain.com/shipments/SH-1001)
  const match = resourceUrl.match(/\/shipments\/([^/?#]+)/);
  const shipmentId = match ? decodeURIComponent(match[1]) : null;

  if (!shipmentId) {
    return c.json({
      template: "summary_with_details_v0",
      metadata: {
        title: "No Shipment Linked",
        subtitle: "Attach a shipment using the app menu",
      },
    });
  }

  // Fetch Shipment COGS and Carrier from Supabase
  const { data: shipment, error } = await supabase
    .from("shipments")
    .select("*")
    .eq("id", shipmentId)
    .single();

  if (error || !shipment) {
    console.error("Error fetching shipment:", error);
    return c.json({
      template: "summary_with_details_v0",
      metadata: {
        title: `Shipment ${shipmentId} Not Found`,
        subtitle: "Verify the ID exists in Supabase database",
      },
    });
  }

  return c.json({
    template: "summary_with_details_v0",
    metadata: {
      title: `Shipment ${shipment.id}`,
      subtitle: `Carrier: ${shipment.carrier || "Unknown"}`,
      fields: [
        {
          name: "Shipment COGS",
          type: "pill",
          text: `$${Number(shipment.cogs).toFixed(2)}`,
          color: "hot-pink",
        },
        {
          name: "Status",
          type: "pill",
          text: shipment.status || "N/A",
          color: shipment.status === "Delivered" ? "green" : "blue",
        },
      ],
      footer: {
        footer_type: "custom_text",
        text: "Database Sync: Supabase Edge",
      },
      num_comments: 0,
    },
  });
});

// Form Metadata: https://developers.asana.com/docs/get-form-metadata
// Renders the Modal Form in Asana
app.get("/form/metadata", (c) => {
  const baseUrl = getBaseUrl(c.req.url);
  return c.json({
    template: "form_metadata_v0",
    metadata: {
      title: "Link Shipment to Task",
      on_submit_callback: `${baseUrl}/form/submit`,
      on_change_callback: `${baseUrl}/form/onchange`,
      fields: [
        {
          name: "Search Shipment ID",
          type: "typeahead",
          id: "shipment_id",
          is_required: true,
          placeholder: "Search by Shipment ID (e.g. SH-1001)",
          typeahead_url: `${baseUrl}/search/typeahead`,
          width: "full",
        },
      ],
    },
  });
});

// Typeahead Endpoint: https://developers.asana.com/docs/get-lookup-typeahead-results
// Queries your Supabase database as the user types
app.get("/search/typeahead", async (c) => {
  const supabase = c.get("supabase");
  const query = c.req.query("query") || "";

  console.log("Searching shipments matching query:", query);

  const { data: shipments, error } = await supabase
    .from("shipments")
    .select("id, carrier, cogs")
    .ilike("id", `%${query}%`)
    .limit(10);

  if (error || !shipments) {
    console.error("Typeahead query error:", error);
    return c.json({ items: [] });
  }

  const items = shipments.map((s) => ({
    title: s.id,
    subtitle: `Carrier: ${s.carrier || "N/A"} | COGS: $${Number(s.cogs).toFixed(2)}`,
    value: s.id,
  }));

  return c.json({ items });
});

// Form OnChange Callback: https://developers.asana.com/docs/on-change-callback
app.post("/form/onchange", (c) => {
  const baseUrl = getBaseUrl(c.req.url);
  return c.json({
    template: "form_metadata_v0",
    metadata: {
      title: "Link Shipment to Task",
      on_submit_callback: `${baseUrl}/form/submit`,
      fields: [
        {
          name: "Search Shipment ID",
          type: "typeahead",
          id: "shipment_id",
          is_required: true,
          placeholder: "Search by Shipment ID (e.g. SH-1001)",
          typeahead_url: `${baseUrl}/search/typeahead`,
          width: "full",
        },
      ],
    },
  });
});

// Form Submit: https://developers.asana.com/docs/on-submit-callback
// Returns the resource attachment containing the Shipment ID back to Asana
app.post("/form/submit", async (c) => {
  const body = await c.req.json();
  const baseUrl = getBaseUrl(c.req.url);
  const shipmentId = body.values?.shipment_id;

  if (!shipmentId) {
    return c.json({
      error: "Shipment ID is required",
    }, 400);
  }

  console.log("Linking Shipment:", shipmentId);

  return c.json({
    resource_name: `Shipment: ${shipmentId}`,
    resource_url: `${baseUrl}/shipments/${encodeURIComponent(shipmentId)}`,
  });
});

export default app;
