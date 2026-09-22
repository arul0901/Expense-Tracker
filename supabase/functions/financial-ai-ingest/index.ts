import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Only allow service role for automated ingestion (or auth header if triggered by client)
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), { status: 401, headers: corsHeaders });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    
    // We use service role to do background processing
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
    
    // But we still validate the caller if it's not the service key
    const isServiceKey = authHeader.replace("Bearer ", "") === supabaseServiceKey;
    
    const { action, userId, sourceId, sourceType, title, content, metadata } = await req.json();

    if (!userId || !sourceType || !title || !content) {
      return new Response(JSON.stringify({ error: "Missing required RAG parameters" }), { status: 400, headers: corsHeaders });
    }

    // Generate Embedding using our other edge function or direct API call
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiApiKey) {
      throw new Error("GEMINI_API_KEY is missing");
    }

    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${geminiApiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: "models/text-embedding-004",
        content: { parts: [{ text: `Title: ${title}\nContent: ${content}` }] },
        outputDimensionality: 384,
      }),
    });

    if (!response.ok) {
      const err = await response.text();
      throw new Error(`Embedding API Error: ${err}`);
    }

    const data = await response.json();
    const embedding = data.embedding?.values;

    if (!embedding || embedding.length !== 384) {
      throw new Error("Invalid embedding generated.");
    }

    // Upsert into financial_ai_documents
    const { error: upsertError } = await supabaseAdmin
      .from('financial_ai_documents')
      .upsert({
        user_id: userId,
        source_type: sourceType,
        source_id: sourceId,
        title,
        content,
        metadata: metadata || {},
        embedding,
        updated_at: new Date().toISOString()
      }, { onConflict: 'user_id, source_type, source_id' }); // Assuming unique constraint exists, else we need a different logic

    if (upsertError) {
      // If unique constraint isn't on those 3, we fallback to deleting old and inserting new
      if (upsertError.code === '42P10' || upsertError.message.includes('unique constraint')) {
        // Just let it fail or handle manual delete/insert
        throw upsertError;
      }
      
      // Manual deduplication if no constraint:
      await supabaseAdmin
          .from('financial_ai_documents')
          .delete()
          .match({ user_id: userId, source_type: sourceType, source_id: sourceId });
          
      const { error: insertError } = await supabaseAdmin
          .from('financial_ai_documents')
          .insert({
            user_id: userId,
            source_type: sourceType,
            source_id: sourceId,
            title,
            content,
            metadata: metadata || {},
            embedding,
          });
          
      if (insertError) throw insertError;
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error: any) {
    console.error("Error in financial-ai-ingest:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
