export type FlashData = {
  notice?: string;
  alert?: string;
};

export type SharedProps = {};

export type Client = {
  id: number;
  name: string;
  billing_address?: string | null;
  email?: string | null;
};

export type Tag = {
  id: number;
  name: string;
};

export type Project = {
  id: number;
  name: string;
  color: string;
  billable_default: boolean;
  client?: {
    id: number;
    name: string;
  };
};

export type AttachedFile = {
  id: number;
  blob_id: number;
  filename: string;
  byte_size: number;
  content_type: string;
};

export type TimeEntry = {
  id: number;
  description: string | null;
  start_at: string;
  end_at: string | null;
  duration_seconds?: number;
  billable: boolean;
  project: {
    id: number;
    name: string;
    color: string;
  } | null;
  tags: Tag[];
  files?: AttachedFile[];
};

export type RunningEntry = {
  id: number;
  description: string | null;
  start_at: string;
  billable: boolean;
  project: {
    id: number;
    name: string;
    color: string;
  } | null;
  tags: Tag[];
};

export type RecentDescription = {
  description: string;
  project_id: number | null;
  tag_ids: number[];
  billable: boolean;
};

export type InvoiceStatus = "draft" | "issued" | "paid";

type InvoiceBase = {
  id: number;
  hashid: string;
  invoice_number: number;
  status: InvoiceStatus;
  total_cents: number;
  period_start: string;
  period_end: string;
  issued_on: string | null;
  total_amount: string;
};

export type InvoiceListItem = InvoiceBase & {
  line_count: number;
  client: { id: number; name: string };
};

export type InvoiceLine = {
  id: number;
  description: string;
  qty_hours: string;
  rate_cents: number | null;
  amount_cents: number;
  amount: string;
  rate: string | null;
};

export type Invoice = InvoiceBase & {
  notes: string | null;
  client: Client;
  lines: InvoiceLine[];
};

export type InvoiceSettings = {
  billable_rate_cents: number;
  sender_name: string;
  sender_address: string | null;
};

export type InvoiceSender = {
  name: string;
  address: string | null;
};

export type UnbilledEntry = {
  id: number;
  description: string;
  duration_seconds: number;
  billable: boolean;
  start_at: string;
  hours: number;
  project: {
    id: number;
    name: string;
    color: string;
    client_id: number | null;
    client: { id: number; name: string } | null;
  } | null;
  tags: Tag[];
};
