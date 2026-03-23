import { getStore } from "@netlify/blobs";
import { createHash } from "crypto";

const GITHUB_API = "https://api.github.com";
const TURNSTILE_VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify";

const VALID_CATEGORIES = ["ui", "sync", "monitoring", "integrations", "other"];
const MAX_TITLE_LENGTH = 120;
const MAX_DESCRIPTION_LENGTH = 2000;

const json = (statusCode, body) => ({
  statusCode,
  headers: {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  },
  body: JSON.stringify(body),
});

function githubHeaders() {
  return {
    Authorization: `Bearer ${process.env.GITHUB_TOKEN}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "TheAnnex-FeatureRequests",
  };
}

function hashIP(ip) {
  return createHash("sha256").update(ip).digest("hex").slice(0, 16);
}

function sanitize(str) {
  return str.replace(/[<>]/g, "").trim();
}

async function verifyTurnstile(token, ip) {
  const secret = process.env.TURNSTILE_SECRET_KEY;
  if (!secret) return { success: true };

  const res = await fetch(TURNSTILE_VERIFY_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ secret, response: token, remoteip: ip }),
  });
  return res.json();
}

async function checkRateLimit(ip) {
  const ipHash = hashIP(ip);
  const today = new Date().toISOString().slice(0, 10);
  const key = `rate:${ipHash}:${today}`;

  try {
    const store = getStore("feature_request_limits");
    const existing = await store.get(key);
    if (existing) return false;
    await store.set(key, new Date().toISOString());
    return true;
  } catch (err) {
    console.warn("Blob store unavailable, skipping rate limit:", err.message);
    return true;
  }
}

async function handleGet() {
  const owner = process.env.GITHUB_OWNER || "ry4nolson";
  const repo = process.env.GITHUB_REPO || "TheAnnex";
  const limit = parseInt(process.env.FEATURE_REQUESTS_LIST_LIMIT || "30", 10);

  const url = `${GITHUB_API}/repos/${owner}/${repo}/issues?labels=feature-request&state=all&per_page=${limit}&sort=created&direction=desc`;

  const res = await fetch(url, { headers: githubHeaders() });
  if (!res.ok) {
    const text = await res.text();
    console.error("GitHub API error:", res.status, text);
    return json(502, { error: "Failed to fetch feature requests" });
  }

  const issues = await res.json();
  const normalized = issues.map((issue) => ({
    number: issue.number,
    title: issue.title,
    body: issue.body,
    labels: issue.labels.map((l) => l.name),
    state: issue.state,
    created_at: issue.created_at,
    html_url: issue.html_url,
    comments: issue.comments,
  }));

  return json(200, { requests: normalized });
}

async function handlePost(event) {
  const contentType = event.headers["content-type"] || "";
  if (!contentType.includes("application/json")) {
    return json(400, { error: "Content-Type must be application/json" });
  }

  if (event.body && event.body.length > 10_000) {
    return json(413, { error: "Request body too large" });
  }

  let payload;
  try {
    payload = JSON.parse(event.body);
  } catch {
    return json(400, { error: "Invalid JSON" });
  }

  const { title, description, category, turnstileToken } = payload;

  if (!title || typeof title !== "string" || title.trim().length === 0) {
    return json(400, { error: "Title is required" });
  }
  if (title.length > MAX_TITLE_LENGTH) {
    return json(400, { error: `Title must be ${MAX_TITLE_LENGTH} characters or fewer` });
  }
  if (!description || typeof description !== "string" || description.trim().length === 0) {
    return json(400, { error: "Description is required" });
  }
  if (description.length > MAX_DESCRIPTION_LENGTH) {
    return json(400, { error: `Description must be ${MAX_DESCRIPTION_LENGTH} characters or fewer` });
  }
  if (!category || !VALID_CATEGORIES.includes(category)) {
    return json(400, { error: `Category must be one of: ${VALID_CATEGORIES.join(", ")}` });
  }
  if (!turnstileToken) {
    return json(400, { error: "CAPTCHA token is required" });
  }

  const clientIP =
    event.headers["x-nf-client-connection-ip"] ||
    event.headers["x-forwarded-for"]?.split(",")[0]?.trim() ||
    "unknown";

  const turnstileResult = await verifyTurnstile(turnstileToken, clientIP);
  if (!turnstileResult.success) {
    return json(403, { error: "CAPTCHA verification failed" });
  }

  const allowed = await checkRateLimit(clientIP);
  if (!allowed) {
    return json(429, { error: "You've already submitted a request today. Please try again tomorrow." });
  }

  const owner = process.env.GITHUB_OWNER || "ry4nolson";
  const repo = process.env.GITHUB_REPO || "TheAnnex";
  const cleanTitle = sanitize(title);
  const cleanDesc = sanitize(description);

  const issueBody = [
    cleanDesc,
    "",
    "---",
    `**Category:** ${category}`,
    `**Submitted:** ${new Date().toISOString()}`,
    `*Submitted via [theannex.app](https://theannex.app) feature request form*`,
  ].join("\n");

  const labels = ["feature-request", `category:${category}`];

  const res = await fetch(`${GITHUB_API}/repos/${owner}/${repo}/issues`, {
    method: "POST",
    headers: githubHeaders(),
    body: JSON.stringify({ title: cleanTitle, body: issueBody, labels }),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error("GitHub issue creation failed:", res.status, text);
    return json(502, { error: "Failed to create feature request" });
  }

  const issue = await res.json();
  return json(201, {
    message: "Feature request submitted!",
    url: issue.html_url,
    number: issue.number,
  });
}

export async function handler(event) {
  if (event.httpMethod === "OPTIONS") {
    return json(204, {});
  }

  if (event.httpMethod === "GET") {
    return handleGet();
  }

  if (event.httpMethod === "POST") {
    return handlePost(event);
  }

  return json(405, { error: "Method not allowed" });
}
