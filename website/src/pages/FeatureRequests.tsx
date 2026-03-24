import { useState, useEffect, useCallback } from "react";
import type { MetaFunction } from "react-router";
import {
  ExternalLink,
  MessageSquare,
  Loader2,
  AlertCircle,
  Plus,
  Github,
} from "lucide-react";

export const meta: MetaFunction = () => [
  { title: "Issues & Features — The Annex" },
  {
    name: "description",
    content:
      "Browse open issues and feature requests for The Annex. Submit new ideas directly on GitHub.",
  },
];

const API_URL = "/.netlify/functions/feature-requests";
const NEW_ISSUE_URL =
  "https://github.com/ry4nolson/TheAnnex/issues/new?labels=feature-request&template=feature_request.yml";
const ALL_ISSUES_URL =
  "https://github.com/ry4nolson/TheAnnex/issues?q=is%3Aissue+label%3Afeature-request";

interface FeatureRequest {
  number: number;
  title: string;
  labels: string[];
  state: string;
  created_at: string;
  html_url: string;
  comments: number;
}

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

export default function FeatureRequests() {
  const [requests, setRequests] = useState<FeatureRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [fetchError, setFetchError] = useState("");

  const fetchRequests = useCallback(async () => {
    try {
      const res = await fetch(API_URL);
      if (!res.ok) throw new Error("Failed to load");
      const data = await res.json();
      setRequests(data.requests);
      setFetchError("");
    } catch {
      setFetchError("Could not load issues. Please try again later.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchRequests();
  }, [fetchRequests]);

  const openCount = requests.filter((r) => r.state === "open").length;
  const closedCount = requests.filter((r) => r.state !== "open").length;

  return (
    <>
      <section className="border-b border-white/5 py-16">
        <div className="mx-auto max-w-4xl px-4 text-center sm:px-6">
          <span className="section-badge">Community</span>
          <h1 className="section-heading mt-4 text-white">
            Issues & Features
          </h1>
          <p className="mx-auto mt-4 max-w-2xl text-brand-400">
            Feature requests and bug reports are tracked as{" "}
            <a
              href={ALL_ISSUES_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="text-brand-accent-light underline decoration-brand-accent/30 underline-offset-2 hover:decoration-brand-accent"
            >
              GitHub Issues
            </a>
            . Have an idea or found a bug? Open an issue — discussion and voting
            happens right on GitHub.
          </p>
          <div className="mt-8">
            <a
              href={NEW_ISSUE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="btn-primary"
            >
              <Plus size={18} />
              Request a Feature
            </a>
          </div>
        </div>
      </section>

      <section className="py-16">
        <div className="mx-auto max-w-4xl px-4 sm:px-6">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div className="flex items-center gap-4 text-sm text-brand-400">
              {!loading && !fetchError && (
                <>
                  <span className="flex items-center gap-1.5">
                    <span className="h-2 w-2 rounded-full bg-emerald-400" />
                    {openCount} open
                  </span>
                  <span className="flex items-center gap-1.5">
                    <span className="h-2 w-2 rounded-full bg-brand-500" />
                    {closedCount} closed
                  </span>
                </>
              )}
            </div>
            <a
              href={ALL_ISSUES_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-2 text-sm text-brand-400 transition-colors hover:text-white"
            >
              <Github size={16} />
              View all on GitHub
              <ExternalLink size={14} />
            </a>
          </div>

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
              <div className="py-12 text-center">
                <p className="text-sm text-brand-500">
                  No feature requests yet.
                </p>
                <a
                  href={NEW_ISSUE_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="mt-4 inline-flex items-center gap-2 text-sm text-brand-accent-light hover:underline"
                >
                  <Plus size={14} />
                  Be the first to request a feature
                </a>
              </div>
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
                        {new Date(req.created_at).toLocaleDateString("en-US", {
                          month: "short",
                          day: "numeric",
                          year: "numeric",
                        })}
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
      </section>
    </>
  );
}
