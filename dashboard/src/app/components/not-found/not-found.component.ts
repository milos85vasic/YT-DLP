import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'app-not-found',
  standalone: true,
  imports: [CommonModule, RouterLink],
  template: `
    <div class="page">
      <div class="icon">🚫</div>
      <h1>404 — Page Not Found</h1>
      <p>The page you're looking for doesn't exist.</p>
      <div class="actions">
        <a routerLink="/" class="btn-home">🏠 Go Home</a>
      </div>
    </div>
  `,
  styles: [`
    .page {
      text-align: center;
      padding: 100px 24px;
      max-width: 500px;
      margin: 0 auto;
      color: #888;
    }
    .icon { font-size: 64px; margin-bottom: 20px; }
    h1 { margin: 0 0 12px; font-size: 24px; color: #fff; }
    p { margin: 0 0 24px; font-size: 15px; line-height: 1.6; }
    .actions { display: flex; justify-content: center; }
    .btn-home {
      padding: 10px 20px;
      border-radius: 10px;
      background: rgba(0,150,255,0.12);
      border: 1px solid rgba(0,150,255,0.3);
      color: #66b3ff;
      text-decoration: none;
      font-size: 14px;
      font-weight: 600;
      transition: all 0.2s;
    }
    .btn-home:hover { background: rgba(0,150,255,0.2); }
  `],
})
export class NotFoundComponent {}
