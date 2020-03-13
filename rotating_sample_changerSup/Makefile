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

LIBRARY_IOC = ROTSC

ROTSC_LIBS += seq pv
ROTSC_LIBS += $(EPICS_BASE_IOC_LIBS)

ROTSC_SRCS += rotsc.st


#=======================================
include $(TOP)/configure/RULES
