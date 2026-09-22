// =====================================================================
// PROFIN — AI FINANCIAL ASSISTANT EDGE FUNCTION
// SECURE INTENT ROUTER + RPC TOOL CALLER + HYBRID RAG SYNTHESIZER
// =====================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface AiRequestPayload {
  prompt: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const token = authHeader.replace("Bearer ", "").trim();
    const { data: { user }, error: userError } = await supabase.auth.getUser(token);
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid user token", details: userError }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { prompt }: AiRequestPayload = await req.json();
    const cleanPrompt = (prompt || "").trim().toLowerCase();

    let intent = "fallback";
    let factData: any = null;

    // -----------------------------------------------------------------
    // STEP 1: FACT RETRIEVAL (PostgreSQL RPCs as Source of Truth)
    // -----------------------------------------------------------------
    if (cleanPrompt.includes("who owes me") || cleanPrompt.includes("people owe me") || cleanPrompt.includes("receivable")) {
      intent = "people_who_owe_me";
      const { data } = await supabase.rpc("get_people_who_owe_me");
      factData = data;
    } else if (cleanPrompt.includes("who do i owe") || cleanPrompt.includes("i owe") || cleanPrompt.includes("payable")) {
      intent = "people_i_owe";
      const { data } = await supabase.rpc("get_people_i_owe");
      factData = data;
    } else if (cleanPrompt.includes("spend") || cleanPrompt.includes("spent") || cleanPrompt.includes("spending") || cleanPrompt.includes("this month") || cleanPrompt.includes("expense") || cleanPrompt.includes("expenses") || cleanPrompt.includes("cost")) {
      intent = "monthly_spending";
      
      const now = new Date();
      let targetMonth = now.getMonth() + 1;
      let targetYear = now.getFullYear();

      if (cleanPrompt.includes("last month") || cleanPrompt.includes("previous month")) {
        targetMonth = now.getMonth();
        if (targetMonth === 0) {
          targetMonth = 12;
          targetYear -= 1;
        }
      } else {
        const months: Record<string, number> = {
          'january': 1, 'february': 2, 'march': 3, 'april': 4,
          'may': 5, 'june': 6, 'july': 7, 'august': 8,
          'september': 9, 'october': 10, 'november': 11, 'december': 12,
          'jan ': 1, 'feb ': 2, 'mar ': 3, 'apr ': 4, 'aug ': 8, 'sep ': 9, 'oct ': 10, 'nov ': 11, 'dec ': 12,
        };

        for (const [key, value] of Object.entries(months)) {
          if (cleanPrompt.includes(key)) {
            targetMonth = value;
            if (targetMonth > (now.getMonth() + 1)) {
              targetYear = now.getFullYear() - 1;
            }
            break;
          }
        }
      }

      if (cleanPrompt.includes("room")) {
        intent = "room_spending";
        const startDate = new Date(targetYear, targetMonth - 1, 1).toISOString();
        const endDate = targetMonth === 12 
          ? new Date(targetYear + 1, 0, 1).toISOString()
          : new Date(targetYear, targetMonth, 1).toISOString();

        const { data } = await supabase
          .from("room_expenses")
          .select("amount_paise, description, date")
          .gte("date", startDate)
          .lt("date", endDate);
        
        let totalPaise = 0;
        if (data) {
          totalPaise = data.reduce((sum, item) => sum + (item.amount_paise || 0), 0);
        }
        factData = {
          message: "Room/Group expenses data retrieved",
          total_room_expenses_rupees: totalPaise / 100,
          expenses: data
        };
      } else {
        const { data } = await supabase.rpc("get_monthly_spending", {
          p_month: targetMonth,
          p_year: targetYear,
        });
        factData = data;
      }
    } else if (cleanPrompt.includes("budget") || cleanPrompt.includes("over budget") || cleanPrompt.includes("budget status")) {
      intent = "budget_status";
      const { data } = await supabase.rpc("get_budget_status");
      factData = data;
    } else if (cleanPrompt.includes("largest expenses") || cleanPrompt.includes("biggest expenses")) {
      intent = "largest_expenses";
      const { data } = await supabase.rpc("get_largest_expenses");
      factData = data;
    }

    // -----------------------------------------------------------------
    // STEP 2: RAG RETRIEVAL (pgvector Context Memory)
    // -----------------------------------------------------------------
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiApiKey) {
      throw new Error("GEMINI_API_KEY is missing");
    }

    // Get embedding for the prompt
    const embedRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${geminiApiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: "models/text-embedding-004",
        content: { parts: [{ text: prompt }] },
        outputDimensionality: 384,
      }),
    });

    let ragData: any[] = [];

    if (embedRes.ok) {
      const embedData = await embedRes.json();
      const embedding = embedData.embedding?.values;

      if (embedding && embedding.length === 384) {
        // Query pgvector for memory
        const { data: memoryData } = await supabase.rpc("match_financial_memory", {
          query_embedding: embedding,
          match_count: 5,
          similarity_threshold: 0.50
        });

        if (memoryData && memoryData.length > 0) {
          ragData = memoryData;
        }
      }
    }

    let sourceType: "database" | "rag" | "hybrid" = "hybrid";
    if (factData === null && ragData.length > 0) sourceType = "rag";
    if (factData !== null && ragData.length === 0) sourceType = "database";
    if (factData === null && ragData.length === 0) sourceType = "hybrid"; // Default fallback

    // -----------------------------------------------------------------
    // STEP 3: HYBRID CONTEXT GENERATION WITH GEMINI
    // -----------------------------------------------------------------
    const systemPrompt = `You are ProFin, a personal financial assistant.
You answer using verified application data and relevant financial memory.

PostgreSQL verified data is authoritative for exact financial values.
RAG information is contextual memory and may be historical.

Never invent financial numbers, transactions, people, balances, dates or budgets.
If verified database data conflicts with RAG memory, always use the verified database data.
Never calculate an exact financial balance from RAG memory.
Never expose private information belonging to another user.
Use ₹ for Indian currency.
Answer naturally and concisely.
Do not mention SQL, RPC, embeddings, vector databases, RAG, Gemini or internal architecture to the user.
If required information is unavailable, clearly say that it is unavailable.

CONTEXT RECEIVED:
{
  "verified_financial_data": ${JSON.stringify(factData)},
  "relevant_financial_memory": ${JSON.stringify(ragData.map(r => ({ title: r.title, content: r.content, type: r.source_type })))}
}`;

    const combinedPrompt = `${systemPrompt}\n\nUSER PROMPT:\n${prompt}`;

    const geminiRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${geminiApiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          { role: "user", parts: [{ text: combinedPrompt }] }
        ],
        generationConfig: { temperature: 0.2 },
      }),
    });

    if (!geminiRes.ok) {
      const err = await geminiRes.text();
      let availableModels = "Could not fetch models";
      try {
        const listRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${geminiApiKey}`);
        const listData = await listRes.json();
        availableModels = listData.models?.map((m: any) => m.name).join(", ") || "No models returned";
      } catch (e) { }
      throw new Error(`Failed to generate response from Gemini: ${err} \n\nAVAILABLE MODELS: ${availableModels}`);
    }

    const geminiData = await geminiRes.json();
    const answer = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || "I'm sorry, I couldn't process your request.";

    // -----------------------------------------------------------------
    // STEP 4: RETURN SECURE STRUCTURED RESPONSE
    // -----------------------------------------------------------------
    return new Response(
      JSON.stringify({
        answer,
        source_type: sourceType,
        intent,
        fact_data: factData,
        rag_data: ragData,
        timestamp: new Date().toISOString()
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    console.error("AI Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
