import { useState, useEffect, useRef, useCallback } from "react";
import type { MetaFunction } from "react-router";
import {
  Send,
  ExternalLink,
  MessageSquare,
  Loader2,
  AlertCircle,
  CheckCircle2,
} from "lucide-react";

export const meta: MetaFunction = () => [
  { title: "Feature Requests — The Annex" },
  {
    name: "description",
    content:
      "Submit and browse feature requests for The Annex. Requests become public GitHub Issues where discussion happens.",
  },
];

const TURNSTILE_SITE_KEY = import.meta.env.VITE_TURNSTILE_SITE_KEY || "";
const API_URL = "/.netlify/functions/feature-requests";

const CATEGORIES = [
  { value: "ui", label: "UI / UX" },
  { value: "sync", label: "Sync Engine" },
  { value: "monitoring", label: "Monitoring" },
  { value: "integrations", label: "Integrations" },
  { value: "other", label: "Other" },
];

interface FeatureRequest {
  number: number;
  title: string;
  body: string;
  labels: string[];
  state: string;
  created_at: string;
  html_url: string;
  comments: number;
}

type FormStatus = "idle" | "submitting" | "success" | "error";

function StateBadge({ state }: { state: string }) {
  const isOpen = state === "open";
  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium ${
        isOpen
          ? "bg-emerald-500/10 text-emerald-400"
          : "bg-brand-500/10 text-brand-400"
      }`}
    >
      <span
        className={`h-1.5 w-1.5 rounded-full ${
          isOpen ? "bg-emerald-400" : "bg-brand-500"
        }`}
      />
      {isOpen ? "Open" : "Closed"}
    </span>
  );
}

function CategoryBadge({ label }: { label: string }) {
  const name = label.replace("category:", "");
  return (
    <span className="inline-flex rounded-full bg-brand-accent/10 px-2.5 py-0.5 text-xs font-medium text-brand-accent-light">
      {name}
    </span>
  );
}

function TurnstileWidget({
  onToken,
  resetKey,
}: {
  onToken: (token: string) => void;
  resetKey: number;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const widgetIdRef = useRef<string | null>(null);

  useEffect(() => {
    if (!TURNSTILE_SITE_KEY) return;

    function renderWidget() {
      if (!containerRef.current || !window.turnstile) return;

      if (widgetIdRef.current !== null) {
        window.turnstile.reset(widgetIdRef.current);
        return;
      }

      widgetIdRef.current = window.turnstile.render(containerRef.current, {
        sitekey: TURNSTILE_SITE_KEY,
        theme: "dark",
        callback: onToken,
      });
    }

    if (window.turnstile) {
      renderWidget();
      return;
    }

    const existing = document.querySelector(
      'script[src*="challenges.cloudflare.com"]'
    );
    if (!existing) {
      const script = document.createElement("script");
      script.src =
        "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
      script.async = true;
      script.onload = renderWidget;
      document.head.appendChild(script);
    }
  }, [onToken, resetKey]);

  if (!TURNSTILE_SITE_KEY) return null;

  return <div ref={containerRef} className="mt-4" />;
}

declare global {
  interface Window {
    turnstile: {
      render: (
        container: HTMLElement,
        opts: { sitekey: string; theme: string; callback: (token: string) => void }
      ) => string;
      reset: (widgetId: string) => void;
    };
  }
}

export default function FeatureRequests() {
  const [requests, setRequests] = useState<FeatureRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [fetchError, setFetchError] = useState("");

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState("other");
  const [turnstileToken, setTurnstileToken] = useState("");
  const [resetKey, setResetKey] = useState(0);
  const [status, setStatus] = useState<FormStatus>("idle");
  const [errorMessage, setErrorMessage] = useState("");
  const [successUrl, setSuccessUrl] = useState("");

  const fetchRequests = useCallback(async () => {
    try {
      const res = await fetch(API_URL);
      if (!res.ok) throw new Error("Failed to load");
      const data = await res.json();
      setRequests(data.requests);
      setFetchError("");
    } catch {
      setFetchError("Could not load feature requests. Please try again later.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchRequests();
  }, [fetchRequests]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim() || !description.trim()) return;

    setStatus("submitting");
    setErrorMessage("");

    try {
      const res = await fetch(API_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          title: title.trim(),
          description: description.trim(),
          category,
          turnstileToken,
        }),
      });

      const data = await res.json();

      if (!res.ok) {
        setStatus("error");
        setErrorMessage(data.error || "Something went wrong.");
        return;
      }

      setStatus("success");
      setSuccessUrl(data.url);
      setTitle("");
      setDescription("");
      setCategory("other");
      setTurnstileToken("");
      setResetKey((k) => k + 1);
      fetchRequests();
    } catch {
      setStatus("error");
      setErrorMessage("Network error. Please try again.");
    }
  }

  return (
    <>
      <section className="border-b border-white/5 py-16">
        <div className="mx-auto max-w-4xl px-4 text-center sm:px-6">
          <span className="section-badge">Community</span>
          <h1 className="section-heading mt-4 text-white">Feature Requests</h1>
          <p className="mx-auto mt-4 max-w-2xl text-brand-400">
            Have an idea for The Annex? Submit it below. Each request becomes a
            public{" "}
            <a
              href="https://github.com/ry4nolson/TheAnnex/issues?q=is%3Aissue+label%3Afeature-request"
              target="_blank"
              rel="noopener noreferrer"
              className="text-brand-accent-light underline decoration-brand-accent/30 underline-offset-2 hover:decoration-brand-accent"
            >
              GitHub Issue
            </a>{" "}
            where discussion and voting happens.
          </p>
        </div>
      </section>

      <section className="py-16">
        <div className="mx-auto max-w-4xl px-4 sm:px-6">
          <div className="grid gap-12 lg:grid-cols-5">
            {/* Form */}
            <div className="lg:col-span-2">
              <h2 className="font-display text-lg font-bold text-white">
                Submit a Request
              </h2>
              <p className="mt-1 text-sm text-brand-400">
                One request per day. Be specific about the problem you&apos;re
                solving.
              </p>

              <form onSubmit={handleSubmit} className="mt-6 space-y-4">
                <div>
                  <label
                    htmlFor="fr-title"
                    className="block text-sm font-medium text-brand-300"
                  >
                    Title
                  </label>
                  <input
                    id="fr-title"
                    type="text"
                    required
                    maxLength={120}
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    placeholder="e.g. Bidirectional sync option"
                    className="mt-1 w-full rounded-lg border border-white/10 bg-white/5 px-4 py-2.5 text-sm text-white placeholder-brand-600 outline-none transition-colors focus:border-brand-accent/50 focus:ring-1 focus:ring-brand-accent/30"
                  />
                </div>

                <div>
                  <label
                    htmlFor="fr-category"
                    className="block text-sm font-medium text-brand-300"
                  >
                    Category
                  </label>
                  <select
                    id="fr-category"
                    value={category}
                    onChange={(e) => setCategory(e.target.value)}
                    className="mt-1 w-full rounded-lg border border-white/10 bg-white/5 px-4 py-2.5 text-sm text-white outline-none transition-colors focus:border-brand-accent/50 focus:ring-1 focus:ring-brand-accent/30"
                  >
                    {CATEGORIES.map((c) => (
                      <option key={c.value} value={c.value}>
                        {c.label}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label
                    htmlFor="fr-description"
                    className="block text-sm font-medium text-brand-300"
                  >
                    Description
                  </label>
                  <textarea
                    id="fr-description"
                    required
                    maxLength={2000}
                    rows={5}
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    placeholder="Describe the feature, the problem it solves, and any context that would help."
                    className="mt-1 w-full rounded-lg border border-white/10 bg-white/5 px-4 py-2.5 text-sm text-white placeholder-brand-600 outline-none transition-colors focus:border-brand-accent/50 focus:ring-1 focus:ring-brand-accent/30"
                  />
                  <p className="mt-1 text-xs text-brand-600">
                    {description.length}/2000
                  </p>
                </div>

                <TurnstileWidget onToken={setTurnstileToken} resetKey={resetKey} />

                <button
                  type="submit"
                  disabled={
                    status === "submitting" ||
                    !title.trim() ||
                    !description.trim() ||
                    (!!TURNSTILE_SITE_KEY && !turnstileToken)
                  }
                  className="btn-primary w-full disabled:cursor-not-allowed disabled:opacity-50"
                >
                  {status === "submitting" ? (
                    <>
                      <Loader2 size={16} className="animate-spin" />
                      Submitting…
                    </>
                  ) : (
                    <>
                      <Send size={16} />
                      Submit Request
                    </>
                  )}
                </button>

                {status === "success" && (
                  <div className="flex items-start gap-2 rounded-lg border border-emerald-500/20 bg-emerald-500/5 px-4 py-3 text-sm text-emerald-400">
                    <CheckCircle2 size={16} className="mt-0.5 shrink-0" />
                    <div>
                      Request submitted!{" "}
                      {successUrl && (
                        <a
                          href={successUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="underline underline-offset-2 hover:text-emerald-300"
                        >
                          View on GitHub
                        </a>
                      )}
                    </div>
                  </div>
                )}

                {status === "error" && (
                  <div className="flex items-start gap-2 rounded-lg border border-red-500/20 bg-red-500/5 px-4 py-3 text-sm text-red-400">
                    <AlertCircle size={16} className="mt-0.5 shrink-0" />
                    <span>{errorMessage}</span>
                  </div>
                )}
              </form>
            </div>

            {/* Request list */}
            <div className="lg:col-span-3">
              <h2 className="font-display text-lg font-bold text-white">
                Existing Requests
              </h2>
              <p className="mt-1 text-sm text-brand-400">
                Click any request to join the discussion on GitHub.
              </p>

              <div className="mt-6 space-y-3">
                {loading && (
                  <div className="flex items-center justify-center py-12 text-brand-500">
                    <Loader2 size={24} className="animate-spin" />
                  </div>
                )}

                {fetchError && (
                  <div className="flex items-center gap-2 rounded-lg border border-red-500/20 bg-red-500/5 px-4 py-3 text-sm text-red-400">
                    <AlertCircle size={16} className="shrink-0" />
                    {fetchError}
                  </div>
                )}

                {!loading && !fetchError && requests.length === 0 && (
                  <p className="py-8 text-center text-sm text-brand-500">
                    No feature requests yet. Be the first!
                  </p>
                )}

                {requests.map((req) => (
                  <a
                    key={req.number}
                    href={req.html_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="group block rounded-xl border border-white/5 bg-white/[0.02] p-4 transition-all hover:border-white/10 hover:bg-white/[0.04]"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <StateBadge state={req.state} />
                          {req.labels
                            .filter((l) => l.startsWith("category:"))
                            .map((l) => (
                              <CategoryBadge key={l} label={l} />
                            ))}
                        </div>
                        <h3 className="mt-2 font-medium text-white group-hover:text-brand-accent-light">
                          {req.title}
                        </h3>
                        <div className="mt-2 flex items-center gap-4 text-xs text-brand-500">
                          <span>
                            #{req.number} opened{" "}
                            {new Date(req.created_at).toLocaleDateString(
                              "en-US",
                              {
                                month: "short",
                                day: "numeric",
                                year: "numeric",
                              }
                            )}
                          </span>
                          {req.comments > 0 && (
                            <span className="flex items-center gap-1">
                              <MessageSquare size={12} />
                              {req.comments}
                            </span>
                          )}
                        </div>
                      </div>
                      <ExternalLink
                        size={16}
                        className="mt-1 shrink-0 text-brand-600 transition-colors group-hover:text-brand-accent-light"
                      />
                    </div>
                  </a>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
