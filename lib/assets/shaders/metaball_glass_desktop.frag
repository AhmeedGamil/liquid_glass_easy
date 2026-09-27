// Desktop (Impeller on OpenGL ES) entry: builds the LIQUID_GLASS_DESKTOP code,
// which ANGLE's D3D compiler on Windows handles in seconds instead of minutes.
#if defined(IMPELLER_TARGET_OPENGLES)
#define LIQUID_GLASS_DESKTOP
#endif
#include "metaball_glass.frag"
