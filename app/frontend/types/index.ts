export type FlashData = {
  notice?: string
  alert?: string
}

export type SharedProps = {}

export type Client = {
  id: number;
  name: string;
  billing_address?: string | null;
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
  formattedDuration: string;
  project: {
    id: number;
    name: string;
    color: string;
  } | null;
  tags: Tag[];
  files?: AttachedFile[];
};
