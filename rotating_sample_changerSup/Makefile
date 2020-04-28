TOP=..
include $(TOP)/configure/CONFIG
#=======================================

# Install .dbd and .db files
DB += rotating_sample_changer.db
DB += error_calculator.db
DB += HRPD_specific.db

DATA += rotsc_0.proto
DATA += rotsc_1.proto

DBD += rotsc.dbd

# Create shared library

LIBRARY_IOC = rotsc

rotsc_LIBS += seq pv
rotsc_LIBS += $(EPICS_BASE_IOC_LIBS)

rotsc_SRCS += rotsc.st


#=======================================
include $(TOP)/configure/RULES
