#ifndef NIF_VIPS_IMAGE_H
#define NIF_VIPS_IMAGE_H

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include "erl_nif.h"

ERL_NIF_TERM nif_image_new_from_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_write_to_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_new(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_new_temp_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]);

#endif
