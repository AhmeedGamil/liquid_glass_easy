// Windows (Impeller on ANGLE) entry: builds the LIQUID_GLASS_WINDOWS code,
// which ANGLE's D3D compiler handles in seconds instead of minutes.
#if defined(IMPELLER_TARGET_OPENGLES)
#define LIQUID_GLASS_WINDOWS
#endif
#include "liquid_glass.frag"
