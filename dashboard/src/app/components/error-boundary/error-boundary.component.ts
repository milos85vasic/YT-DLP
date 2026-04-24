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
      color: #cc7832;
    }
    .error-icon { font-size: 64px; margin-bottom: 16px; }
    h2 { margin: 0 0 12px; font-size: 22px; color: #a9b7c6; }
    p { margin: 0 0 24px; font-size: 14px; color: #808080; line-height: 1.6; }
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
      background: rgba(204,120,50,0.12);
      border: 1px solid rgba(204,120,50,0.3);
      color: #cc7832;
    }
    .btn-retry:hover { background: rgba(204,120,50,0.2); }
    .btn-home {
      background: rgba(104,151,187,0.12);
      border: 1px solid rgba(104,151,187,0.3);
      color: #6897bb;
    }
    .btn-home:hover { background: rgba(104,151,187,0.2); }
    .content { display: contents; }
    @media (max-width: 640px) {
      .error-fallback { padding: 60px 20px; }
      h2 { font-size: 20px; }
      .error-icon { font-size: 48px; }
    }
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
