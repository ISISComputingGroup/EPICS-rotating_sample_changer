program rotsc ("P")
 
option +r;
option +d;

#include "seqPVmacros.h"
%% #include "stdlib.h"
%% #include "errlog.h"

PV(unsigned int, last_setpoint, "{P}LAST_POSN:SP", Monitor);
PV(unsigned int, setpoint, "{P}POSN:SP", Monitor);
PV(unsigned int, setpoint_alarm, "{P}POSN:SP.SEVR", Monitor);
PV(unsigned int, setpoint_raw, "{P}POSN:SP:RAW", Monitor);
PV(unsigned int, actual_position, "{P}POSN", Monitor);

PV(unsigned int, initialized, "{P}IS_INITIALISED", Monitor);
PV(unsigned int, reinitialize, "{P}INIT", NoMon);

PV(unsigned int, motor0_active, "{P}MOTOR_0_ACTIVE", Monitor);
PV(unsigned int, motor1_active, "{P}MOTOR_1_ACTIVE", Monitor);

PV(unsigned int, move_complete, "{P}CALC_MOVE_FINISHED", Monitor);
PV(unsigned int, not_moving, "{P}CALC_NOT_MOVING", Monitor);

PV(string, error, "{P}ERR_STRING.SVAL", Monitor);
PV(unsigned int, error_number, "{P}ERR_NUMBER", Monitor);

PV(double, max_motion_begin_delay, "{P}SEQ:MAX_MOTION_BEGIN_DELAY", Monitor);
PV(double, max_motion_time, "{P}SEQ:MAX_MOTION_TIME", Monitor);
PV(unsigned int, maximum_drop_retries, "{P}SEQ:MAX_RETRY", Monitor);

PV(unsigned int, sample_arm_down, "{P}SAMPLE_ARM_DOWN", Monitor);
PV(unsigned int, sample_arm_up, "{P}SAMPLE_ARM_UP", Monitor);

PV(unsigned int, retrieve_sample, "{P}RETRIEVE_DROPPED", NoMon);
PV(unsigned int, raise_arm, "{P}RAISE_ARM", Monitor);

int sample_dropped_retries = 0;

%% char* PROGRAM_NAME = "ROTSC Sequencer";


ss rotsc
{
  state uninitialized
  { 
    /* Every max_motion_time seconds, if the sample changer is not initialized, send the reinitialize command 
       re-initialize is essentially just a home - moves to position 1 and then arm goes down */
    when(delay(max_motion_time)) 
    {
      errlogSevPrintf(errlogMajor, "%s: Sample changer is not initialized. Reinitializing...\n", PROGRAM_NAME);
      PVPUT(reinitialize, 1);
    } state uninitialized
  
    when (initialized)
    {
      errlogSevPrintf(errlogInfo, "%s: Sample changer initialized correctly.\n", PROGRAM_NAME);
    } state idle
  }

  state idle
  {
    /* Normal case where setpoint changes. Dont send a move request if actual_position < 0 as this means the sample changer is uninitialized (probably
       power cycled under us). In this case, trust that it is still in the correct position, until the setpoint changes again */
    when(setpoint != actual_position && actual_position >= 0 && setpoint_alarm == 0) 
    {
      errlogSevPrintf(errlogInfo, "%s: Starting move from actual_position = %d to target = %d.\n", PROGRAM_NAME, actual_position, setpoint);
      if (setpoint_raw == -1) {
        PVPUT(last_setpoint, 1);
      } else {
        PVPUT(last_setpoint, setpoint_raw);
      }
      PVPUT(setpoint_raw, setpoint);
    } state wait_for_motion_to_begin
    
    /* Catch case where sample changer power cycles underneath us. Wait for setpoint to change (setpoint != setpoint_raw) and then re-initialize. */
    when(actual_position == -1 && setpoint != setpoint_raw) {
      errlogSevPrintf(errlogMajor, "%s: Move requested but sample changer wasn't initialised. Re-initializing first before move.\n", PROGRAM_NAME, actual_position, setpoint);
      PVPUT(reinitialize, 1);
    } state uninitialized
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
      errlogSevPrintf(errlogMajor, "%s: Move requested while sample changer not initialized. Will attempt to reinitialize.\n", PROGRAM_NAME, error);
      PVPUT(reinitialize, 1);
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
      sample_dropped_retries = 0;
    } state idle
  }
  
  state retrieve_dropped_sample
  {
    when(error_number == 0)
	{
	  PVPUTSTR(error, "Attempting to retrieve dropped");
      PVPUT(error_number, 7);
	} state retrieve_dropped_sample
	
    when(move_complete)
    {
      errlogSevPrintf(errlogInfo, "%s: Retrieving dropped sample.\n", PROGRAM_NAME);
      PVPUT(retrieve_sample, 1);
    } state wait_for_retrieved_sample
  }
  
  state wait_for_retrieved_sample
  {
    when(not_moving && !sample_arm_up && (setpoint_raw == actual_position))
    {
      errlogSevPrintf(errlogInfo, "%s: Sample retrieved, retrying move to %d.\n", PROGRAM_NAME, setpoint);
      PVPUT(setpoint_raw, setpoint);
      sample_dropped_retries++;
    } state wait_for_motion_to_begin
    
    when(sample_dropped_retries == maximum_drop_retries)
    {
      errlogSevPrintf(errlogInfo, "%s: Sample could not be retrieved after %d retries.\n", PROGRAM_NAME, maximum_drop_retries);
      PVPUTSTR(error, "Dropped sample could not be retrieved");	  
      PVPUT(setpoint, actual_position);
    } state idle
  }
  
}
