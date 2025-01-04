#include "tcldbfcmd.hpp"

extern "C" {
  DLLEXPORT int Tcldbf_Init (Tcl_Interp *interp);
  DLLEXPORT int Dbf_Init (Tcl_Interp *interp);
}

int init (Tcl_Interp *interp, const char * name, const char * version, bool compatible) {
#ifdef USE_TCL_STUBS    
  if (Tcl_InitStubs(interp, STUB_VERSION, 0) == NULL) {
      return TCL_ERROR;
  }
#endif
  if (Tcl_FindCommand(interp, "dbf", NULL, 0)) {
    Tcl_AppendResult(interp, "dbf command already exists", NULL);
    return TCL_ERROR;
  }
  new TclDbfCmd(interp, "dbf", compatible);
  Tcl_PkgProvide(interp, name, version);
  return TCL_OK;
}

int Tcldbf_Init (Tcl_Interp *interp) {
  return init(interp, PACKAGE_NAME, PACKAGE_VERSION, false);
}

int Dbf_Init (Tcl_Interp *interp) {
  return init(interp, PACKAGE_NAME2, PACKAGE_VERSION2, true);
}
