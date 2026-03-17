import { useState, useEffect, useCallback } from "react";
import { Link, useLocation } from "react-router";
import { Menu, X, Github } from "lucide-react";

const NAV_LINKS = [
  { path: "/", label: "Home" },
  { path: "/docs", label: "Docs" },
  { path: "/changelog", label: "Changelog" },
];

const GITHUB_URL = "https://github.com/ry4nolson/TheAnnex";

export default function Header() {
  const [isOpen, setIsOpen] = useState(false);
  const location = useLocation();

  const isActive = (path: string) => location.pathname === path;

  const handleEscape = useCallback(
    (e: KeyboardEvent) => {
      if (e.key === "Escape" && isOpen) {
        setIsOpen(false);
      }
    },
    [isOpen]
  );

  useEffect(() => {
    document.addEventListener("keydown", handleEscape);
    return () => document.removeEventListener("keydown", handleEscape);
  }, [handleEscape]);

  useEffect(() => {
    setIsOpen(false);
  }, [location.pathname]);

  return (
    <header className="sticky top-0 z-50 border-b border-white/5 bg-brand-950/80 backdrop-blur-xl">
      <nav className="mx-auto max-w-6xl px-4 sm:px-6" aria-label="Main navigation">
        <div className="flex h-16 items-center justify-between">
          <Link to="/" className="flex items-center gap-3">
            <img
              src="/app-icon.png"
              alt=""
              className="h-8 w-8 rounded-lg"
            />
            <span className="font-display text-lg font-bold text-white">
              The Annex
            </span>
          </Link>

          <div className="hidden items-center gap-1 md:flex">
            {NAV_LINKS.map((link) => (
              <Link
                key={link.path}
                to={link.path}
                aria-current={isActive(link.path) ? "page" : undefined}
                className={`rounded-lg px-4 py-2 text-sm font-medium transition-all duration-200 ${
                  isActive(link.path)
                    ? "bg-white/10 text-white"
                    : "text-brand-300 hover:bg-white/5 hover:text-white"
                }`}
              >
                {link.label}
              </Link>
            ))}
            <a
              href={GITHUB_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="ml-2 rounded-lg p-2 text-brand-400 transition-colors hover:bg-white/5 hover:text-white"
              aria-label="GitHub (opens in new tab)"
            >
              <Github size={20} />
            </a>
            <a href="/#buy" className="btn-primary ml-3 py-2 text-sm">
              Support $5
            </a>
          </div>

          <div className="flex items-center gap-2 md:hidden">
            <a href="/#buy" className="btn-primary py-1.5 px-4 text-xs">
              Support $5
            </a>
            <button
              className="rounded-lg p-2 text-brand-300 hover:bg-white/5"
              onClick={() => setIsOpen(!isOpen)}
              aria-label={isOpen ? "Close menu" : "Open menu"}
              aria-expanded={isOpen}
              aria-controls="mobile-nav"
            >
              {isOpen ? <X size={22} /> : <Menu size={22} />}
            </button>
          </div>
        </div>

        {isOpen && (
          <div
            id="mobile-nav"
            className="border-t border-white/5 pb-4 pt-2 md:hidden"
            role="navigation"
            aria-label="Mobile navigation"
          >
            {NAV_LINKS.map((link) => (
              <Link
                key={link.path}
                to={link.path}
                aria-current={isActive(link.path) ? "page" : undefined}
                className={`block rounded-lg px-4 py-3 text-sm font-medium transition-all ${
                  isActive(link.path)
                    ? "bg-white/10 text-white"
                    : "text-brand-300 hover:bg-white/5 hover:text-white"
                }`}
              >
                {link.label}
              </Link>
            ))}
            <a
              href={GITHUB_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="mt-1 flex items-center gap-2 rounded-lg px-4 py-3 text-sm font-medium text-brand-300 hover:bg-white/5 hover:text-white"
            >
              <Github size={18} />
              GitHub
              <span className="sr-only"> (opens in new tab)</span>
            </a>
          </div>
        )}
      </nav>
    </header>
  );
}
