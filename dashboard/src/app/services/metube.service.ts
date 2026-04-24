import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, timer, of } from 'rxjs';
import { switchMap, shareReplay, take, map } from 'rxjs/operators';

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
  download_type?: string;
  codec?: string;
  custom_name_prefix?: string;
  playlist_item_limit?: number;
  split_by_chapters?: boolean;
  chapter_template?: string;
  subtitle_language?: string;
  subtitle_mode?: string;
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

  /** Clear all history entries (does NOT delete files). */
  clearHistory(): Observable<{ status: string }> {
    return new Observable((observer) => {
      this.getHistory().subscribe({
        next: (data) => {
          const ids = (data.done || []).map((item) => item.id);
          if (ids.length === 0) {
            observer.next({ status: 'ok' });
            observer.complete();
            return;
          }
          this.deleteDownloads(ids, 'done').subscribe({
            next: (res) => {
              observer.next(res);
              observer.complete();
            },
            error: (err) => observer.error(err),
          });
        },
        error: (err) => observer.error(err),
      });
    });
  }

  /** Retry a failed/completed download by removing from history and re-adding. */
  retryDownload(item: DownloadInfo): Observable<{ status: string; msg?: string }> {
    return new Observable((observer) => {
      // 1. Remove from history
      this.deleteDownloads([item.id], 'done').subscribe({
        next: () => {
          // 2. Re-add with same settings
          const req: AddDownloadRequest = {
            url: item.url,
            quality: item.quality || 'best',
            format: item.format || 'any',
            folder: item.folder || '',
            download_type: item.download_type || 'video',
          };
          this.addDownload(req).subscribe({
            next: (res) => {
              observer.next(res);
              observer.complete();
            },
            error: (err) => observer.error(err),
          });
        },
        error: (err) => observer.error(err),
      });
    });
  }

  /** Delete download from history AND optionally delete files from disk. */
  deleteDownloadWithFile(
    item: DownloadInfo,
    deleteFile: boolean
  ): Observable<{ success: boolean; files_deleted?: string[]; error?: string }> {
    return this.http.post<{ success: boolean; files_deleted?: string[]; error?: string }>(
      `${this.base}/delete-download`,
      {
        id: item.id,
        title: item.title,
        folder: item.folder || '',
        delete_file: deleteFile,
      }
    );
  }

  getCookieStatus(): Observable<{ status: string; has_cookies: boolean }> {
    return this.http.get<{ status: string; has_cookies: boolean }>(`${this.base}/cookie-status`);
  }

  getVersion(): Observable<{ version: string; 'yt-dlp': string }> {
    return this.http.get<{ version: string; 'yt-dlp': string }>(`${this.base}/version`);
  }

  /**
   * Poll history until we find an item matching the given URL
   * in queue, pending, or done. Returns the item or null after max attempts.
   */
  pollForItem(url: string, maxAttempts = 20, intervalMs = 500): Observable<DownloadInfo | null> {
    return timer(0, intervalMs).pipe(
      take(maxAttempts),
      switchMap(() => this.getHistory()),
      map((data) => {
        const all = [...(data.pending || []), ...(data.queue || []), ...(data.done || [])];
        return all.find((item) => item.url === url) || null;
      })
    );
  }
}
