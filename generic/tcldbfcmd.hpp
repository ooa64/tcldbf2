#ifndef TCLDBFCMD_H
#define TCLDBFCMD_H

#include <tcl.h>
#include "tclcmd.hpp"

class TclDbfCmd : public TclCmd {
public:
  TclDbfCmd(Tcl_Interp * interp, const char * name): TclCmd(interp, name) {};
private:    
  virtual int Command(int objc, Tcl_Obj * const objv[]);
  virtual void Cleanup();
};

#endif