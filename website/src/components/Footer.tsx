import { Link } from "react-router";
import { Github, ExternalLink } from "lucide-react";

const GITHUB_URL = "https://github.com/ry4nolson/TheAnnex";
const SPONSOR_URL = "https://www.texasbeardcompany.com";

export default function Footer() {
  return (
    <footer className="border-t border-white/5 bg-brand-950">
      <div className="mx-auto max-w-6xl px-4 py-12 sm:px-6">
        <div className="grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
          <div className="sm:col-span-2 lg:col-span-1">
            <div className="flex items-center gap-3">
              <img
                src="/app-icon.png"
                alt=""
                className="h-8 w-8 rounded-lg"
              />
              <span className="font-display text-lg font-bold text-white">
                The Annex
              </span>
            </div>
            <p className="mt-3 text-sm leading-relaxed text-brand-400">
              A macOS menu bar app that syncs your folders to your NAS.
            </p>
          </div>

          <div>
            <h3 className="text-xs font-semibold uppercase tracking-widest text-brand-400">
              Product
            </h3>
            <ul className="mt-4 space-y-2.5">
              <li>
                <Link
                  to="/docs"
                  className="text-sm text-brand-300 transition-colors hover:text-white"
                >
                  Documentation
                </Link>
              </li>
              <li>
                <Link
                  to="/changelog"
                  className="text-sm text-brand-300 transition-colors hover:text-white"
                >
                  Changelog
                </Link>
              </li>
              <li>
                <a
                  href={`${GITHUB_URL}/releases/latest`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 text-sm text-brand-300 transition-colors hover:text-white"
                >
                  Latest Release
                  <ExternalLink size={12} />
                </a>
              </li>
            </ul>
          </div>

          <div>
            <h3 className="text-xs font-semibold uppercase tracking-widest text-brand-400">
              Source
            </h3>
            <ul className="mt-4 space-y-2.5">
              <li>
                <a
                  href={GITHUB_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 text-sm text-brand-300 transition-colors hover:text-white"
                >
                  <Github size={14} />
                  GitHub
                </a>
              </li>
              <li>
                <a
                  href={`${GITHUB_URL}/issues`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 text-sm text-brand-300 transition-colors hover:text-white"
                >
                  Report a Bug
                  <ExternalLink size={12} />
                </a>
              </li>
              <li>
                <a
                  href={`${GITHUB_URL}/blob/main/LICENSE`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 text-sm text-brand-300 transition-colors hover:text-white"
                >
                  GPL-3.0 License
                  <ExternalLink size={12} />
                </a>
              </li>
            </ul>
          </div>

          <div>
            <h3 className="text-xs font-semibold uppercase tracking-widest text-brand-400">
              Sponsor
            </h3>
            <a
              href={SPONSOR_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="mt-4 inline-block"
            >
              <span className="text-sm text-brand-300 transition-colors hover:text-white">
                Texas Beard Company
              </span>
            </a>
          </div>
        </div>
      </div>

      <div className="border-t border-white/5">
        <div className="mx-auto max-w-6xl px-4 py-6 sm:px-6">
          <p className="text-center text-xs text-brand-500">
            &copy; {new Date().getFullYear()} The Annex. Open source under
            GPL-3.0.
          </p>
        </div>
      </div>
    </footer>
  );
}
