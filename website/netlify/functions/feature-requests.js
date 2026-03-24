const GITHUB_API = "https://api.github.com";

const json = (statusCode, body) => ({
  statusCode,
  headers: {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
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

export async function handler(event) {
  if (event.httpMethod !== "GET") {
    return json(405, { error: "Method not allowed" });
  }

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
    labels: issue.labels.map((l) => l.name),
    state: issue.state,
    created_at: issue.created_at,
    html_url: issue.html_url,
    comments: issue.comments,
  }));

  return json(200, { requests: normalized });
}
