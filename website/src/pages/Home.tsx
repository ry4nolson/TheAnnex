import {
  ArrowRight,
  FolderSync,
  Link2,
  MonitorSmartphone,
  Gauge,
  HardDrive,
  Shield,
  Wifi,
  Terminal,
  Github,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import type { MetaFunction } from "react-router";

export const meta: MetaFunction = () => [
  { title: "The Annex — Sync Your Mac to Your NAS" },
  {
    name: "description",
    content:
      "A macOS menu bar app that syncs your folders to your NAS. Rsync-powered, with optional symlink mode so your files live on the NAS while still feeling local.",
  },
];

const GITHUB_URL = "https://github.com/ry4nolson/TheAnnex";
const RELEASES_URL = "https://github.com/ry4nolson/TheAnnex/releases/latest";

const SCREENSHOTS: { src: string; alt: string }[] = [
  { src: "/screenshots/GeneralTab.png", alt: "General tab — devices and status" },
  { src: "/screenshots/SyncFoldersTab.png", alt: "Sync Folders tab — sync pairs and controls" },
  { src: "/screenshots/ActivityLogTab.png", alt: "Activity Log tab — searchable sync log" },
  { src: "/screenshots/StatisticsTab.png", alt: "Statistics tab — charts and transfer metrics" },
  { src: "/screenshots/AdvancedTab.png", alt: "Advanced tab — scheduling and rsync options" },
  { src: "/screenshots/WhatsNewTab.png", alt: "What's New tab — changelog inside the app" },
  { src: "/screenshots/AboutTab.png", alt: "About tab — version and update controls" },
];

const FEATURES = [
  {
    icon: FolderSync,
    title: "Rsync-Powered Sync",
    description:
      "Queue-based sync engine with progress tracking, bandwidth throttling, and up to 2 concurrent transfers.",
  },
  {
    icon: Link2,
    title: "Symlink Mode",
    description:
      "Replace local folders with symlinks to your NAS. Apps read and write directly — your files live on the NAS but feel local.",
  },
  {
    icon: MonitorSmartphone,
    title: "Multi-NAS Support",
    description:
      "Configure unlimited NAS devices. Assign sync folders to specific devices. Bonjour auto-discovery finds them on your network.",
  },
  {
    icon: Gauge,
    title: "Live Monitoring",
    description:
      "Connection quality, latency, disk space, and online status — all visible at a glance from the menu bar.",
  },
  {
    icon: HardDrive,
    title: "Auto-Mount Shares",
    description:
      "SMB shares mount automatically when a NAS comes online. Credentials stored securely in your Keychain.",
  },
  {
    icon: Shield,
    title: "Offline Resilience",
    description:
      "When your NAS goes offline, symlinks are replaced with local copies. When it returns, changes sync back automatically.",
  },
  {
    icon: Wifi,
    title: "WiFi & Power Aware",
    description:
      "Restrict syncs to specific WiFi networks. Pause when on battery. Sync only when conditions are right.",
  },
  {
    icon: Terminal,
    title: "Open Source",
    description:
      "GPL-3.0 licensed. Download free releases, build from source, or chip in to support development.",
  },
];

const USE_CASES = [
  {
    title: "Offload a project folder",
    description:
      "Your MacBook is running low on space, but your NAS has terabytes free. Sync ~/Projects to the NAS, enable symlink mode, and apps read/write directly. Take your laptop to a coffee shop — The Annex restores a local copy. Get home — it syncs back and re-symlinks.",
  },
  {
    title: "Back up multiple Macs",
    description:
      "Your Mac Studio syncs Documents, Music, and Pictures every 5 minutes. Your MacBook syncs Documents and Desktop only on home WiFi. Each Mac gets its own NAS path. Activity Log and Statistics show exactly what moved and when.",
  },
  {
    title: "Manage multiple NAS devices",
    description:
      "Primary Synology for everyday storage, secondary QNAP for cold backups. Set the Synology as default, assign specific folders to the QNAP. The Annex monitors both independently — online status, disk space, connection quality.",
  },
];

export default function Home() {
  const [buying, setBuying] = useState(false);
  const [shotIndex, setShotIndex] = useState(0);
  const [isHoveringShots, setIsHoveringShots] = useState(false);
  const [lightboxOpen, setLightboxOpen] = useState(false);

  const prefersReducedMotion = useMemo(() => {
    if (typeof window === "undefined") return false;
    return window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches ?? false;
  }, []);

  useEffect(() => {
    if (prefersReducedMotion) return;
    if (isHoveringShots) return;
    if (lightboxOpen) return;
    if (SCREENSHOTS.length <= 1) return;

    const id = window.setInterval(() => {
      setShotIndex((i) => (i + 1) % SCREENSHOTS.length);
    }, 6500);

    return () => window.clearInterval(id);
  }, [isHoveringShots, lightboxOpen, prefersReducedMotion]);

  useEffect(() => {
    if (!lightboxOpen) return;
    function onKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") setLightboxOpen(false);
      if (e.key === "ArrowLeft") {
        setShotIndex((i) => (i - 1 + SCREENSHOTS.length) % SCREENSHOTS.length);
      }
      if (e.key === "ArrowRight") {
        setShotIndex((i) => (i + 1) % SCREENSHOTS.length);
      }
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [lightboxOpen]);

  async function handleBuy() {
    setBuying(true);
    try {
      const res = await fetch("/.netlify/functions/checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
      });
      const data = await res.json();
      if (data.url) {
        window.location.href = data.url;
      }
    } catch {
      setBuying(false);
    }
  }

  return (
    <>
      {/* Hero */}
      <section className="relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-b from-brand-accent/5 via-transparent to-transparent" />
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top,rgba(99,102,241,0.08),transparent_60%)]" />
        <div className="relative mx-auto max-w-6xl px-4 pb-20 pt-24 sm:px-6 sm:pt-32 lg:pt-40">
          <div className="mx-auto max-w-3xl text-center">
            <div className="mb-8 flex justify-center">
              <img
                src="/app-icon.png"
                alt="The Annex app icon"
                className="h-24 w-24 rounded-2xl shadow-2xl shadow-brand-accent/20 sm:h-32 sm:w-32"
              />
            </div>
            <h1 className="font-display text-4xl font-bold tracking-tight text-white sm:text-5xl lg:text-6xl">
              Sync your Mac
              <br />
              <span className="text-brand-accent-light">to your NAS</span>
            </h1>
            <p className="mx-auto mt-6 max-w-2xl text-lg leading-relaxed text-brand-300 sm:text-xl">
              A macOS menu bar app that keeps your folders backed up to your
              NAS — and optionally symlinks them so your files live on the NAS
              while still feeling local.
            </p>
            <div className="mt-10 flex flex-col items-center justify-center gap-4 sm:flex-row">
              <button
                onClick={handleBuy}
                disabled={buying}
                className="btn-primary px-8 py-3.5 text-base disabled:opacity-60"
              >
                {buying ? "Redirecting..." : "Support for $5"}
                {!buying && <ArrowRight size={18} />}
              </button>
              <a
                href={RELEASES_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="btn-secondary px-8 py-3.5 text-base"
              >
                <Github size={18} />
                Free download
              </a>
            </div>
            <p className="mt-4 text-sm text-brand-500">
              macOS 12+ &middot; Apple Silicon & Intel &middot; Open source
              (GPL-3.0)
            </p>
            <p className="mt-3 text-sm text-brand-400">
              Want to support the project? The $5 checkout is optional.
            </p>
          </div>
        </div>
      </section>

      {/* Screenshots */}
      <section className="border-t border-white/5 py-20">
        <div className="mx-auto max-w-6xl px-4 sm:px-6">
          <div className="text-center">
            <span className="section-badge">Screenshots</span>
            <h2 className="section-heading mt-4 text-white">
              A quick look inside
            </h2>
            <p className="mx-auto mt-4 max-w-2xl text-brand-400">
              The Annex lives in your menu bar, but the full app gives you
              devices, sync folders, logs, stats, and advanced controls.
            </p>
          </div>

          <div
            className="mt-12"
            onMouseEnter={() => setIsHoveringShots(true)}
            onMouseLeave={() => setIsHoveringShots(false)}
          >
            <div className="mx-auto w-full max-w-3xl lg:max-w-[50%]">
              <div className="relative overflow-hidden rounded-2xl border border-white/5 bg-white/[0.02]">
              <div className="relative aspect-[16/12] w-full bg-brand-900">
                {SCREENSHOTS.map((shot, i) => (
                  <button
                    key={shot.src}
                    type="button"
                    onClick={() => {
                      setShotIndex(i);
                      setLightboxOpen(true);
                    }}
                    className="absolute inset-0"
                    aria-hidden={i !== shotIndex}
                    tabIndex={i === shotIndex ? 0 : -1}
                  >
                    <img
                      src={shot.src}
                      alt={i === shotIndex ? shot.alt : ""}
                      loading={i === shotIndex ? "eager" : "lazy"}
                      className={[
                        "h-full w-full object-cover object-center",
                        prefersReducedMotion
                          ? ""
                          : "transition-opacity duration-700 ease-out",
                        i === shotIndex ? "opacity-100" : "opacity-0",
                      ].join(" ")}
                    />
                  </button>
                ))}

                <button
                  type="button"
                  onClick={() =>
                    setShotIndex(
                      (shotIndex - 1 + SCREENSHOTS.length) % SCREENSHOTS.length
                    )
                  }
                  className="absolute left-3 top-1/2 -translate-y-1/2 rounded-xl border border-white/10 bg-brand-950/60 p-2.5 text-white backdrop-blur transition hover:bg-brand-950/80 focus:outline-none focus:ring-2 focus:ring-brand-accent/60"
                  aria-label="Previous screenshot"
                >
                  <ChevronLeft size={18} />
                </button>
                <button
                  type="button"
                  onClick={() =>
                    setShotIndex((shotIndex + 1) % SCREENSHOTS.length)
                  }
                  className="absolute right-3 top-1/2 -translate-y-1/2 rounded-xl border border-white/10 bg-brand-950/60 p-2.5 text-white backdrop-blur transition hover:bg-brand-950/80 focus:outline-none focus:ring-2 focus:ring-brand-accent/60"
                  aria-label="Next screenshot"
                >
                  <ChevronRight size={18} />
                </button>
              </div>

              <div className="flex flex-col gap-3 border-t border-white/5 p-4 sm:flex-row sm:items-center sm:justify-between">
                <p className="text-sm text-brand-300">
                  {SCREENSHOTS[shotIndex]?.alt}
                </p>
                <div className="flex items-center justify-between gap-3 sm:justify-end">
                  <div
                    className="flex items-center gap-2"
                    role="tablist"
                    aria-label="Screenshot selector"
                  >
                    {SCREENSHOTS.map((_, i) => (
                      <button
                        key={i}
                        type="button"
                        onClick={() => setShotIndex(i)}
                        className={[
                          "h-2.5 w-2.5 rounded-full transition",
                          i === shotIndex
                            ? "bg-brand-accent"
                            : "bg-white/15 hover:bg-white/25",
                        ].join(" ")}
                        aria-label={`Show screenshot ${i + 1}`}
                        aria-current={i === shotIndex ? "true" : undefined}
                      />
                    ))}
                  </div>
                  <button
                    type="button"
                    onClick={() => setLightboxOpen(true)}
                    className="text-xs font-semibold text-brand-accent-light underline decoration-brand-600 transition-colors hover:text-white hover:no-underline"
                  >
                    View full size →
                  </button>
                </div>
              </div>
              </div>
            </div>

            <p className="mt-3 text-center text-xs text-brand-500">
              Auto-advances every few seconds. Hover to pause.
            </p>
          </div>
        </div>
      </section>

      {lightboxOpen && (
        <div
          className="fixed inset-0 z-[200] flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm"
          role="dialog"
          aria-modal="true"
          aria-label="Screenshot viewer"
          onMouseDown={(e) => {
            if (e.target === e.currentTarget) setLightboxOpen(false);
          }}
        >
          <div className="relative w-full max-w-6xl overflow-hidden rounded-2xl border border-white/10 bg-brand-950 shadow-2xl">
            <div className="relative aspect-[16/10] w-full bg-black">
              <img
                src={SCREENSHOTS[shotIndex]?.src}
                alt={SCREENSHOTS[shotIndex]?.alt ?? "Screenshot"}
                className="h-full w-full object-contain"
              />

              <button
                type="button"
                onClick={() => setLightboxOpen(false)}
                className="absolute right-3 top-3 rounded-xl border border-white/10 bg-brand-950/60 px-3 py-2 text-sm font-semibold text-white backdrop-blur transition hover:bg-brand-950/80 focus:outline-none focus:ring-2 focus:ring-brand-accent/60"
                aria-label="Close"
              >
                Close
              </button>

              <button
                type="button"
                onClick={() =>
                  setShotIndex(
                    (shotIndex - 1 + SCREENSHOTS.length) % SCREENSHOTS.length
                  )
                }
                className="absolute left-3 top-1/2 -translate-y-1/2 rounded-xl border border-white/10 bg-brand-950/60 p-2.5 text-white backdrop-blur transition hover:bg-brand-950/80 focus:outline-none focus:ring-2 focus:ring-brand-accent/60"
                aria-label="Previous screenshot"
              >
                <ChevronLeft size={18} />
              </button>
              <button
                type="button"
                onClick={() =>
                  setShotIndex((shotIndex + 1) % SCREENSHOTS.length)
                }
                className="absolute right-3 top-1/2 -translate-y-1/2 rounded-xl border border-white/10 bg-brand-950/60 p-2.5 text-white backdrop-blur transition hover:bg-brand-950/80 focus:outline-none focus:ring-2 focus:ring-brand-accent/60"
                aria-label="Next screenshot"
              >
                <ChevronRight size={18} />
              </button>
            </div>

            <div className="flex flex-col gap-2 border-t border-white/10 p-4 sm:flex-row sm:items-center sm:justify-between">
              <p className="text-sm text-brand-300">{SCREENSHOTS[shotIndex]?.alt}</p>
              <p className="text-xs text-brand-500">ESC to close · ←/→ to navigate</p>
            </div>
          </div>
        </div>
      )}

      {/* Features */}
      <section className="border-t border-white/5 py-24">
        <div className="mx-auto max-w-6xl px-4 sm:px-6">
          <div className="text-center">
            <span className="section-badge">Features</span>
            <h2 className="section-heading mt-4 text-white">
              Everything you need to manage NAS sync
            </h2>
            <p className="mx-auto mt-4 max-w-2xl text-brand-400">
              Rsync-powered sync with symlink support, multi-NAS management,
              live monitoring, and smart scheduling — all from your menu bar.
            </p>
          </div>
          <div className="mt-16 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
            {FEATURES.map((feature) => (
              <div
                key={feature.title}
                className="group rounded-2xl border border-white/5 bg-white/[0.02] p-6 transition-all duration-300 hover:border-brand-accent/20 hover:bg-white/[0.04]"
              >
                <div className="mb-4 inline-flex rounded-xl bg-brand-accent/10 p-3 text-brand-accent-light transition-colors group-hover:bg-brand-accent/15">
                  <feature.icon size={22} />
                </div>
                <h3 className="font-display text-base font-semibold text-white">
                  {feature.title}
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-brand-400">
                  {feature.description}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Use Cases */}
      <section className="border-t border-white/5 py-24">
        <div className="mx-auto max-w-6xl px-4 sm:px-6">
          <div className="text-center">
            <span className="section-badge">Use Cases</span>
            <h2 className="section-heading mt-4 text-white">
              Built for real workflows
            </h2>
          </div>
          <div className="mt-16 grid gap-8 lg:grid-cols-3">
            {USE_CASES.map((useCase) => (
              <div
                key={useCase.title}
                className="rounded-2xl border border-white/5 bg-white/[0.02] p-8"
              >
                <h3 className="font-display text-lg font-semibold text-white">
                  {useCase.title}
                </h3>
                <p className="mt-3 text-sm leading-relaxed text-brand-400">
                  {useCase.description}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* How It Works */}
      <section className="border-t border-white/5 py-24">
        <div className="mx-auto max-w-4xl px-4 sm:px-6">
          <div className="text-center">
            <span className="section-badge">Getting Started</span>
            <h2 className="section-heading mt-4 text-white">
              Up and running in minutes
            </h2>
          </div>
          <div className="mt-16 space-y-8">
            {[
              {
                step: "1",
                title: "Launch The Annex",
                description:
                  "It appears in your menu bar. The welcome screen walks you through first-time setup.",
              },
              {
                step: "2",
                title: "Add your NAS",
                description:
                  'Click "Scan Network" to auto-discover your NAS via Bonjour, or enter the hostname manually. Add your credentials.',
              },
              {
                step: "3",
                title: "Add sync folders",
                description:
                  "Pick from presets (Documents, Desktop, Pictures, etc.) or define custom folder pairs.",
              },
              {
                step: "4",
                title: "Sync",
                description:
                  "Click Sync All, or let the automatic interval handle it. Enable symlink mode to free up local space.",
              },
            ].map((item) => (
              <div key={item.step} className="flex gap-6">
                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-accent/10 font-display text-sm font-bold text-brand-accent-light">
                  {item.step}
                </div>
                <div>
                  <h3 className="font-display text-base font-semibold text-white">
                    {item.title}
                  </h3>
                  <p className="mt-1 text-sm leading-relaxed text-brand-400">
                    {item.description}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Buy CTA */}
      <section id="buy" className="border-t border-white/5 py-24">
        <div className="mx-auto max-w-3xl px-4 text-center sm:px-6">
          <img
            src="/app-icon.png"
            alt=""
            className="mx-auto mb-8 h-20 w-20 rounded-2xl shadow-2xl shadow-brand-accent/20"
          />
          <h2 className="section-heading text-white">
            Support The Annex
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-brand-400">
            The Annex is open source. Download it for free, build it yourself,
            or chip in $5 to support development.
          </p>
          <div className="mt-10 flex flex-col items-center justify-center gap-4 sm:flex-row">
            <button
              onClick={handleBuy}
              disabled={buying}
              className="btn-primary px-10 py-4 text-base disabled:opacity-60"
            >
              {buying ? "Redirecting..." : "Support for $5"}
              {!buying && <ArrowRight size={18} />}
            </button>
            <a
              href={RELEASES_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="btn-secondary px-10 py-4 text-base"
            >
              <Github size={18} />
              Free download
            </a>
          </div>
          <div className="mt-8 flex flex-wrap items-center justify-center gap-x-8 gap-y-3 text-sm text-brand-500">
            <span>macOS 12+</span>
            <span>&middot;</span>
            <span>Apple Silicon & Intel</span>
            <span>&middot;</span>
            <span>Developer ID Signed</span>
            <span>&middot;</span>
            <span>Apple Notarized</span>
          </div>
          <p className="mt-4 text-xs text-brand-500">
            The checkout is optional support. The app and source remain public.
          </p>
        </div>
      </section>

      {/* Sponsor */}
      <section className="border-t border-white/5 py-12">
        <div className="mx-auto max-w-6xl px-4 text-center sm:px-6">
          <p className="text-xs text-brand-500">
            Proudly sponsored by{" "}
            <a
              href="https://www.texasbeardcompany.com"
              target="_blank"
              rel="noopener noreferrer"
              className="text-brand-400 underline decoration-brand-600 transition-colors hover:text-brand-300"
            >
              Texas Beard Company
            </a>
          </p>
        </div>
      </section>
    </>
  );
}
