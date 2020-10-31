#include "vix_common.h"
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <vips/vips.h>

static ERL_NIF_TERM ATOM_TRUE;
static ERL_NIF_TERM ATOM_FALSE;
static ERL_NIF_TERM ATOM_OK;
static ERL_NIF_TERM ATOM_ERROR;

static int on_load(ErlNifEnv *env, void **priv, ERL_NIF_TERM load_info) {
  ATOM_TRUE = enif_make_atom(env, "true");
  ATOM_FALSE = enif_make_atom(env, "false");
  ATOM_OK = enif_make_atom(env, "ok");
  ATOM_ERROR = enif_make_atom(env, "error");

  if (VIPS_INIT(""))
    return 1;

  return 0;
}

static void on_unload(ErlNifEnv *env, void *priv) { debug("vix unload"); }

static ErlNifFunc nif_funcs[] = {{"gintro", 0, gintro, USE_DIRTY_IO},
                                 {"invert", 2, invert, USE_DIRTY_IO}};

ERL_NIF_INIT(Elixir.Vix.VipsObjectNif, nif_funcs, &on_load, NULL, NULL,
             &on_unload)
