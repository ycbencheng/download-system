<script lang="ts">
  interface Props {
    status: "active" | "expired" | "limit_reached" | "revoked";
  }
  let { status }: Props = $props();

  const labels: Record<string, string> = {
    active: "Active",
    expired: "Expired",
    limit_reached: "Limit",
    revoked: "Revoked",
  };
</script>

<span class="badge {status}">{labels[status] ?? status}</span>

<style>
  .badge {
    display: inline-block;
    padding: 0.15rem 0.5rem;
    border-radius: 9999px;
    font-size: 0.72rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }

  .active {
    background: #d1fae5;
    color: #065f46;
  }

  .expired {
    background: #fef3c7;
    color: #92400e;
  }

  .limit_reached {
    background: #fee2e2;
    color: #991b1b;
  }

  .revoked {
    background: #e5e7eb;
    color: #374151;
  }
</style>
