#include "tcldbfcmd.hpp"

extern "C" {
  DLLEXPORT int Tcldbf_Init (Tcl_Interp *interp);
}

static void Tcldbf_Done(void *);

TclDbfCmd * cmd = NULL;

int Tcldbf_Init (Tcl_Interp *interp) {

  if (!cmd) {
#ifdef USE_TCL_STUBS    
    if (Tcl_InitStubs(interp, STUB_VERSION, 0) == NULL) {
        return TCL_ERROR;
    }
#endif
    cmd = new TclDbfCmd(interp, "dbf");
    Tcl_CreateExitHandler(Tcldbf_Done, NULL);
    Tcl_PkgProvide(interp, PACKAGE_NAME, PACKAGE_VERSION);
  }

  return TCL_OK;
}

static void Tcldbf_Done(void *) {
  if (cmd) {
    delete cmd;
    cmd = NULL;
  }
}
