import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./components/download-form/download-form.component').then(
        (m) => m.DownloadFormComponent
      ),
  },
  {
    path: 'queue',
    loadComponent: () =>
      import('./components/queue/queue.component').then(
        (m) => m.QueueComponent
      ),
  },
  {
    path: 'history',
    loadComponent: () =>
      import('./components/history/history.component').then(
        (m) => m.HistoryComponent
      ),
  },
  {
    path: '**',
    loadComponent: () =>
      import('./components/not-found/not-found.component').then(
        (m) => m.NotFoundComponent
      ),
  },
];
