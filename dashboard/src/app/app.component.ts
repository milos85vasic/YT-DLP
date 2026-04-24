import { Component, OnInit, OnDestroy } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { CommonModule } from '@angular/common';
import { Subscription } from 'rxjs';
import { MetubeService } from './services/metube.service';
import { ErrorBoundaryComponent } from './components/error-boundary/error-boundary.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, RouterLink, RouterLinkActive, RouterOutlet, ErrorBoundaryComponent],
  template: `
    <div class="app">
      <header class="header">
        <div class="brand">
          <div class="logo">YT-DLP</div>
          <span class="tag">Dashboard</span>
        </div>
        <nav class="nav">
          <a routerLink="/" routerLinkActive="active" [routerLinkActiveOptions]="{exact:true}">
            📥 Download
          </a>
          <a routerLink="/queue" routerLinkActive="active">
            ⏳ Queue
            <span class="badge" *ngIf="queueCount > 0">{{ queueCount }}</span>
          </a>
          <a routerLink="/history" routerLinkActive="active">
            📜 History
            <span class="badge error" *ngIf="errorCount > 0">{{ errorCount }}</span>
          </a>
          <a routerLink="/cookies" routerLinkActive="active">
            🍪 Cookies
            <span class="badge cookie-stale" *ngIf="cookieStale">!</span>
          </a>
        </nav>
        <div class="connection-status" [class.offline]="!apiOnline">
          <span *ngIf="apiOnline" class="dot online"></span>
          <span *ngIf="!apiOnline" class="dot offline"></span>
          <span class="label">{{ apiOnline ? 'Online' : 'Offline' }}</span>
        </div>
      </header>

      <main class="main">
        <app-error-boundary>
          <router-outlet></router-outlet>
        </app-error-boundary>
      </main>

      <footer class="footer">
        <span>Powered by MeTube API</span>
        <span>YT-DLP Dashboard</span>
      </footer>
    </div>
  `,
  styles: [`
    .app {
      display: flex;
      flex-direction: column;
      min-height: 100vh;
      background: #2b2b2b;
      color: #a9b7c6;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 24px;
      height: 56px;
      background: #3c3f41;
      border-bottom: 1px solid #555555;
      position: sticky;
      top: 0;
      z-index: 100;
      backdrop-filter: blur(12px);
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .logo {
      font-size: 18px;
      font-weight: 800;
      color: #a9b7c6;
    }
    .tag {
      font-size: 11px;
      padding: 3px 8px;
      background: rgba(255,255,255,0.06);
      border-radius: 6px;
      color: #888;
    }
    .nav {
      display: flex;
      gap: 4px;
    }
    .nav a {
      position: relative;
      padding: 8px 16px;
      border-radius: 10px;
      font-size: 13px;
      font-weight: 500;
      color: #808080;
      text-decoration: none;
      transition: all 0.2s;
    }
    .nav a:hover { color: #a9b7c6; background: rgba(157,0,30,0.08); }
    .nav a.active { color: #a9b7c6; background: rgba(157,0,30,0.15); }
    .badge {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-width: 18px;
      height: 18px;
      padding: 0 5px;
      margin-left: 6px;
      background: rgba(104,151,187,0.15);
      color: #6897bb;
      border-radius: 9px;
      font-size: 10px;
      font-weight: 700;
    }
    .badge.error {
      background: rgba(204,120,50,0.15);
      color: #cc7832;
    }
    .badge.cookie-stale {
      background: rgba(217,164,65,0.15);
      color: #d9a441;
    }
    .connection-status {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 11px;
      font-weight: 600;
      color: #00ff88;
      padding: 4px 10px;
      border-radius: 8px;
      background: rgba(0,255,136,0.08);
      border: 1px solid rgba(0,255,136,0.15);
      transition: all 0.3s;
    }
    .connection-status.offline {
      color: #cc7832;
      background: rgba(204,120,50,0.08);
      border-color: rgba(204,120,50,0.15);
    }
    .dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
    }
    .dot.online { background: #6a8759; box-shadow: 0 0 6px rgba(106,135,89,0.5); }
    .dot.offline { background: #cc7832; box-shadow: 0 0 6px rgba(204,120,50,0.5); }
    .main { flex: 1; }
    .footer {
      display: flex;
      justify-content: space-between;
      padding: 16px 24px;
      font-size: 11px;
      color: #555555;
      border-top: 1px solid #555555;
    }
    @media (max-width: 640px) {
      .header { flex-wrap: wrap; height: auto; padding: 12px 16px; gap: 8px; }
      .brand { gap: 6px; }
      .logo { font-size: 16px; }
      .nav { flex-wrap: wrap; width: 100%; justify-content: center; gap: 2px; }
      .nav a { padding: 6px 10px; font-size: 12px; }
      .connection-status { font-size: 10px; padding: 3px 8px; }
      .footer { flex-direction: column; text-align: center; gap: 4px; padding: 12px 16px; }
    }
  `],
})
export class AppComponent implements OnInit, OnDestroy {
  title = 'YT-DLP Dashboard';
  queueCount = 0;
  errorCount = 0;
  cookieStale = false;
  apiOnline = true;
  private sub?: Subscription;
  private cookieSub?: Subscription;

  constructor(private metube: MetubeService) {}

  ngOnInit(): void {
    this.sub = this.metube.getHistoryPolling(2000).subscribe({
      next: (data) => {
        this.apiOnline = true;
        this.queueCount = (data.queue?.length || 0) + (data.pending?.length || 0);
        this.errorCount = (data.done || []).filter((i) => i.status === 'error').length;
      },
      error: (err) => {
        this.apiOnline = false;
        this.queueCount = 0;
        this.errorCount = 0;
        console.error('Nav poll error', err);
      },
    });
    this.cookieSub = this.metube.getCookieStatus().subscribe({
      next: (data) => {
        this.cookieStale = !data.has_cookies || (data.cookie_age_minutes || 0) > 60;
      },
      error: () => {
        this.cookieStale = true;
      },
    });
  }

  ngOnDestroy(): void {
    this.sub?.unsubscribe();
    this.cookieSub?.unsubscribe();
  }
}
