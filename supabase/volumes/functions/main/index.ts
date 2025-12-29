// Supabase Edge Functions main entry point
// Add your edge functions in separate directories under /volumes/functions/

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const url = new URL(req.url)
  const { pathname } = url

  // Health check
  if (pathname === "/health") {
    return new Response(JSON.stringify({ status: "ok" }), {
      headers: { "Content-Type": "application/json" },
    })
  }

  // Default response
  return new Response(
    JSON.stringify({
      message: "Wink Edge Functions",
      path: pathname
    }),
    {
      headers: { "Content-Type": "application/json" },
      status: 200
    },
  )
})
