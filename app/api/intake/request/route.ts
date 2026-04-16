import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { randomUUID } from "node:crypto";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL ?? "";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";

const RESEND_API_KEY = process.env.RESEND_API_KEY ?? "";
const INTAKE_EMAIL_FROM = process.env.INTAKE_EMAIL_FROM ?? "noreply@lemma.local";
const INTAKE_EMAIL_TO = ["juliushsu@gmail.com", "team@lemmaofficial.com"];

function ok(data: Record<string, unknown>, status = 200) {
  return NextResponse.json(
    {
      schema_version: "intake.request.v1",
      data,
      meta: {
        request_id: randomUUID(),
        timestamp: new Date().toISOString()
      },
      error: null
    },
    { status }
  );
}

function fail(code: string, message: string, status = 400, details: Record<string, unknown> | null = null) {
  return NextResponse.json(
    {
      schema_version: "intake.request.v1",
      data: {},
      meta: {
        request_id: randomUUID(),
        timestamp: new Date().toISOString()
      },
      error: { code, message, details }
    },
    { status }
  );
}

async function sendIntakeEmail(payload: {
  intakeId: string;
  name: string;
  email: string;
  company: string;
  role: string | null;
  team_size: string | null;
  message: string | null;
  request_type: string;
  source_path: string | null;
}) {
  if (!RESEND_API_KEY) {
    return { sent: false, status: "not_configured" as const, error: "RESEND_API_KEY is not configured" };
  }

  const subject = `[Lemma Intake][${payload.request_type}] ${payload.company} - ${payload.name}`;
  const text = [
    `Intake ID: ${payload.intakeId}`,
    `Type: ${payload.request_type}`,
    `Name: ${payload.name}`,
    `Email: ${payload.email}`,
    `Company: ${payload.company}`,
    `Role: ${payload.role ?? ""}`,
    `Team Size: ${payload.team_size ?? ""}`,
    `Source Path: ${payload.source_path ?? ""}`,
    `Message:\n${payload.message ?? ""}`
  ].join("\n");

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      from: INTAKE_EMAIL_FROM,
      to: INTAKE_EMAIL_TO,
      subject,
      text
    })
  });

  if (!response.ok) {
    const body = await response.text();
    return { sent: false, status: "failed" as const, error: `resend_${response.status}: ${body.slice(0, 500)}` };
  }

  return { sent: true, status: "sent" as const, error: null };
}

export async function POST(request: Request) {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return fail("CONFIG_MISSING", "Supabase service configuration is missing", 500);
  }

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return fail("INVALID_JSON", "Request body must be valid JSON", 400);
  }

  const name = String(body.name ?? "").trim();
  const email = String(body.email ?? "").trim().toLowerCase();
  const company = String(body.company ?? "").trim();
  const role = body.role == null ? null : String(body.role).trim() || null;
  const team_size = body.team_size == null ? null : String(body.team_size).trim() || null;
  const message = body.message == null ? null : String(body.message).trim() || null;
  const request_type_raw = String(body.request_type ?? "request_demo").trim();
  const request_type = ["request_demo", "apply_access", "other"].includes(request_type_raw)
    ? request_type_raw
    : "other";
  const source_path = body.source_path == null ? null : String(body.source_path).trim() || null;

  if (!name || !email || !company) {
    return fail("INVALID_REQUEST", "name/email/company are required", 400);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: inserted, error: insertError } = await supabase
    .from("intake_requests")
    .insert({
      name,
      email,
      company,
      role,
      team_size,
      message,
      request_type,
      source_path,
      email_delivery_status: "pending"
    })
    .select("id,created_at")
    .single();

  if (insertError || !inserted) {
    return fail("INTERNAL_ERROR", "Failed to save intake request", 500, {
      reason: insertError?.message ?? "unknown"
    });
  }

  const emailResult = await sendIntakeEmail({
    intakeId: inserted.id,
    name,
    email,
    company,
    role,
    team_size,
    message,
    request_type,
    source_path
  });

  await supabase
    .from("intake_requests")
    .update({
      email_delivery_status: emailResult.status,
      email_delivery_error: emailResult.error
    })
    .eq("id", inserted.id);

  return ok(
    {
      intake_id: inserted.id,
      created_at: inserted.created_at,
      email_delivery_status: emailResult.status,
      notified_recipients: INTAKE_EMAIL_TO,
      request_type
    },
    201
  );
}
