#include <glib-object.h>

#include "../utils.h"

#include "g_object.h"

ErlNifResourceType *G_OBJECT_RT;

static ERL_NIF_TERM ATOM_UNREF_GOBJECT;

// Ownership is transferred to beam, `obj` must *not* be freed
// by the caller
ERL_NIF_TERM g_object_to_erl_term(ErlNifEnv *env, GObject *obj) {
  ERL_NIF_TERM term;
  GObjectResource *gobject_r;

  gobject_r = enif_alloc_resource(G_OBJECT_RT, sizeof(GObjectResource));

  // TODO: Keep gtype name and use elixir-struct instead of c-struct,
  // so that type information is visible in elixir.
  gobject_r->obj = obj;

  term = enif_make_resource(env, gobject_r);
  enif_release_resource(gobject_r);

  return term;
}

ERL_NIF_TERM nif_g_object_type_name(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  GObject *obj;

  if (!erl_term_to_g_object(env, argv[0], &obj))
    return make_error(env, "Failed to get GObject");

  return make_binary(env, G_OBJECT_TYPE_NAME(obj));
}

ERL_NIF_TERM nif_g_object_unref(ErlNifEnv *env, int argc,
                                const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  GObjectResource *gobject_r = NULL;

  if (!enif_get_resource(env, argv[0], G_OBJECT_RT, (void **)&gobject_r)) {
    // This should never happen, since g_object_unref is an internal call
    return ATOM_ERROR;
  }

  g_object_unref(gobject_r->obj);
  gobject_r->obj = NULL;

  debug("GObject unref");

  return ATOM_OK;
}

bool erl_term_to_g_object(ErlNifEnv *env, ERL_NIF_TERM term, GObject **obj) {
  GObjectResource *gobject_r = NULL;
  if (enif_get_resource(env, term, G_OBJECT_RT, (void **)&gobject_r)) {
    (*obj) = gobject_r->obj;
    return true;
  }
  return false;
}

static void g_object_dtor(ErlNifEnv *env, void *ptr) {
  GObjectResource *orig_gobject_r = (GObjectResource *)ptr;

  /**
   * The resource destructor is executed inside a normal scheduler instead of a
   * dirty scheduler, which can cause issues if the code is time-consuming.
   * See: https://erlangforums.com/t/4290
   *
   * To address this, we avoid performing time-consuming work in the destructor
   * and offload it to a janitor process. The Janitor process then calls the
   * time-consuming cleanup NIF code on a dirty scheduler. Since Beam
   * deallocates the resource at the end of the `dtor` call, we must create a
   * new resource term to pass the object to the janitor process.
   *
   * Resources can be of two types:
   *
   *   1. Normal Resource: Constructed during normal operations; the pointer to
   * the object is never NULL in this case.
   *
   *   2. Internal Resource: Constructed within the `dtor` of a normal resource
   * solely for cleanup purposes and not for image processing operations. The
   * pointer to the object will be NULL after cleanup.
   *
   * Currently, we use this length approach for all `g_object` and
   * `g_boxed` objects, including smaller types like `VipsArray` of
   * integers or doubles. For these smaller objects, it might be more
   * efficient to skip certain steps. However, we are deferring the
   * implementation of such special cases to keep the code simple for
   * now.
   *
   */
  if (orig_gobject_r->obj != NULL) {
    GObjectResource *temp_gobject_r = NULL;
    ERL_NIF_TERM temp_term;

    /* Create temporary internal resource for the cleanup */
    temp_gobject_r = enif_alloc_resource(G_OBJECT_RT, sizeof(GObjectResource));
    temp_gobject_r->obj = orig_gobject_r->obj;

    temp_term = enif_make_resource(env, temp_gobject_r);
    enif_release_resource(temp_gobject_r);
    send_to_janitor(env, ATOM_UNREF_GOBJECT, temp_term);
    debug("GObjectResource is sent to janitor process");
  } else {
    debug("GObjectResource is already unset");
  }

  return;
}

int nif_g_object_init(ErlNifEnv *env) {
  G_OBJECT_RT = enif_open_resource_type(
      env, NULL, "g_object_resource", (ErlNifResourceDtor *)g_object_dtor,
      ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  if (!G_OBJECT_RT) {
    error("Failed to open gobject_resource");
    return 1;
  }

  ATOM_UNREF_GOBJECT = make_atom(env, "unref_gobject");

  return 0;
}
