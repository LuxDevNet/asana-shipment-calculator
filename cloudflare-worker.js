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
// Displays the calculated values (AMZ, LMZ, and Difference) in Asana
app.get("/widget", async (c) => {
  const supabase = c.get("supabase");
  const resourceUrl = c.req.query("resource_url") || "";

  console.log("Fetching widget for resource:", resourceUrl);

  // Extract shipment ID from the URL (e.g. https://domain.com/shipments/SHIP-INHOUSE-01)
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

  // Fetch Shipment COGS values from the SQL view
  const { data: shipment, error } = await supabase
    .from("shipment_cogs_summary")
    .select("*")
    .eq("shipment_id", shipmentId)
    .single();

  if (error || !shipment) {
    console.error("Error fetching shipment calculations:", error);
    return c.json({
      template: "summary_with_details_v0",
      metadata: {
        title: `Shipment ${shipmentId} Not Found`,
        subtitle: "Check the ID in packlists or shipping_queue",
      },
    });
  }

  // Determine pill color for the difference
  const diffVal = Number(shipment.shipment_value_dif);
  let diffColor = "none";
  if (diffVal > 0) diffColor = "red";       // Amazon is higher than Luminize
  if (diffVal < 0) diffColor = "green";     // Luminize is higher than Amazon
  if (diffVal === 0) diffColor = "blue";

  return c.json({
    template: "summary_with_details_v0",
    metadata: {
      title: shipment.shipment_id,
      subtitle: `Source: ${shipment.source_type.toUpperCase()} | Qty: ${shipment.total_quantity}`,
      fields: [
        {
          name: "AMZ Value",
          type: "pill",
          text: `$${Number(shipment.shipment_value_amz).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`,
          color: "orange",
        },
        {
          name: "LMZ Value",
          type: "pill",
          text: `$${Number(shipment.shipment_value_lmz).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`,
          color: "blue",
        },
        {
          name: "Difference",
          type: "pill",
          text: `$${diffVal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`,
          color: diffColor,
        },
      ],
      footer: {
        footer_type: "custom_text",
        text: `Calculated from ${shipment.total_items} items`,
      },
      num_comments: 0,
    },
  });
});

// Form Metadata: https://developers.asana.com/docs/get-form-metadata
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
          placeholder: "Search by Shipment ID (e.g. SHIP-AMZ-99)",
          typeahead_url: `${baseUrl}/search/typeahead`,
          width: "full",
        },
      ],
    },
  });
});

// Typeahead Endpoint: https://developers.asana.com/docs/get-lookup-typeahead-results
app.get("/search/typeahead", async (c) => {
  const supabase = c.get("supabase");
  const query = c.req.query("query") || "";

  console.log("Searching shipments matching query:", query);

  // Search by shipment_id in the view
  const { data: shipments, error } = await supabase
    .from("shipment_cogs_summary")
    .select("shipment_id, source_type, total_items, total_quantity")
    .ilike("shipment_id", `%${query}%`)
    .limit(10);

  if (error || !shipments) {
    console.error("Typeahead query error:", error);
    return c.json({ items: [] });
  }

  const items = shipments.map((s) => ({
    title: s.shipment_id,
    subtitle: `Source: ${s.source_type.toUpperCase()} | Qty: ${s.total_quantity} (${s.total_items} items)`,
    value: s.shipment_id,
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
          placeholder: "Search by Shipment ID (e.g. SHIP-AMZ-99)",
          typeahead_url: `${baseUrl}/search/typeahead`,
          width: "full",
        },
      ],
    },
  });
});

// Form Submit: https://developers.asana.com/docs/on-submit-callback
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
