#include <vips/vips.h>

#include "async.h"
#include "cleanup.h"
#include "utils.h"

/*
 * A streaming save waits while its reader is slow. On a dirty scheduler that
 * wait can deadlock, since the reader may need a dirty scheduler too (file
 * writes do). So the save runs on a thread, and the caller waits for a
 * message.
 *
 * Each job gets its own thread. `slots` limits the jobs running at once. A
 * job gives up its slot while it waits on its reader, so slow readers never
 * keep other jobs from running.
 */

#define MAX_ARGC 3

// the default number of dirty IO schedulers, which saves ran on before
#define MAX_RUNNING_JOBS 10

typedef struct {
  ErlNifEnv *env;
  ErlNifPid caller;
  ERL_NIF_TERM ref;
  VixNif nif;
  int argc;
  ERL_NIF_TERM argv[MAX_ARGC];
} Job;

static GMutex lock;
static GCond slot_free;
static GCond no_jobs;
static GQueue pending = G_QUEUE_INIT;
static int slots = MAX_RUNNING_JOBS;
static int resuming; // jobs waiting for a slot after a wait
static int jobs;     // queued or running

static ERL_NIF_TERM ATOM_VIX_RAISE;

/* `caller_env` is the NIF env on a scheduler thread, NULL on our threads */
static void start_job(ErlNifEnv *caller_env, Job *job);

/* Call with the lock held */
static Job *take_pending_job(void) {
  if (slots > resuming && !g_queue_is_empty(&pending)) {
    slots--;
    return g_queue_pop_head(&pending);
  }
  return NULL;
}

static void release_slot(ErlNifEnv *caller_env) {
  Job *job;

  g_mutex_lock(&lock);
  slots++;
  g_cond_signal(&slot_free);
  job = take_pending_job();
  g_mutex_unlock(&lock);

  if (job)
    start_job(caller_env, job);
}

static void acquire_slot(void) {
  g_mutex_lock(&lock);
  resuming++;
  while (slots == 0)
    g_cond_wait(&slot_free, &lock);
  slots--;
  resuming--;
  g_mutex_unlock(&lock);
}

void vix_async_wait(GCond *cond, GMutex *mutex) {
  release_slot(NULL);
  g_cond_wait(cond, mutex);

  // do not hold the caller's lock while waiting for a slot
  g_mutex_unlock(mutex);
  acquire_slot();
  g_mutex_lock(mutex);
}

static void finish_job(ErlNifEnv *caller_env, Job *job, ERL_NIF_TERM result) {
  enif_send(caller_env, &job->caller, job->env,
            enif_make_tuple2(job->env, job->ref, result));
  enif_free_env(job->env);
  g_free(job);

  g_mutex_lock(&lock);
  if (--jobs == 0)
    g_cond_broadcast(&no_jobs);
  g_mutex_unlock(&lock);
}

static gpointer run_job(gpointer data) {
  Job *job = (Job *)data;
  ERL_NIF_TERM result, reason;

  result = job->nif(job->env, job->argc, job->argv);
  if (enif_has_pending_exception(job->env, &reason))
    result = enif_make_tuple2(job->env, ATOM_VIX_RAISE, reason);

  release_slot(NULL);

  // a thread still running this code must be joined before the unload
  vix_cleanup_thread(g_thread_ref(g_thread_self()));
  finish_job(NULL, job, result);
  return NULL;
}

static void start_job(ErlNifEnv *caller_env, Job *job) {
  GThread *thread = vips_g_thread_new("vix", run_job, job);

  if (thread) {
    g_thread_unref(thread);
    return;
  }

  vips_error_clear();
  finish_job(caller_env, job, make_error(job->env, "Failed to start a thread"));
  release_slot(caller_env);
}

ERL_NIF_TERM vix_async(ErlNifEnv *env, VixNif nif, int argc,
                       const ERL_NIF_TERM argv[]) {
  Job *job;

  if (argc < 1 || argc > MAX_ARGC + 1)
    return enif_make_badarg(env);

  job = g_new(Job, 1);
  job->env = enif_alloc_env();
  job->nif = nif;
  job->ref = enif_make_copy(job->env, argv[0]);
  job->argc = argc - 1;
  for (int i = 0; i < job->argc; i++)
    job->argv[i] = enif_make_copy(job->env, argv[i + 1]);
  enif_self(env, &job->caller);

  g_mutex_lock(&lock);
  jobs++;
  g_queue_push_tail(&pending, job);
  job = take_pending_job();
  g_mutex_unlock(&lock);

  if (job)
    start_job(env, job);

  return ATOM_OK;
}

/* Call before vix_cleanup_stop(), which joins the threads */
void vix_async_stop(void) {
  g_mutex_lock(&lock);
  while (jobs > 0)
    g_cond_wait(&no_jobs, &lock);
  g_mutex_unlock(&lock);
}

int vix_async_init(ErlNifEnv *env) {
  ATOM_VIX_RAISE = make_atom(env, "vix_raise");
  return 0;
}
