#include <glib-object.h>
#include <vips/vips.h>

#include "g_object/g_object.h"
#include "utils.h"
#include "vips_interpolate.h"

ERL_NIF_TERM nif_interpolate_new(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]) {
  ASSERT_ARGC(argc, 1);

  ERL_NIF_TERM ret;
  ErlNifTime start;
  char name[1024] = {0};
  VipsInterpolate *interpolate = NULL;

  start = enif_monotonic_time(ERL_NIF_USEC);

  if (!get_binary(env, argv[0], name, 1024)) {
    ret = raise_badarg(env, "interpolate name must be a valid string");
    goto exit;
  }

  interpolate = vips_interpolate_new(name);

  if (!interpolate) {
    error("Failed to get interpolate for %s. error: %s", name,
          vips_error_buffer());
    vips_error_clear();
    ret = make_error(env, "Failed to create VipsInterpolate for given name");
    goto exit;
  }

  ret = make_ok(env, g_object_to_erl_term(env, (GObject *)interpolate));

exit:
  notify_consumed_timeslice(env, start, enif_monotonic_time(ERL_NIF_USEC));
  return ret;
}
