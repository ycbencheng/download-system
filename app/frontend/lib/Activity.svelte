<script lang="ts">
  import { onMount } from "svelte";
  import { fetchDownloadEvents, type DownloadEvent } from "./api";
  import StatusBadge from "./StatusBadge.svelte";

  let events: DownloadEvent[] = $state([]);
  let loading = $state(true);
  let error: string | null = $state(null);

  onMount(async () => {
    try {
      events = await fetchDownloadEvents();
    } catch (e) {
      error = e instanceof Error ? e.message : "Failed to load activity";
    } finally {
      loading = false;
    }
  });

  function truncateUA(ua: string | null): string {
    if (!ua) return "—";
    return ua.length > 60 ? ua.slice(0, 57) + "…" : ua;
  }
</script>

{#if loading}
  <p class="loading">Loading activity…</p>
{:else if error}
  <p class="error">{error}</p>
{:else if events.length === 0}
  <p class="empty">No download activity yet.</p>
{:else}
  <table>
    <thead>
      <tr>
        <th>Time</th>
        <th>Product</th>
        <th>Buyer</th>
        <th>Outcome</th>
        <th>IP</th>
        <th>User Agent</th>
      </tr>
    </thead>
    <tbody>
      {#each events as ev (ev.id)}
        <tr>
          <td class="date">{new Date(ev.created_at).toLocaleString()}</td>
          <td class="primary">{ev.product_name}</td>
          <td>{ev.buyer_email}</td>
          <td><StatusBadge status={ev.outcome} /></td>
          <td><code>{ev.ip ?? "—"}</code></td>
          <td class="ua" title={ev.user_agent ?? ""}>{truncateUA(ev.user_agent)}</td>
        </tr>
      {/each}
    </tbody>
  </table>
{/if}

<style>
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.88rem;
  }

  th {
    text-align: left;
    padding: 0.5rem 0.75rem;
    font-weight: 600;
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: #6b7280;
    border-bottom: 1px solid #e5e7eb;
  }

  td {
    padding: 0.6rem 0.75rem;
    border-bottom: 1px solid #f3f4f6;
  }

  tr:last-child td {
    border-bottom: none;
  }

  .primary {
    font-weight: 500;
  }

  .date {
    color: #6b7280;
    font-size: 0.82rem;
    white-space: nowrap;
  }

  .ua {
    font-size: 0.78rem;
    color: #6b7280;
    max-width: 200px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  code {
    font-size: 0.82rem;
    background: #f3f4f6;
    padding: 0.15rem 0.4rem;
    border-radius: 3px;
  }

  .loading, .empty {
    color: #6b7280;
    font-size: 0.9rem;
  }

  .error {
    color: #dc2626;
    font-size: 0.9rem;
  }
</style>
