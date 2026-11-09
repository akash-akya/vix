#include "cleanup.h"
#include "utils.h"

/*
 * Freeing a libvips object can be slow (see https://erlangforums.com/t/4290),
 * and resource destructors run on normal schedulers. So destructors queue the
 * values here, and cleanup threads free them.
 *
 * GThreadPool would fit, but the bundled libvips does not export its APIs.
 */

#define CLEANUP_THREADS 2

typedef struct {
  GType boxed_type; // G_TYPE_INVALID for a GObject
  gpointer ptr;
} CleanupJob;

static GAsyncQueue *cleanup_queue;
static GThread *cleanup_threads[CLEANUP_THREADS];
static int cleanup_thread_count;

/* Queued once per thread to stop it, after the jobs queued before it */
static CleanupJob stop_job;

static gpointer cleanup_thread(gpointer data) {
  CleanupJob *job;

  while ((job = g_async_queue_pop(cleanup_queue)) != &stop_job) {
    if (job->boxed_type == G_TYPE_INVALID) {
      g_object_unref(job->ptr);
    } else {
      g_boxed_free(job->boxed_type, job->ptr);
    }

    g_free(job);
  }

  return NULL;
}

static void push_job(GType boxed_type, gpointer ptr) {
  CleanupJob *job = g_new(CleanupJob, 1);

  job->boxed_type = boxed_type;
  job->ptr = ptr;
  g_async_queue_push(cleanup_queue, job);
}

int vix_cleanup_start(void) {
  cleanup_queue = g_async_queue_new();

  for (int i = 0; i < CLEANUP_THREADS; i++) {
    cleanup_threads[i] =
        g_thread_try_new("vix-cleanup", cleanup_thread, NULL, NULL);

    if (!cleanup_threads[i]) {
      error("Failed to start a cleanup thread");
      vix_cleanup_stop();
      return 1;
    }

    cleanup_thread_count++;
  }

  return 0;
}

void vix_cleanup_stop(void) {
  for (int i = 0; i < cleanup_thread_count; i++)
    g_async_queue_push(cleanup_queue, &stop_job);

  for (int i = 0; i < cleanup_thread_count; i++)
    g_thread_join(cleanup_threads[i]);

  cleanup_thread_count = 0;
  g_async_queue_unref(cleanup_queue);
  cleanup_queue = NULL;
}

void vix_cleanup_object(GObject *object) { push_job(G_TYPE_INVALID, object); }

void vix_cleanup_boxed(GType type, gpointer boxed) { push_job(type, boxed); }
