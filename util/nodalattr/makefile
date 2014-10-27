#--------------------------------------------------------------------------
# makefile
#
# A system to build ASGS-related utilities for processing ADCIRC output.
#
#--------------------------------------------------------------------------
# Copyright(C) 2014 Jason Fleming
#
# This file is part of the ADCIRC Surge Guidance System (ASGS).
#
# The ASGS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ASGS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with the ASGS.  If not, see <http://www.gnu.org/licenses/>.
#--------------------------------------------------------------------------
#
# specify compiler=gfortran on the make command line
ifeq ($(compiler),gfortran)
   FC := gfortran
   FFLAGS := -cpp -ffree-line-length-none
   ifeq ($(DEBUG),full)
      FFLAGS := -cpp -ffree-line-length-none -g -O0 -fbacktrace -fbounds-check -ffpe-trap=zero,invalid,underflow,overflow,denormal #-Wall
   endif
endif
#
OUTPUTDIR := ../../output
INCLUDES := -I. -I$(OUTPUTDIR)
#
# if netcdf libraries are available on the target platform, 
# use NETCDF=enable on the make command line
ifeq ($(NETCDF),enable)
   FFLAGS      := $(FFLAGS) -DASGSNETCDF
   NETCDFPATH  := /usr
   INCLUDES    := -I. -I$(NETCDFPATH)/include
   LIBS        := -L$(NETCDFPATH)/lib
   LDFLAGS     := -lnetcdff
endif
ifeq ($(NETCDF4),enable)
   FFLAGS      := $(FFLAGS) -DHAVE_NETCDF4
endif
ifeq ($(NETCDF4_COMPRESSION),enable)
   FFLAGS      := $(FFLAGS) -DNETCDF_CAN_DEFLATE
endif
#
#
OBJ := $(OUTPUTDIR)/adcmesh.o $(OUTPUTDIR)/asgsio.o
MODS := $(OUTPUTDIR)/adcmesh.mod $(OUTPUTDIR)/asgsio.mod
#
# targets
all : tau0_gen
#
clean :
	rm -f *.o *.mod *.x
#
tau0_gen : $(MODS) tau0_gen.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@.x $@.f90 $(OBJ) $(LDFLAGS)
#
$(OUTPUTDIR)/adcmesh.mod : $(OUTPUTDIR)/adcmesh.f90 $(OUTPUTDIR)/asgsio.mod
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -c $(OUTPUTDIR)/adcmesh.f90 $(LDFLAGS)
#
$(OUTPUTDIR)/asgsio.mod : $(OUTPUTDIR)/asgsio.f90 
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -c $(OUTPUTDIR)/asgsio.f90 $(LDFLAGS)