<script lang="ts">
  import { onMount } from "svelte";
  import { fetchProducts, type Product } from "./api";

  let products: Product[] = $state([]);
  let loading = $state(true);
  let error: string | null = $state(null);

  onMount(async () => {
    try {
      products = await fetchProducts();
    } catch (e) {
      error = e instanceof Error ? e.message : "Failed to load products";
    } finally {
      loading = false;
    }
  });
</script>

{#if loading}
  <p class="loading">Loading products…</p>
{:else if error}
  <p class="error">{error}</p>
{:else if products.length === 0}
  <p class="empty">No products yet.</p>
{:else}
  <table>
    <thead>
      <tr>
        <th>Name</th>
        <th>File</th>
        <th>Expiry (hours)</th>
        <th>Max downloads</th>
        <th>Created</th>
      </tr>
    </thead>
    <tbody>
      {#each products as p (p.id)}
        <tr>
          <td class="primary">{p.name}</td>
          <td><code>{p.file_name}</code></td>
          <td class="num">{p.expiry_hours}</td>
          <td class="num">{p.max_downloads}</td>
          <td class="date">{new Date(p.created_at).toLocaleDateString()}</td>
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
    text-align: right;
    font-variant-numeric: tabular-nums;
  }

  .date {
    color: #6b7280;
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
