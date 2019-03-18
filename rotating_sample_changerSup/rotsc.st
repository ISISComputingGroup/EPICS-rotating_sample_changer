program rotsc ("P")
 
option +r;
option +d;

#include "seqPVmacros.h"
%% #include "stdlib.h"
%% #include "errlog.h"

ss rotsc
{
  state idle
  {
    when(1) 
	{
      puts("Exit idle state");
	} state wait
  }
  
  state wait
  {
    when(0)
	{
	  puts("Exit wait state");
	} state idle
  }
}
