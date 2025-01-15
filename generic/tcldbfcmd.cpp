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
  dbf d -open $input_file [-readonly]
    opens dbase file, returns a handle.

  dbf d -create $input_file [-codepage $codepage]
    creates dbase file, returns a handle
*/

int TclDbfCmd::Command (int objc, Tcl_Obj * const objv[]) {
  if (objc < 4) {
    Tcl_WrongNumArgs(tclInterp, 1, objv, "<varname> -create|-open <filename> ?option?");
    return TCL_ERROR;
  }
  if (dbfcounter >= 0xFFFF) {
    Tcl_AppendResult(tclInterp, "too many dbfs open", NULL);
    return TCL_ERROR;
  }


  DBFHandle dbf;
  SAHooks sHooks;
  SASetupDefaultHooks(&sHooks);
  sHooks.bKeepFileExtension = !compatible; 
  Tcl_DString s;
  Tcl_DString e;
  Tcl_DStringInit(&s);
  Tcl_DStringInit(&e);
  int result = TCL_ERROR;

  char * varname = Tcl_GetString(objv[1]);
  char * filename = Tcl_UtfToExternalDString(NULL,
      Tcl_TranslateFileName(tclInterp, Tcl_GetString(objv[3]), &s), -1, &e);

  if (strcmp(Tcl_GetString(objv[2]), "-create") == 0) {

    const char * codepage = "LDID/87"; /* 87 - ANSI */
    if (objc == 6 && strcmp(Tcl_GetString(objv[4]), "-codepage") == 0) {
      codepage = Tcl_GetString(objv[5]);
    } else if (objc > 4) {
      Tcl_WrongNumArgs(tclInterp, 3, objv, "<filename> ?-codepage <codepage>?");
      goto exit;
    }

    dbf = DBFCreateLL(filename, codepage, &sHooks);
    if (compatible) {
      if (dbf == NULL) {
        Tcl_AppendResult(tclInterp, "0", NULL);
        result = TCL_OK;
        goto exit;
      } else {
        Tcl_AppendResult(tclInterp, "1", NULL);
      }
    } else if (dbf == NULL) {
      Tcl_AppendResult(tclInterp, "create ", Tcl_GetString(objv[3]), " failed", NULL);
      goto exit;
    }

  } else if (strcmp(Tcl_GetString(objv[2]), "-open") == 0) {

    const char * openmode = "rb+";
    if (objc == 5 && strcmp(Tcl_GetString(objv[4]), "-readonly") == 0) {
      openmode = "rb";
    } else if (objc > 4) {
      Tcl_WrongNumArgs(tclInterp, 3, objv, "<filename> ?-readonly?");
      goto exit;
    }

    dbf = DBFOpenLL(filename, openmode, &sHooks);
    if (compatible) {
      if (dbf == NULL) {
        Tcl_AppendResult(tclInterp, "Error: could not open input file ", filename, NULL);
        goto exit;
      } else {
        Tcl_AppendResult(tclInterp, "1", NULL);
      }
    } else if (dbf == NULL) {
      Tcl_AppendResult(tclInterp, "open ", Tcl_GetString(objv[3]), " failed", NULL);
      goto exit;
    }
  
  } else {
    Tcl_WrongNumArgs(tclInterp, 2, objv, "-create|-open <filename> ?option?");
    goto exit;
  }

  char cmdname[9];
  snprintf(cmdname, sizeof(cmdname), "dbf.%04X", dbfcounter++);
  (void) new TclDbfObjectCmd(tclInterp, cmdname, this, dbf, compatible);

  Tcl_SetVar2(tclInterp, varname, NULL, cmdname, 0);
  if (!compatible) {
    Tcl_AppendResult(tclInterp, cmdname, NULL);
  }
  result = TCL_OK;

exit:
  Tcl_DStringFree(&e);
  Tcl_DStringFree(&s);
  return result;
};
