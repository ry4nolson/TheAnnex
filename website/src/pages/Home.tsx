import {
  ArrowRight,
  FolderSync,
  Link2,
  MonitorSmartphone,
  Gauge,
  HardDrive,
  Shield,
  Wifi,
  BatteryCharging,
  Terminal,
  Github,
} from "lucide-react";
import { useState } from "react";
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
      "GPL-3.0 licensed. Build from source for free, or buy the built and signed app to support development.",
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
                {buying ? "Redirecting..." : "Buy for $5"}
                {!buying && <ArrowRight size={18} />}
              </button>
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
            <p className="mt-4 text-sm text-brand-500">
              macOS 12+ &middot; Apple Silicon & Intel &middot; Open source
              (GPL-3.0)
            </p>
          </div>
        </div>
      </section>

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
            Get The Annex for $5
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-brand-400">
            Signed, notarized, and ready to run. One-time purchase — no
            subscriptions. Or build from source for free.
          </p>
          <div className="mt-10 flex flex-col items-center justify-center gap-4 sm:flex-row">
            <button
              onClick={handleBuy}
              disabled={buying}
              className="btn-primary px-10 py-4 text-base disabled:opacity-60"
            >
              {buying ? "Redirecting..." : "Buy for $5"}
              {!buying && <ArrowRight size={18} />}
            </button>
            <a
              href={GITHUB_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="btn-secondary px-10 py-4 text-base"
            >
              <Github size={18} />
              Build from Source
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
