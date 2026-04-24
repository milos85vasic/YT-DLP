import { Component, ErrorHandler, Injectable } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';

@Injectable({ providedIn: 'root' })
export class GlobalErrorHandler implements ErrorHandler {
  constructor(private router: Router) {}

  handleError(error: Error): void {
    console.error('Global error caught:', error);
    // Navigate to error page for catastrophic errors
    if (error.message?.includes('Cannot read') || error.message?.includes('undefined')) {
      // Don't navigate automatically for minor errors
    }
  }
}

@Component({
  selector: 'app-error-boundary',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div *ngIf="hasError" class="error-fallback">
      <div class="error-icon">💥</div>
      <h2>Something went wrong</h2>
      <p>{{ errorMessage }}</p>
      <div class="actions">
        <button class="btn-retry" (click)="reload()">↻ Reload Page</button>
        <button class="btn-home" (click)="goHome()">🏠 Go Home</button>
      </div>
    </div>
    <div *ngIf="!hasError" class="content">
      <ng-content></ng-content>
    </div>
  `,
  styles: [`
    .error-fallback {
      text-align: center;
      padding: 80px 24px;
      max-width: 500px;
      margin: 0 auto;
      color: #ff5588;
    }
    .error-icon { font-size: 64px; margin-bottom: 16px; }
    h2 { margin: 0 0 12px; font-size: 22px; color: #fff; }
    p { margin: 0 0 24px; font-size: 14px; color: #aaa; line-height: 1.6; }
    .actions {
      display: flex;
      gap: 12px;
      justify-content: center;
      flex-wrap: wrap;
    }
    .btn-retry, .btn-home {
      padding: 10px 20px;
      border-radius: 10px;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
      border: none;
    }
    .btn-retry {
      background: rgba(255,85,136,0.12);
      border: 1px solid rgba(255,85,136,0.3);
      color: #ff5588;
    }
    .btn-retry:hover { background: rgba(255,85,136,0.2); }
    .btn-home {
      background: rgba(0,150,255,0.12);
      border: 1px solid rgba(0,150,255,0.3);
      color: #66b3ff;
    }
    .btn-home:hover { background: rgba(0,150,255,0.2); }
    .content { display: contents; }
  `],
})
export class ErrorBoundaryComponent {
  hasError = false;
  errorMessage = 'An unexpected error occurred.';

  constructor(private router: Router) {}

  catchError(message: string): void {
    this.hasError = true;
    this.errorMessage = message;
  }

  reload(): void {
    window.location.reload();
  }

  goHome(): void {
    this.hasError = false;
    this.router.navigate(['/']);
  }
}
