import type { MetaFunction } from "react-router";
import { Link } from "react-router";
import {
  Download,
  Terminal,
  MonitorSmartphone,
  FolderSync,
  Link2,
  Settings,
  HelpCircle,
  ExternalLink,
} from "lucide-react";

export const meta: MetaFunction = () => [
  { title: "Documentation — The Annex" },
  {
    name: "description",
    content:
      "Getting started guide, requirements, and troubleshooting for The Annex.",
  },
];

const GITHUB_URL = "https://github.com/ry4nolson/TheAnnex";

function SideNav() {
  const sections = [
    { id: "installation", label: "Installation" },
    { id: "requirements", label: "Requirements" },
    { id: "getting-started", label: "Getting Started" },
    { id: "features", label: "Features" },
    { id: "menu-bar", label: "Menu Bar" },
    { id: "troubleshooting", label: "Troubleshooting" },
  ];

  return (
    <nav className="hidden lg:block" aria-label="Documentation navigation">
      <div className="sticky top-24 space-y-1">
        <p className="mb-3 text-xs font-semibold uppercase tracking-widest text-brand-500">
          On this page
        </p>
        {sections.map((section) => (
          <a
            key={section.id}
            href={`#${section.id}`}
            className="block rounded-lg px-3 py-1.5 text-sm text-brand-400 transition-colors hover:bg-white/5 hover:text-white"
          >
            {section.label}
          </a>
        ))}
      </div>
    </nav>
  );
}

function Section({
  id,
  icon: Icon,
  title,
  children,
}: {
  id: string;
  icon: typeof Download;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section id={id} className="scroll-mt-24">
      <div className="flex items-center gap-3">
        <div className="inline-flex rounded-xl bg-brand-accent/10 p-2.5 text-brand-accent-light">
          <Icon size={20} />
        </div>
        <h2 className="font-display text-2xl font-bold text-white">{title}</h2>
      </div>
      <div className="mt-6 space-y-4 text-sm leading-relaxed text-brand-300">
        {children}
      </div>
    </section>
  );
}

function Code({ children }: { children: string }) {
  return (
    <pre className="overflow-x-auto rounded-xl border border-white/5 bg-brand-900 p-4">
      <code className="text-sm text-brand-300">{children}</code>
    </pre>
  );
}

export default function Docs() {
  return (
    <>
      <section className="border-b border-white/5 py-16">
        <div className="mx-auto max-w-5xl px-4 text-center sm:px-6">
          <span className="section-badge">Documentation</span>
          <h1 className="section-heading mt-4 text-white">
            Getting Started
          </h1>
          <p className="mt-4 text-brand-400">
            Everything you need to install, configure, and use The Annex.
          </p>
        </div>
      </section>

      <section className="py-16">
        <div className="mx-auto grid max-w-5xl gap-16 px-4 sm:px-6 lg:grid-cols-[1fr_200px]">
          <div className="space-y-16">
            <Section id="installation" icon={Download} title="Installation">
              <h3 className="text-base font-semibold text-white">Download</h3>
              <p>
                Grab the latest <code className="rounded bg-white/5 px-1.5 py-0.5 text-brand-accent-light">TheAnnex.dmg</code> or{" "}
                <code className="rounded bg-white/5 px-1.5 py-0.5 text-brand-accent-light">TheAnnex.zip</code> from{" "}
                <a
                  href={`${GITHUB_URL}/releases/latest`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1 text-brand-accent-light hover:underline"
                >
                  GitHub Releases
                  <ExternalLink size={12} />
                </a>
                , open the DMG, and drag The Annex to your Applications folder.
              </p>

              <h3 className="text-base font-semibold text-white">
                Build from Source
              </h3>
              <Code>{`git clone https://github.com/ry4nolson/TheAnnex.git
cd TheAnnex
./build.sh`}</Code>
              <p>
                The app will be compiled, signed (ad-hoc), installed to{" "}
                <code className="rounded bg-white/5 px-1.5 py-0.5 text-brand-accent-light">~/Applications/TheAnnex.app</code>, and
                launched automatically.
              </p>
            </Section>

            <Section
              id="requirements"
              icon={MonitorSmartphone}
              title="Requirements"
            >
              <ul className="list-inside list-disc space-y-2">
                <li>macOS 12.0 (Monterey) or later</li>
                <li>Xcode Command Line Tools (build from source only)</li>
                <li>Access to a NAS with SMB shares</li>
              </ul>
            </Section>

            <Section
              id="getting-started"
              icon={FolderSync}
              title="Getting Started"
            >
              <ol className="list-inside list-decimal space-y-3">
                <li>
                  <strong className="text-white">Launch The Annex</strong> — it
                  appears in your menu bar. The welcome screen walks you through
                  first-time setup.
                </li>
                <li>
                  In <strong className="text-white">General</strong>, click{" "}
                  <strong className="text-white">Add NAS</strong> →{" "}
                  <strong className="text-white">Scan Network</strong> to
                  auto-discover your NAS via Bonjour.
                </li>
                <li>
                  Enter credentials and shares, click{" "}
                  <strong className="text-white">Add</strong>.
                </li>
                <li>
                  Go to <strong className="text-white">Sync Folders</strong> →{" "}
                  <strong className="text-white">Add Folder</strong> → pick a
                  preset or custom folder.
                </li>
                <li>
                  Click <strong className="text-white">Sync All</strong> or let
                  the automatic check interval handle it.
                </li>
              </ol>
            </Section>

            <Section id="features" icon={Settings} title="Features">
              <h3 className="text-base font-semibold text-white">
                Sync Engine
              </h3>
              <ul className="list-inside list-disc space-y-1">
                <li>Queue-based sync with up to 2 concurrent transfers</li>
                <li>One-way sync: Local → NAS (rsync with --update)</li>
                <li>Per-folder or sync-all, cancel individual or all</li>
                <li>Progress tracking and bandwidth throttling</li>
              </ul>

              <h3 className="text-base font-semibold text-white">
                Symlink Mode
              </h3>
              <ul className="list-inside list-disc space-y-1">
                <li>
                  Replace local folders with symlinks to the NAS after syncing
                </li>
                <li>
                  NAS goes offline → symlink removed, local copy restored
                  automatically
                </li>
                <li>
                  NAS comes back → local changes synced, symlink re-created
                </li>
                <li>
                  macOS-protected folders (Desktop, Documents, Pictures) run in
                  sync-only mode automatically
                </li>
              </ul>

              <h3 className="text-base font-semibold text-white">
                Monitoring
              </h3>
              <ul className="list-inside list-disc space-y-1">
                <li>Live connection quality (latency, packet loss) per NAS</li>
                <li>Disk space monitoring with progress bars</li>
                <li>Auto-mount SMB shares when NAS comes online</li>
                <li>Configurable check intervals (30s to 30min)</li>
              </ul>

              <h3 className="text-base font-semibold text-white">
                Interface Tabs
              </h3>
              <ul className="list-inside list-disc space-y-1">
                <li>
                  <strong className="text-white">General</strong> — NAS devices,
                  discovery, monitoring dashboard
                </li>
                <li>
                  <strong className="text-white">Sync Folders</strong> — sync
                  pair list with status, clickable paths
                </li>
                <li>
                  <strong className="text-white">Activity Log</strong> —
                  searchable, filterable log with export
                </li>
                <li>
                  <strong className="text-white">Statistics</strong> — transfer
                  metrics, charts (macOS 13+)
                </li>
                <li>
                  <strong className="text-white">Advanced</strong> — bandwidth,
                  WiFi filtering, power, rsync flags
                </li>
                <li>
                  <strong className="text-white">About</strong> — version,
                  update check, changelog
                </li>
              </ul>
            </Section>

            <Section id="menu-bar" icon={Link2} title="Menu Bar">
              <ul className="list-inside list-disc space-y-1">
                <li>Dynamic status icon (connected / offline / syncing)</li>
                <li>Quick access to sync folders and shares</li>
                <li>Active sync progress with per-job cancel</li>
                <li>Recent activity feed</li>
              </ul>
            </Section>

            <Section
              id="troubleshooting"
              icon={HelpCircle}
              title="Troubleshooting"
            >
              <h3 className="text-base font-semibold text-white">
                NAS Won't Connect
              </h3>
              <ol className="list-inside list-decimal space-y-1">
                <li>
                  Verify hostname:{" "}
                  <code className="rounded bg-white/5 px-1.5 py-0.5 text-brand-accent-light">ping YourNAS.local</code>
                </li>
                <li>Check credentials</li>
                <li>Ensure SMB is enabled on the NAS</li>
              </ol>

              <h3 className="text-base font-semibold text-white">
                Sync Fails
              </h3>
              <ol className="list-inside list-decimal space-y-1">
                <li>
                  Check the <strong className="text-white">Activity Log</strong>{" "}
                  for errors
                </li>
                <li>Verify NAS paths exist and are writable</li>
                <li>Ensure sufficient disk space</li>
              </ol>

              <h3 className="text-base font-semibold text-white">
                Shares Won't Mount
              </h3>
              <ol className="list-inside list-decimal space-y-1">
                <li>
                  Try mounting manually in Finder:{" "}
                  <code className="rounded bg-white/5 px-1.5 py-0.5 text-brand-accent-light">smb://YourNAS.local/share</code>
                </li>
                <li>Check firewall settings</li>
                <li>Review Activity Log for mount errors</li>
              </ol>

              <h3 className="text-base font-semibold text-white">
                NAS Not Found in Scan
              </h3>
              <ol className="list-inside list-decimal space-y-1">
                <li>Ensure your NAS advertises SMB via Bonjour/mDNS</li>
                <li>
                  Check that both devices are on the same network/subnet
                </li>
                <li>Try entering the hostname manually</li>
              </ol>
            </Section>
          </div>

          <SideNav />
        </div>
      </section>
    </>
  );
}
