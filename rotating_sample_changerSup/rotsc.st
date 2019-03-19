program rotsc ("P")
 
option +r;
option +d;

#include "seqPVmacros.h"
%% #include "stdlib.h"
%% #include "errlog.h"

PV(unsigned int, setpoint, "{P}POSN:SP", Monitor);
PV(unsigned int, setpoint_alarm, "{P}POSN:SP.SEVR", Monitor);
PV(unsigned int, setpoint_raw, "{P}POSN:SP:RAW", NoMon);
PV(unsigned int, actual_position, "{P}POSN", Monitor);

PV(unsigned int, initialized, "{P}IS_INITIALISED", Monitor);

PV(unsigned int, motor0_active, "{P}MOTOR_0_ACTIVE", Monitor);
PV(unsigned int, motor1_active, "{P}MOTOR_1_ACTIVE", Monitor);

PV(unsigned int, move_complete, "{P}CALC_MOVE_FINISHED", Monitor);

PV(string, error, "{P}ERR_STRING.SVAL", Monitor);

PV(double, max_motion_begin_delay, "{P}SEQ:MAX_MOTION_BEGIN_DELAY", Monitor);
PV(double, max_motion_time, "{P}SEQ:MAX_MOTION_TIME", Monitor);

PV(unsigned int, sample_arm_down, "{P}SAMPLE_ARM_DOWN", Monitor);

%% char* PROGRAM_NAME = "ROTSC Sequencer";


ss rotsc
{
  state uninitialized
  { 
    /* Every minute, print a log message that the sample changer is still not initialized */
    /* TODO: could we automatically initialize the changer here? What problems would that have? */
    when(delay(60)) 
    {
      errlogSevPrintf(errlogMajor, "%s: Sample changer is not initialized.\n", PROGRAM_NAME);
    } state uninitialized
  
    when (initialized)
    {
      errlogSevPrintf(errlogInfo, "%s: Sample changer initialized correctly.\n", PROGRAM_NAME);
    } state idle
  }

  state idle
  {
    when(setpoint != actual_position && setpoint_alarm == 0) 
	{
      errlogSevPrintf(errlogInfo, "%s: Starting move from actual_position = %d to target = %d.\n", PROGRAM_NAME, actual_position, setpoint);
      PVPUT(setpoint_raw, setpoint);
	} state wait_for_motion_to_begin
  }
  
  state wait_for_motion_to_begin
  {
    when(motor0_active || motor1_active)
    {
      errlogSevPrintf(errlogInfo, "%s: Motion started.\n", PROGRAM_NAME);
    } state wait_for_motion_complete
    
    when (move_complete && (setpoint == actual_position)) {
      errlogSevPrintf(errlogInfo, "%s: Motion appeared complete before motors started. The move may have been too fast for the IOC to notice.\n", PROGRAM_NAME);
    } state wait_for_motion_complete
    
    /* Check if the sample changer has become uninitialized, if so log an error and go back to uninitialized state */
    when (!initialized)
    {
      errlogSevPrintf(errlogMajor, "%s: Move requested while sample changer not initialized.\n", PROGRAM_NAME, error);
    } state uninitialized
    
    when(delay(max_motion_begin_delay))
    {
      errlogSevPrintf(errlogMajor, "%s: Waited for %f seconds, but move didn't appear to start. Continuing anyway. Last error from device was '%s'.\n", PROGRAM_NAME, max_motion_begin_delay, error);
    } state wait_for_motion_complete
  }
  
  state wait_for_motion_complete
  {
    when(move_complete) 
    {
      errlogSevPrintf(errlogInfo, "%s: Target position (%d) reached.\n", PROGRAM_NAME, setpoint_raw);
    } state idle
    
    when(delay(max_motion_time))
    {
      errlogSevPrintf(errlogMajor, 
                      "%s: Waited %f seconds but move never completed. Final position = %d, setpoint = %d, motor0_active = %d, motor1_active = %d, sample_arm_down = %d, finished = %d. Will retry move. Last error from device was '%s'.\n", 
                      PROGRAM_NAME, max_motion_time, actual_position, setpoint_raw, motor0_active, motor1_active, sample_arm_down, move_complete, error);
      
      /* Resend setpoint. Hopefully this time it works ok. */
      PVPUT(setpoint_raw, setpoint);
    } state wait_for_motion_to_begin
  }
}
