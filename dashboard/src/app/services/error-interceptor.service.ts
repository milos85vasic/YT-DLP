import { Injectable } from '@angular/core';
import { HttpInterceptor, HttpRequest, HttpHandler, HttpEvent, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';

@Injectable()
export class ErrorInterceptor implements HttpInterceptor {
  intercept(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    return next.handle(req).pipe(
      catchError((error: HttpErrorResponse) => {
        let message = 'Request failed';

        if (error.status === 0) {
          message = 'Cannot connect to the server. Is the MeTube service running?';
        } else if (error.status === 502 || error.status === 504) {
          message = 'The MeTube backend is unreachable (gateway error). Check if containers are running.';
        } else if (error.status === 404) {
          message = `API endpoint not found: ${req.url}`;
        } else if (error.status >= 500) {
          message = `Server error (${error.status}). Try again later.`;
        } else if (error.error?.msg) {
          message = error.error.msg;
        } else if (error.error?.error) {
          message = error.error.error;
        } else if (error.message) {
          message = error.message;
        }

        console.error(`[HTTP ${error.status}] ${req.method} ${req.url}: ${message}`);
        return throwError(() => ({ ...error, friendlyMessage: message }));
      })
    );
  }
}
