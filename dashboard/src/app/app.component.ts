import { Component } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, RouterLink, RouterLinkActive, RouterOutlet],
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
          </a>
          <a routerLink="/history" routerLinkActive="active">
            📜 History
          </a>
        </nav>
      </header>

      <main class="main">
        <router-outlet></router-outlet>
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
export class AppComponent {
  title = 'YT-DLP Dashboard';
}
