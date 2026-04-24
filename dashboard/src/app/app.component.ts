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
        </nav>
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
      background: #0d0d0d;
      color: #eee;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 24px;
      height: 56px;
      background: rgba(255,255,255,0.03);
      border-bottom: 1px solid rgba(255,255,255,0.06);
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
      background: linear-gradient(90deg, #ff0050, #ffcc00);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
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
      color: #999;
      text-decoration: none;
      transition: all 0.2s;
    }
    .nav a:hover { color: #fff; background: rgba(255,255,255,0.05); }
    .nav a.active { color: #fff; background: rgba(255,0,80,0.12); }
    .badge {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-width: 18px;
      height: 18px;
      padding: 0 5px;
      margin-left: 6px;
      background: rgba(0,150,255,0.2);
      color: #66b3ff;
      border-radius: 9px;
      font-size: 10px;
      font-weight: 700;
    }
    .badge.error {
      background: rgba(255,0,80,0.2);
      color: #ff5588;
    }
    .main { flex: 1; }
    .footer {
      display: flex;
      justify-content: space-between;
      padding: 16px 24px;
      font-size: 11px;
      color: #444;
      border-top: 1px solid rgba(255,255,255,0.04);
    }
  `],
})
export class AppComponent implements OnInit, OnDestroy {
  title = 'YT-DLP Dashboard';
  queueCount = 0;
  errorCount = 0;
  private sub?: Subscription;

  constructor(private metube: MetubeService) {}

  ngOnInit(): void {
    this.sub = this.metube.getHistoryPolling(2000).subscribe({
      next: (data) => {
        this.queueCount = (data.queue?.length || 0) + (data.pending?.length || 0);
        this.errorCount = (data.done || []).filter((i) => i.status === 'error').length;
      },
      error: (err) => console.error('Nav poll error', err),
    });
  }

  ngOnDestroy(): void {
    this.sub?.unsubscribe();
  }
}
