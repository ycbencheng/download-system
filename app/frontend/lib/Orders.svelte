<script lang="ts">
  import { onMount } from "svelte";
  import { fetchOrders, type Order } from "./api";
  import StatusBadge from "./StatusBadge.svelte";

  let orders: Order[] = $state([]);
  let loading = $state(true);
  let error: string | null = $state(null);

  onMount(async () => {
    try {
      orders = await fetchOrders();
    } catch (e) {
      error = e instanceof Error ? e.message : "Failed to load orders";
    } finally {
      loading = false;
    }
  });
</script>

{#if loading}
  <p class="loading">Loading orders…</p>
{:else if error}
  <p class="error">{error}</p>
{:else if orders.length === 0}
  <p class="empty">No orders yet.</p>
{:else}
  <table>
    <thead>
      <tr>
        <th>Order</th>
        <th>Buyer</th>
        <th>Product</th>
        <th>Downloads</th>
        <th>Status</th>
        <th>Ordered</th>
      </tr>
    </thead>
    <tbody>
      {#each orders as o (o.id)}
        <tr>
          <td class="num">#{o.id}</td>
          <td>{o.buyer_email}</td>
          <td class="primary">{o.product_name}</td>
          <td class="num">
            {#if o.download_link}
              {o.download_link.download_count}/{o.download_link.max_downloads}
            {:else}
              —
            {/if}
          </td>
          <td>
            {#if o.download_link}
              <StatusBadge status={o.download_link.status} />
            {:else}
              <span class="badge unknown">no link</span>
            {/if}
          </td>
          <td class="date">{new Date(o.created_at).toLocaleString()}</td>
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

  .num {
    font-variant-numeric: tabular-nums;
  }

  .date {
    color: #6b7280;
    font-size: 0.82rem;
  }

  .badge {
    display: inline-block;
    padding: 0.15rem 0.5rem;
    border-radius: 9999px;
    font-size: 0.72rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }

  .unknown {
    background: #f3f4f6;
    color: #6b7280;
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
