const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type ChatRole = "user" | "assistant";

type ChatHistoryItem = {
  role: ChatRole;
  content: string;
};

type ChatContext = {
  profile_name?: string | null;
  profile_age?: number | null;
  medical_history?: string | null;
  caregiver_role?: string | null;
  baby_name?: string | null;
  planning_baby?: boolean | null;
  latest_week?: number | null;
  latest_risk_label?: string | null;
  latest_risk_score?: number | null;
  latest_systolic?: number | null;
  latest_diastolic?: number | null;
  latest_blood_sugar?: number | null;
  latest_body_temp?: number | null;
  latest_bmi?: number | null;
  latest_heart_rate?: number | null;
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

function buildSystemPrompt(context: ChatContext) {
  const lines = [
    "Sen Gebelik Rehberi adli, Turkce yanit veren destekleyici bir gebelik asistanisin.",
    "Kisa, net, sicak ve anlasilir yanit ver.",
    "Tibbi tani koyma, kesin yargili konusma ve acil durumlari hafife alma.",
    "Kanama, siddetli agri, bayilma, nefes darligi, yuksek ates, su gelmesi veya bebek hareketlerinde belirgin azalma varsa acil degerlendirme oner.",
    "Yanitinda kullanicinin baglamini uygunsa kisaca kullan ama gereksiz tekrar etme.",
  ];

  const contextLines = <string>[];
  if (context.profile_name) {
    contextLines.push(`Kullanici adi: ${context.profile_name}`);
  }
  if (context.caregiver_role) {
    contextLines.push(`Rol: ${context.caregiver_role}`);
  }
  if (context.baby_name) {
    contextLines.push(`Bebek adi: ${context.baby_name}`);
  }
  if (typeof context.planning_baby === "boolean") {
    contextLines.push(
      `Durum: ${context.planning_baby ? "Bebek planlama" : "Aktif gebelik takibi"}`,
    );
  }
  if (context.profile_age != null) {
    contextLines.push(`Yas: ${context.profile_age}`);
  }
  if (context.medical_history) {
    contextLines.push(`Saglik notu: ${context.medical_history}`);
  }
  if (context.latest_week != null) {
    contextLines.push(`Son kayitli hafta: ${context.latest_week}`);
  }
  if (context.latest_risk_label) {
    contextLines.push(`Son risk etiketi: ${context.latest_risk_label}`);
  }
  if (context.latest_risk_score != null) {
    contextLines.push(
      `Son risk skoru: ${(context.latest_risk_score * 100).toFixed(0)}%`,
    );
  }

  const latestMetrics = [
    context.latest_systolic != null ? `sistolik ${context.latest_systolic}` : "",
    context.latest_diastolic != null ? `diastolik ${context.latest_diastolic}` : "",
    context.latest_blood_sugar != null
      ? `kan sekeri ${context.latest_blood_sugar}`
      : "",
    context.latest_body_temp != null
      ? `vucut sicakligi ${context.latest_body_temp}`
      : "",
    context.latest_bmi != null ? `BMI ${context.latest_bmi}` : "",
    context.latest_heart_rate != null ? `nabiz ${context.latest_heart_rate}` : "",
  ].filter(Boolean);
  if (latestMetrics.isNotEmpty) {
    contextLines.push(`Son olcumler: ${latestMetrics.join(", ")}`);
  }

  if (contextLines.isNotEmpty) {
    lines.push(`Baglam:\n${contextLines.join("\n")}`);
  }

  return lines.join("\n");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const apiKey = Deno.env.get("OPENAI_API_KEY");
  const model = Deno.env.get("OPENAI_MODEL") || "gpt-4.1-mini";
  if (!apiKey) {
    return jsonResponse({ error: "OPENAI_API_KEY tanimli degil." }, 500);
  }

  let payload: {
    message?: string;
    history?: ChatHistoryItem[];
    context?: ChatContext;
  };
  try {
    payload = await req.json();
  } catch (_) {
    return jsonResponse({ error: "Gecersiz istek govdesi." }, 400);
  }

  const message = payload.message?.trim() ?? "";
  if (!message) {
    return jsonResponse({ error: "Mesaj bos olamaz." }, 400);
  }

  const history = Array.isArray(payload.history)
    ? payload.history
        .filter((item) =>
          item &&
          (item.role === "user" || item.role === "assistant") &&
          typeof item.content === "string" &&
          item.content.trim().length > 0
        )
        .slice(-10)
    : [];

  const upstream = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      stream: true,
      temperature: 0.6,
      messages: [
        {
          role: "system",
          content: buildSystemPrompt(payload.context ?? {}),
        },
        ...history,
        {
          role: "user",
          content: message,
        },
      ],
    }),
  });

  if (!upstream.ok || !upstream.body) {
    const errorText = await upstream.text();
    return jsonResponse(
      {
        error: errorText || "OpenAI akisi baslatilamadi.",
      },
      upstream.status || 500,
    );
  }

  const encoder = new TextEncoder();
  const decoder = new TextDecoder();

  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      const send = (data: unknown) => {
        controller.enqueue(
          encoder.encode(`data: ${JSON.stringify(data)}\n\n`),
        );
      };

      let buffer = "";
      try {
        for await (const chunk of upstream.body!) {
          buffer += decoder.decode(chunk, { stream: true });

          while (buffer.includes("\n")) {
            const newlineIndex = buffer.indexOf("\n");
            const rawLine = buffer.slice(0, newlineIndex).trim();
            buffer = buffer.slice(newlineIndex + 1);

            if (!rawLine.startsWith("data:")) continue;
            const data = rawLine.slice(5).trim();
            if (!data) continue;

            if (data === "[DONE]") {
              controller.enqueue(encoder.encode("data: [DONE]\n\n"));
              controller.close();
              return;
            }

            const parsed = JSON.parse(data);
            const delta = parsed?.choices?.[0]?.delta?.content;
            if (typeof delta === "string" && delta.length > 0) {
              send({ type: "delta", delta });
            }
          }
        }

        controller.enqueue(encoder.encode("data: [DONE]\n\n"));
        controller.close();
      } catch (error) {
        send({
          type: "error",
          error: error instanceof Error ? error.message : "Akis beklenmedik sekilde kesildi.",
        });
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: {
      ...corsHeaders,
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
      "X-Accel-Buffering": "no",
    },
  });
});
