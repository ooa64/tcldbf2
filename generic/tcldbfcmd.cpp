#include <string.h>
#include "tcldbfcmd.hpp"

#if defined(TCLDBFCMD_DEBUG)
#   include <iostream>
#   define DEBUGLOG(_x_) (std::cerr << "DEBUG: " << _x_ << "\n")
#else
#   define DEBUGLOG(_x_)
#endif

/*
  dbf d -open|open $input_file [-readonly]
    opens dbase file, returns a handle.
  dbf d -create|create $input_file [-codepage $codepage]
    creates dbase file, returns a handle
*/

int TclDbfCmd::Command(int objc, Tcl_Obj * const objv[]) {
  DEBUGLOG("TclDbfCmd::Command *" << this);

  if (objc < 4) {
    Tcl_WrongNumArgs(tclInterp, 1, objv, "<varname> -create|-open <filename> ?option?");
    return TCL_ERROR;
  }
  char *filename = Tcl_GetString(objv[3]);

  if (strcmp(Tcl_GetString(objv[2]), "-create") == 0) {

  } else if (strcmp(Tcl_GetString(objv[2]), "-open") == 0) {
  
  }

  return TCL_OK;
};

void TclDbfCmd::Cleanup() {
  DEBUGLOG("TclDbfCmd::Cleanup *" << this);
};
