import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink, RouterLinkActive } from '@angular/router';

@Component({
  selector: 'app-navbar',
  standalone: true,
  imports: [CommonModule, RouterLink, RouterLinkActive],
  template: `
    <nav class="navbar">
      <div class="brand">
        <span class="logo">📥</span>
        <span class="title">YT-DLP Dashboard</span>
      </div>
      <div class="links">
        <a routerLink="/download" routerLinkActive="active">Download</a>
        <a routerLink="/queue" routerLinkActive="active">Queue</a>
        <a routerLink="/history" routerLinkActive="active">History</a>
      </div>
    </nav>
  `,
  styles: [`
    .navbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 24px;
      height: 56px;
      background: linear-gradient(90deg, #1a1a2e 0%, #16213e 100%);
      border-bottom: 1px solid rgba(255,255,255,0.08);
      position: sticky;
      top: 0;
      z-index: 100;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .logo { font-size: 22px; }
    .title {
      font-size: 18px;
      font-weight: 600;
      background: linear-gradient(90deg, #ff0050, #ffcc00);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .links {
      display: flex;
      gap: 6px;
    }
    .links a {
      color: #aaa;
      text-decoration: none;
      padding: 6px 16px;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 500;
      transition: all 0.2s ease;
    }
    .links a:hover {
      color: #fff;
      background: rgba(255,255,255,0.06);
    }
    .links a.active {
      color: #fff;
      background: rgba(255,0,80,0.15);
    }
  `],
})
export class NavbarComponent {}
