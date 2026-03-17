import {
  Links,
  Meta,
  Outlet,
  Scripts,
  ScrollRestoration,
} from "react-router";
import type { LinksFunction, MetaFunction } from "react-router";
import "./index.css";

const GOOGLE_FONTS_URL =
  "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Space+Grotesk:wght@500;600;700&display=swap";

export const meta: MetaFunction = () => [
  { title: "The Annex — Sync Your Mac to Your NAS" },
  {
    name: "description",
    content:
      "A macOS menu bar app that syncs your folders to your NAS — and optionally symlinks them so your files live on the NAS while still feeling local.",
  },
];

export const links: LinksFunction = () => [
  { rel: "icon", type: "image/png", href: "/app-icon.png" },
  { rel: "apple-touch-icon", href: "/app-icon.png" },
  { rel: "preconnect", href: "https://fonts.googleapis.com" },
  {
    rel: "preconnect",
    href: "https://fonts.gstatic.com",
    crossOrigin: "anonymous",
  },
  { rel: "stylesheet", href: GOOGLE_FONTS_URL },
];

export function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="h-full">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta property="og:site_name" content="The Annex" />
        <meta
          property="og:title"
          content="The Annex — Sync Your Mac to Your NAS"
        />
        <meta
          property="og:description"
          content="A macOS menu bar app that syncs your folders to your NAS — and optionally symlinks them so your files live on the NAS while still feeling local."
        />
        <meta property="og:type" content="website" />
        <meta property="og:image" content="/og-image.png" />
        <meta property="og:image:width" content="512" />
        <meta property="og:image:height" content="512" />
        <meta name="twitter:card" content="summary" />
        <meta
          name="twitter:title"
          content="The Annex — Sync Your Mac to Your NAS"
        />
        <meta
          name="twitter:description"
          content="A macOS menu bar app that syncs your folders to your NAS — and optionally symlinks them so your files live on the NAS while still feeling local."
        />
        <meta name="twitter:image" content="/og-image.png" />
        <meta name="theme-color" content="#0a0e17" />
        <Meta />
        <Links />
      </head>
      <body className="flex min-h-full flex-col">
        {children}
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}

export default function Root() {
  return <Outlet />;
}
