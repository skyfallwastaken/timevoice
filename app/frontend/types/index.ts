export type FlashData = {
  notice?: string
  alert?: string
}

export type SharedProps = {}

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
  formattedDuration: string;
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
