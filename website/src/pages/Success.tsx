import type { MetaFunction } from "react-router";
import { Link } from "react-router";
import { Download, Github, ArrowLeft, CheckCircle } from "lucide-react";

export const meta: MetaFunction = () => [
  { title: "Thank You — The Annex" },
  {
    name: "description",
    content: "Thanks for supporting The Annex! Download the latest release.",
  },
];

const RELEASE_URL = "https://github.com/ry4nolson/TheAnnex/releases/latest";
const GITHUB_URL = "https://github.com/ry4nolson/TheAnnex";

export default function Success() {
  return (
    <section className="flex flex-grow items-center justify-center py-24">
      <div className="mx-auto max-w-lg px-4 text-center sm:px-6">
        <div className="mx-auto mb-6 flex h-16 w-16 items-center justify-center rounded-full bg-emerald-500/10">
          <CheckCircle size={32} className="text-emerald-400" />
        </div>

        <h1 className="font-display text-3xl font-bold text-white sm:text-4xl">
          Thank you!
        </h1>
        <p className="mt-4 text-lg text-brand-300">
          Thanks for supporting continued development of The Annex. Download the
          latest release below.
        </p>

        <div className="mt-10 flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
          <a
            href={RELEASE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-primary px-8 py-3.5 text-base"
          >
            <Download size={18} />
            Download Latest Release
          </a>
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-secondary px-8 py-3.5 text-base"
          >
            <Github size={18} />
            View on GitHub
          </a>
        </div>

        <div className="mt-12">
          <Link
            to="/"
            className="inline-flex items-center gap-2 text-sm text-brand-400 transition-colors hover:text-white"
          >
            <ArrowLeft size={16} />
            Back to home
          </Link>
        </div>

        <div className="mt-16 rounded-2xl border border-white/5 bg-white/[0.02] p-6 text-left">
          <h2 className="font-display text-sm font-semibold text-white">
            Quick Start
          </h2>
          <ol className="mt-3 space-y-2 text-sm text-brand-400">
            <li>
              1. Open the DMG and drag The Annex to your Applications folder
            </li>
            <li>2. Launch — it appears in your menu bar</li>
            <li>3. Add your NAS and start syncing</li>
          </ol>
          <p className="mt-4 text-sm text-brand-500">
            Need help?{" "}
            <Link
              to="/docs"
              className="text-brand-accent-light hover:underline"
            >
              Read the docs
            </Link>
          </p>
        </div>
      </div>
    </section>
  );
}
