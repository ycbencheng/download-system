const BASE = "/api/v1";

export interface Product {
  id: number;
  name: string;
  file_name: string;
  expiry_hours: number;
  max_downloads: number;
  created_at: string;
}

export interface DownloadLinkSummary {
  id: number;
  expires_at: string;
  max_downloads: number;
  download_count: number;
  revoked: boolean;
  status: "active" | "expired" | "limit_reached" | "revoked";
}

export interface Order {
  id: number;
  buyer_email: string;
  product_name: string;
  created_at: string;
  download_link: DownloadLinkSummary | null;
}

export type DownloadOutcome = "success" | "expired" | "limit_reached" | "revoked";

export interface DownloadEvent {
  id: number;
  ip: string | null;
  user_agent: string | null;
  outcome: DownloadOutcome;
  created_at: string;
  download_link_id: number;
  buyer_email: string;
  product_name: string;
}

async function fetchJSON<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    headers: { Accept: "application/json" },
  });
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  return res.json() as Promise<T>;
}

export function fetchProducts(): Promise<Product[]> {
  return fetchJSON<Product[]>("/products");
}

export function fetchOrders(): Promise<Order[]> {
  return fetchJSON<Order[]>("/orders");
}

export function fetchDownloadEvents(): Promise<DownloadEvent[]> {
  return fetchJSON<DownloadEvent[]>("/download_events");
}
