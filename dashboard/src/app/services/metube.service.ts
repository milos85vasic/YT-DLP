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
  error?: string | null;
  percent?: number | null;
  speed?: string | null;
  eta?: string | null;
  size?: number | string | null;
  filename?: string | null;
  timestamp?: number;
  download_type?: string;
  codec?: string;
  custom_name_prefix?: string;
  playlist_item_limit?: number;
  split_by_chapters?: boolean;
  chapter_template?: string;
  subtitle_language?: string;
  subtitle_mode?: string;
  chapter_files?: string[];
  subtitle_files?: string[];
  ytdl_options_presets?: string[];
  ytdl_options_overrides?: Record<string, unknown>;
  entry?: unknown | null;
}

export interface HistoryResponse {
  done: DownloadInfo[];
  queue: DownloadInfo[];
  pending: DownloadInfo[];
}

export interface PlatformCookieBucket {
  domains_present: string[];
  session_count: number;
  max_expiry_unix: number;
  min_expiry_unix: number;
}

export interface CookieStatusResponse {
  status?: string;
  has_cookies: boolean;
  metube_reachable?: boolean;
  cookie_age_minutes?: number;
  platforms?: { [platform: string]: PlatformCookieBucket };
}

export interface ProfileStatusResponse {
  profile: 'no-vpn' | 'vpn' | 'unknown' | string;
  vpn_active: boolean;
  metube_url?: string;
  metube_reachable?: boolean;
}

export interface BulkDeleteResult {
  total_requested: number;
  succeeded: number;
  files_deleted: string[];
  errors: { url: string; error: string }[];
}

export interface AbortedHistoryEntry {
  url: string;
  title?: string;
  folder?: string;
  reason?: string;
  percent?: number | null;
  speed?: string;
  eta?: string;
  size?: number | string | null;
  aborted_at?: number;
  status: 'aborted';
}

export interface AbortedHistoryResponse {
  aborted: AbortedHistoryEntry[];
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

  deleteDownloads(urls: string[], where: 'queue' | 'done'): Observable<{ status: string }> {
    return this.http.post<{ status: string }>(`${this.base}/delete`, { ids: urls, where });
  }

  /** Clear all history entries (does NOT delete files). */
  clearHistory(): Observable<{ status: string }> {
    return new Observable((observer) => {
      this.getHistory().subscribe({
        next: (data) => {
          const urls = (data.done || []).map((item) => item.url);
          if (urls.length === 0) {
            observer.next({ status: 'ok' });
            observer.complete();
            return;
          }
          this.deleteDownloads(urls, 'done').subscribe({
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
      // 1. Remove from history (MeTube /delete expects URLs as keys)
      this.deleteDownloads([item.url], 'done').subscribe({
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
        url: item.url,
        title: item.title,
        folder: item.folder || '',
        delete_file: deleteFile,
      }
    );
  }

  /**
   * Bulk-clear records by URL — removes from queue OR done list,
   * NEVER touches files. Equivalent to repeated cleanup() calls but
   * issued as one /delete request.
   */
  clearSelected(urls: string[], where: 'queue' | 'done'): Observable<{ status: string }> {
    if (urls.length === 0) {
      // Avoid an empty POST that the backend may treat as a clear-all.
      return new Observable((observer) => {
        observer.next({ status: 'ok' });
        observer.complete();
      });
    }
    return this.deleteDownloads(urls, where);
  }

  /**
   * Bulk-delete history records AND files from disk. Iterates
   * /api/delete-download for each URL because the landing endpoint
   * resolves filenames per-item; aggregates results into a single
   * summary the caller can show in a toast.
   *
   * Returns:
   *   total_requested  — count of URLs we attempted
   *   succeeded        — count where success=true
   *   files_deleted    — flat list of all files removed across all items
   *   errors           — list of {url, error} for failed items
   */
  deleteSelectedWithFiles(
    items: DownloadInfo[]
  ): Observable<BulkDeleteResult> {
    return new Observable<BulkDeleteResult>((observer) => {
      if (items.length === 0) {
        observer.next({
          total_requested: 0,
          succeeded: 0,
          files_deleted: [],
          errors: [],
        });
        observer.complete();
        return;
      }
      const result: BulkDeleteResult = {
        total_requested: items.length,
        succeeded: 0,
        files_deleted: [],
        errors: [],
      };
      let completed = 0;
      const tick = () => {
        completed += 1;
        if (completed === items.length) {
          observer.next(result);
          observer.complete();
        }
      };
      // Issue all requests in parallel — landing's /api/delete-download
      // is idempotent per-URL so concurrent calls don't conflict.
      for (const item of items) {
        this.deleteDownloadWithFile(item, true).subscribe({
          next: (res) => {
            if (res.success) {
              result.succeeded += 1;
              if (res.files_deleted) {
                result.files_deleted.push(...res.files_deleted);
              }
            } else {
              result.errors.push({ url: item.url, error: res.error || 'unknown' });
            }
            tick();
          },
          error: (err) => {
            result.errors.push({
              url: item.url,
              error: err.error?.error || err.message || 'network error',
            });
            tick();
          },
        });
      }
    });
  }

  /**
   * Convenience: delete EVERY item currently in the history with
   * files. Same shape as deleteSelectedWithFiles but operates over
   * the live /history snapshot to ensure nothing is missed.
   */
  deleteAllHistoryWithFiles(): Observable<BulkDeleteResult> {
    return new Observable<BulkDeleteResult>((observer) => {
      this.getHistory().subscribe({
        next: (data) => {
          const done = data.done || [];
          this.deleteSelectedWithFiles(done).subscribe({
            next: (r) => {
              observer.next(r);
              observer.complete();
            },
            error: (err) => observer.error(err),
          });
        },
        error: (err) => observer.error(err),
      });
    });
  }

  /**
   * Convenience: clear EVERY item currently in the queue (pending +
   * active downloads). Records only — no files involved (downloads
   * haven't completed yet).
   */
  clearAllQueue(): Observable<{ status: string }> {
    return new Observable((observer) => {
      this.getHistory().subscribe({
        next: (data) => {
          const urls = [
            ...(data.pending || []).map((i) => i.url),
            ...(data.queue || []).map((i) => i.url),
          ];
          if (urls.length === 0) {
            observer.next({ status: 'ok' });
            observer.complete();
            return;
          }
          this.deleteDownloads(urls, 'queue').subscribe({
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

  getCookieStatus(): Observable<CookieStatusResponse> {
    return this.http.get<CookieStatusResponse>(`${this.base}/cookie-status`);
  }

  getProfileStatus(): Observable<ProfileStatusResponse> {
    return this.http.get<ProfileStatusResponse>(`${this.base}/profile-status`);
  }

  /**
   * Aborted-history: vendor MeTube doesn't preserve cancelled queue
   * items. We persist them in a landing-side store so the user sees
   * "aborted" rows on the History page instead of the items vanishing.
   */
  getAbortedHistory(): Observable<AbortedHistoryResponse> {
    return this.http.get<AbortedHistoryResponse>(`${this.base}/aborted-history`);
  }

  recordAbortedItem(item: DownloadInfo): Observable<{ success: boolean; count?: number; error?: string }> {
    return this.http.post<{ success: boolean; count?: number; error?: string }>(
      `${this.base}/aborted-history`,
      {
        url: item.url,
        title: item.title || '',
        folder: item.folder || '',
        reason: 'user-cancel',
        percent: item.percent ?? null,
        speed: item.speed || '',
        eta: item.eta || '',
        size: item.size ?? null,
      },
    );
  }

  deleteAbortedHistory(urls: string[] | '*'): Observable<{ success: boolean; removed?: number; remaining?: number; error?: string }> {
    return this.http.request<{ success: boolean; removed?: number; remaining?: number; error?: string }>(
      'DELETE',
      `${this.base}/aborted-history`,
      { body: { urls } },
    );
  }

  uploadCookies(file: File): Observable<{ success: boolean; error?: string }> {
    const formData = new FormData();
    formData.append('cookies', file);
    return this.http.post<{ success: boolean; error?: string }>(`${this.base}/upload-cookies`, formData);
  }

  deleteCookies(): Observable<{ success: boolean; msg?: string; error?: string }> {
    return this.http.post<{ success: boolean; msg?: string; error?: string }>(`${this.base}/delete-cookies`, {});
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
