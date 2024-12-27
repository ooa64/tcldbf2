#include <string.h>
#include "tcldbfcmd.hpp"
#include "tcldbfobjectcmd.hpp"

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
  if (objc < 4) {
    Tcl_WrongNumArgs(tclInterp, 1, objv, "<varname> create|open <filename> ?option?");
    return TCL_ERROR;
  }

  int result = TCL_ERROR;
  DBFHandle dbf;
  Tcl_DString s;
  Tcl_DString e;
  Tcl_DStringInit(&s);
  Tcl_DStringInit(&e);

  char * varname = Tcl_GetString(objv[1]);
  char * filename = Tcl_UtfToExternalDString(NULL,
      Tcl_TranslateFileName(tclInterp, Tcl_GetString(objv[3]), &s), -1, &e);

  if (strcmp(Tcl_GetString(objv[2]), "create") == 0 ||
      strcmp(Tcl_GetString(objv[2]), "-create") == 0) {

    const char * codepage = "LDID/87"; /* 87 - ANSI */
    if (objc == 6 && strcmp(Tcl_GetString(objv[4]), "-codepage") == 0) {
      codepage = Tcl_GetString(objv[5]);
    } else if (objc > 4) {
      Tcl_WrongNumArgs(tclInterp, 1, objv, "<varname> create <filename> ?-codepage <codepage>?");
      result = TCL_ERROR;
      goto exit;
    }

    dbf = DBFCreateEx(filename, codepage);
    if (dbf == NULL) {
      Tcl_AppendResult(tclInterp, "create ", Tcl_GetString(objv[3]), " failed", NULL);
      result = TCL_ERROR;
      goto exit;
    }

  } else if (strcmp(Tcl_GetString(objv[2]), "open") == 0 ||
        strcmp(Tcl_GetString(objv[2]), "-open") == 0) {

    const char * openmode = "rb+";
    if (objc == 5 && strcmp(Tcl_GetString(objv[4]), "-readonly") == 0) {
      openmode = "rb";
    } else if (objc > 4) {
      Tcl_WrongNumArgs(tclInterp, 1, objv, "<varname> open <filename> ?-readonly?");
      result = TCL_ERROR;
      goto exit;
    }

    dbf = DBFOpen(filename, openmode);
    if (dbf == NULL) {
      Tcl_AppendResult(tclInterp, "open ", Tcl_GetString(objv[3]), " failed", NULL);
      result = TCL_ERROR;
      goto exit;
    }
  
  } else {
    Tcl_WrongNumArgs(tclInterp, 1, objv, "<varname> create|open <filename> ?option?");
    result = TCL_ERROR;
    goto exit;
  }

  char cmdname[9];
  snprintf(cmdname, sizeof(cmdname), "dbf.%04X", dbfcounter++);
  (void) new TclDbfObjectCmd(tclInterp, cmdname, this, dbf);

  Tcl_SetVar2(tclInterp, varname, NULL, cmdname, 0);
  if (Tcl_GetString(objv[2])[0] != '-') {
    // NOTE: SetResult produces strange result, like memory dump
    // Tcl_SetResult(tclInterp, cmdname, NULL);
    Tcl_AppendResult(tclInterp, cmdname, NULL);
  }
  result = TCL_OK;

exit:
  Tcl_DStringFree(&e);
  Tcl_DStringFree(&s);
  if (Tcl_GetString(objv[2])[0] == '-') {
    // v.1 compatibility
    Tcl_SetResult(tclInterp, (char *)(result == TCL_OK ? "1" : "0"), NULL);
    return TCL_OK;
  }
  return result;
};
