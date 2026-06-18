<script lang="ts">
  import Products from "./Products.svelte";
  import Orders from "./Orders.svelte";
  import Activity from "./Activity.svelte";

  type Tab = "products" | "orders" | "activity";
  let activeTab: Tab = $state("orders");

  function setTab(tab: Tab) {
    activeTab = tab;
  }
</script>

<div class="dashboard">
  <header class="dashboard-header">
    <h1>Download System</h1>
    <p class="subtitle">Read-only dashboard</p>
  </header>

  <nav class="tabs">
    <button
      class="tab"
      class:active={activeTab === "products"}
      onclick={() => setTab("products")}
    >Products</button>
    <button
      class="tab"
      class:active={activeTab === "orders"}
      onclick={() => setTab("orders")}
    >Recent Orders</button>
    <button
      class="tab"
      class:active={activeTab === "activity"}
      onclick={() => setTab("activity")}
    >Download Activity</button>
  </nav>

  <main class="panel">
    {#if activeTab === "products"}
      <Products />
    {:else if activeTab === "orders"}
      <Orders />
    {:else}
      <Activity />
    {/if}
  </main>
</div>

<style>
  :global(body) {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
      Helvetica, Arial, sans-serif;
    background: #f5f7fa;
    color: #1a1a2e;
  }

  .dashboard {
    max-width: 960px;
    margin: 0 auto;
    padding: 2rem 1.5rem;
  }

  .dashboard-header {
    margin-bottom: 1.5rem;
  }

  .dashboard-header h1 {
    margin: 0;
    font-size: 1.6rem;
    font-weight: 700;
    color: #1a1a2e;
  }

  .subtitle {
    margin: 0.25rem 0 0;
    font-size: 0.85rem;
    color: #6b7280;
  }

  .tabs {
    display: flex;
    gap: 0;
    border-bottom: 2px solid #e5e7eb;
    margin-bottom: 1.5rem;
  }

  .tab {
    padding: 0.6rem 1.2rem;
    border: none;
    background: none;
    font-size: 0.9rem;
    font-weight: 500;
    color: #6b7280;
    cursor: pointer;
    border-bottom: 2px solid transparent;
    margin-bottom: -2px;
    transition: color 0.15s, border-color 0.15s;
  }

  .tab:hover {
    color: #374151;
  }

  .tab.active {
    color: #2563eb;
    border-bottom-color: #2563eb;
  }

  .panel {
    background: #fff;
    border-radius: 8px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
    padding: 1.5rem;
  }
</style>
