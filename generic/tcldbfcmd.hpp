#ifndef TCLDBFCMD_H
#define TCLDBFCMD_H

#include <tcl.h>
#include <shapefil.h>
#include "tclcmd.hpp"

class TclDbfCmd : public TclCmd {

public:

  TclDbfCmd (Tcl_Interp * interp, const char * name, bool v1compatible):
      TclCmd(interp, name), dbfcounter(0), compatible(v1compatible) {}

private:

  int dbfcounter;
  bool compatible;
  virtual int Command (int objc, Tcl_Obj * const objv[]);
};

#endif