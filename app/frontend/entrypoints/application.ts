// Vite + Svelte entrypoint. The read-only dashboard (timeboxed, built last) is
// the only page that ships JS; it mounts into a `#dashboard` element. Every
// other page (the server-rendered download landing/error pages) has no such
// target, so this stays a deliberate no-op there.
import { mount } from "svelte";
import App from "../lib/App.svelte";

const target = document.getElementById("dashboard");
if (target) {
  // Clear the server-rendered "frontend not built" fallback before mounting so
  // it only ever shows when this bundle did not run (see dashboard/index.html.erb).
  target.innerHTML = "";
  mount(App, { target });
}
