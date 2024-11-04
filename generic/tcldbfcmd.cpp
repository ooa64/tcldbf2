#include <iostream>
#include "tcldbfcmd.hpp"

#if defined(TCLDBFCMD_DEBUG)
#   include <iostream>
#   define DEBUGLOG(_x_) (std::cerr << "DEBUG: " << _x_ << "\n")
#else
#   define DEBUGLOG(_x_)
#endif

int TclDbfCmd::Command(int objc, Tcl_Obj * const objv[]) {
  DEBUGLOG("TclDbfCmd::Command *" << this);

  Tcl_Obj * result = Tcl_GetObjResult(tclInterp);

  Tcl_AppendToObj(result, "Hello,", -1);
  if (objc > 1) {
    for (int i = 1; i < objc; i++) {
      Tcl_AppendToObj(result, " ", -1);
      Tcl_AppendObjToObj(result, objv[i]);
    }
  } else {
     Tcl_AppendToObj(result, " World", -1);
  }
  Tcl_AppendToObj(result, "!", -1);

  return TCL_OK;
};

void TclDbfCmd::Cleanup() {
  DEBUGLOG("TclDbfCmd::Cleanup *" << this);
};
