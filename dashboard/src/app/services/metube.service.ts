import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, timer } from 'rxjs';
import { switchMap, shareReplay } from 'rxjs/operators';

export interface AddDownloadRequest {
  url: string;
  quality?: string;
  format?: string;
  folder?: string;
  download_type?: string;
}

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
  timestamp?: number;
}

export interface HistoryResponse {
  done: DownloadInfo[];
  queue: DownloadInfo[];
  pending: DownloadInfo[];
}

@Injectable({ providedIn: 'root' })
export class MetubeService {
  private readonly base = '/api';

  constructor(private http: HttpClient) {}

  addDownload(req: AddDownloadRequest): Observable<{ status: string; msg?: string }> {
    return this.http.post<{ status: string; msg?: string }>(`${this.base}/add`, req);
  }

  startDownloads(ids: string[]): Observable<{ status: string }> {
    return this.http.post<{ status: string }>(`${this.base}/start`, { ids });
  }

  getHistory(): Observable<HistoryResponse> {
    return this.http.get<HistoryResponse>(`${this.base}/history`);
  }

  getHistoryPolling(intervalMs = 1000): Observable<HistoryResponse> {
    return timer(0, intervalMs).pipe(
      switchMap(() => this.getHistory()),
      shareReplay(1)
    );
  }

  deleteDownloads(ids: string[], where: 'queue' | 'done'): Observable<{ status: string }> {
    return this.http.post<{ status: string }>(`${this.base}/delete`, { ids, where });
  }

  getCookieStatus(): Observable<{ status: string; has_cookies: boolean }> {
    return this.http.get<{ status: string; has_cookies: boolean }>(`${this.base}/cookie-status`);
  }

  getVersion(): Observable<{ version: string; yt_dlp_version: string }> {
    return this.http.get<{ version: string; yt_dlp_version: string }>(`${this.base}/version`);
  }

  /**
   * Poll history until we find an item matching the given URL
   * in queue, pending, or done. Returns the item or null after max attempts.
   */
  pollForItem(url: string, maxAttempts = 20, intervalMs = 500): Observable<DownloadInfo | null> {
    return timer(0, intervalMs).pipe(
      switchMap(() => this.getHistory()),
      switchMap((data) => {
        const all = [...(data.pending || []), ...(data.queue || []), ...(data.done || [])];
        const match = all.find((item) => item.url === url);
        return [match || null];
      }),
      // Stop after maxAttempts
      // Note: caller should use take(maxAttempts) or similar
    );
  }
}
