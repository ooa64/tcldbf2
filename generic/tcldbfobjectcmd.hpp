#ifndef TCLDBFOBJECTCMD_H
#define TCLDBFOBJECTCMD_H

#include <tcl.h>
#include <shapefil.h>
#include "tclcmd.hpp"

#include "codepages.c"

class TclDbfObjectCmd : public TclCmd {
public:
  TclDbfObjectCmd(Tcl_Interp * interp, const char * name, TclCmd * parent,
      DBFHandle handle): TclCmd(interp, name, parent) {
    Tcl_DStringInit(&dstring);
    encoding = Tcl_GetEncoding(NULL, codepage_encoding(handle->pszCodePage));    
    dbf = handle;
  } 

  virtual ~TclDbfObjectCmd() {
    DBFClose(dbf);
    Tcl_FreeEncoding(encoding);
    Tcl_DStringFree(&dstring);
  };

private:
  DBFHandle dbf;
  Tcl_Encoding encoding;
  Tcl_DString dstring;

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

  int AddField(Tcl_Obj * labelObj, Tcl_Obj * typeObj, Tcl_Obj * widthObj, Tcl_Obj * precObj);
  int GetField(Tcl_Obj * fieldObj, int index);

  virtual int Command(int objc, Tcl_Obj * const objv[]);
  virtual void Cleanup();
};

#endif
