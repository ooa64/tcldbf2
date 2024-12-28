#ifndef TCLDBFOBJECTCMD_H
#define TCLDBFOBJECTCMD_H

#include <tcl.h>
#include <shapefil.h>
#include "tclcmd.hpp"

class TclDbfObjectCmd : public TclCmd {

public:
  TclDbfObjectCmd(Tcl_Interp * interp, const char * name, TclCmd * parent, DBFHandle handle);
  virtual ~TclDbfObjectCmd();

  void SetLastError(const char * s) {
    Tcl_DStringSetLength(&dstring, 0);
    Tcl_DStringAppend(&message, s, -1);
  }

private:
  DBFHandle dbf;
  Tcl_Encoding encoding;
  Tcl_DString dstring;
  Tcl_DString message;

  inline const char * EncodeTclString(const char * s) {
    Tcl_DStringFree(&dstring);
    Tcl_ExternalToUtfDString(encoding, s, -1, &dstring);
    return Tcl_DStringValue(&dstring);
  };

  inline const char * DecodeTclString(const char * s) {
    Tcl_DStringFree(&dstring);
    Tcl_UtfToExternalDString(encoding, s, -1, &dstring);
    return Tcl_DStringValue(&dstring);
  };

  int CheckLastError() {
    if (Tcl_DStringLength(&message)) {
      Tcl_DStringResult(tclInterp, &message);
      return TCL_ERROR;
    }
    return TCL_OK;
  }

  int AddField(Tcl_Obj * labelObj, Tcl_Obj * typeObj, Tcl_Obj * widthObj, Tcl_Obj * precObj);
  int GetField(Tcl_Obj * fieldObj, int index);
  int SetFieldValue(int rowid, int index, Tcl_Obj * valueObj);
  int GetFieldValue(int rowid, int index, Tcl_Obj ** valueObj);
  int GetRowid(Tcl_Obj * rowidObj, int * rowid);

  virtual int Command(int objc, Tcl_Obj * const objv[]);
};

#endif
