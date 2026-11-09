#ifndef VIX_CLEANUP_H
#define VIX_CLEANUP_H

#include <glib-object.h>

/* Stops any threads it started if it fails */
int vix_cleanup_start(void);

/* Frees the queued values. Call only when nothing can queue more */
void vix_cleanup_stop(void);

/* Both take ownership of the value */
void vix_cleanup_object(GObject *object);

void vix_cleanup_boxed(GType type, gpointer boxed);

#endif
