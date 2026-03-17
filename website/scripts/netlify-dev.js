#!/usr/bin/env node
/**
 * Run Netlify Dev with a workaround for the react-router-server function.
 * The plugin-generated server function fails to resolve @react-router/node in the
 * functions-serve sandbox. In dev we serve the app entirely from the Vite dev server
 * (proxied at 8888), so we remove the generated function before starting so Netlify
 * doesn't try to load it.
 */

import { existsSync, rmSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { execSync } from "node:child_process";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const serverBuild = join(root, "build/server/server.js");
const netlifyServerFn = join(root, ".netlify/v1/functions/react-router-server.mjs");

if (!existsSync(serverBuild)) {
  console.log("Building (build/server not found)...");
  execSync("react-router build", { stdio: "inherit", cwd: root });
}

if (existsSync(netlifyServerFn)) {
  rmSync(netlifyServerFn, { force: true });
}

execSync("netlify dev", { stdio: "inherit", cwd: root });
