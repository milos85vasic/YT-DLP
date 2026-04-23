export interface DownloadInfo {
  id: string;
  title: string;
  url: string;
  quality: string;
  format: string;
  folder: string;
  status: string;
  msg?: string;
  error?: string;
  percent?: number;
  speed?: string;
  eta?: string;
  size?: number | string;
  filename?: string;
}

export interface HistoryResponse {
  done: DownloadInfo[];
  queue: DownloadInfo[];
  pending: DownloadInfo[];
}
