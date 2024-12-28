#ifndef TCLDBFCMD_H
#define TCLDBFCMD_H

#include <tcl.h>
#include <shapefil.h>
#include "tclcmd.hpp"

class TclDbfCmd : public TclCmd {

public:
  TclDbfCmd(Tcl_Interp * interp, const char * name): TclCmd(interp, name) {};

private:
  int dbfcounter = 0;
  virtual int Command(int objc, Tcl_Obj * const objv[]);
};

#endif