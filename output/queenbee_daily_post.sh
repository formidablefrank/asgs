#!/bin/bash
#------------------------------------------------------------------------
# queenbee_daily_post.sh : Posting to opendap from queenbee. 
#------------------------------------------------------------------------
# Copyright(C) 2015--2017 Jason Fleming
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
#------------------------------------------------------------------------
# Example of invocation:
# ~/asgs/trunk/output/queenbee_daily_post.sh ~/asgs/config/asgs_config_phil_garnet_hsdrrs2014.sh /lustre/work1/jgflemin/asgs19368/38 99 2008 38 garnet.erdc.hpc.mil nhcConsensus 2008080800  2743200.000000000 HSDRRS2014_MRGO_leveeupdate_fixSTC_MX.grd  ~/asgs/trunk/output /u/jgflemin/asgs/log/asgs-2014-Apr-23-T05:33:41.19368.log ~/.ssh/id_rsa.pub
#
CONFIG=$1
ADVISDIR=$2
STORM=$3
YEAR=$4
ADVISORY=$5
HOSTNAME=$6
ENSTORM=$7
CSDATE=$8
HSTIME=$9
GRIDFILE=${10}
OUTPUTDIR=${11}
SYSLOG=${12}
SSHKEY=${13}
#
STORMDIR=${ADVISDIR}/${ENSTORM}       # shorthand
cd ${STORMDIR}
THIS=queenbee_daily_post.sh
# get the forecast ensemble member number for use in CERA load balancing
# as well as picking up any bespoke configuration for this ensemble
# member in the configuration files
ENMEMNUM=`grep "forecastEnsembleMemberNumber" ${STORMDIR}/run.properties | sed 's/forecastEnsembleMemberNumber.*://' | sed 's/^\s//'` 2>> ${SYSLOG}
si=$ENMEMNUM
#
# grab all config info
. ${CONFIG} 
# Bring in logging functions
. ${SCRIPTDIR}/logging.sh
# Bring in platform-specific configuration
. ${SCRIPTDIR}/platforms.sh
# dispatch environment (using the functions in platforms.sh)
env_dispatch ${TARGET}
# grab all config info (again, last, so the CONFIG file takes precedence)
. ${CONFIG}
#
# write the intended audience to the run.properties file for CERA
echo "intendedAudience : $INTENDEDAUDIENCE" >> run.properties
echo "enstorm : $ENSTORM" >> run.properties 2>> $SYSLOG
#
#--------------------------------------------------------------------------
#              I N U N D A T I O N    M  A S K  
#--------------------------------------------------------------------------
# When presenting inundation data on Google Maps, the ADCIRC extent of
# initially dry area is often landward of the Google Maps shoreline, 
# resulting in the erroneous depiction of non-inundated land areas 
# seaward of inundated areas. The inundationMask program expands the 
# inundation area presented on Google Maps to cover the full land area
# as depicted by Google Maps. 
# 
if [ -e ${STORMDIR}/initiallydry.63.nc ]; then
   if [ -e ${OUTPUTDIR}/inundationMask.x ]; then
      ${OUTPUTDIR}/inundationMask.x --filename initiallydry.63.nc --netcdf4 --numpasses 2 2>> ${SYSLOG} 2>&1
      ERROVALUE=$?
      if [ $ERROVALUE == 0 ]; then
         echo "Inundation Mask File Name : inundationmask.63.nc" >> run.properties
         echo "Inundation Mask Format : netcdf" >> run.properties
      else
         error "$ENSTORM: $THIS: Failed to create inundationmask.63.nc file."
      fi
   else
      error "$ENSTORM: $THIS: The initiallydry.63.nc file was found in $STORMDIR but the inundationMask.x executable was not found in ${OUTPUTDIR}."
   fi
fi

#
#-----------------------------------------------------------------------
#          I N C L U S I O N   O F   10 M   W I N D S
#-----------------------------------------------------------------------
# If winds at 10m (i.e., wind velocities that do not include the effect
# of land interaction from nodal attributes line directional wind roughness
# and canopy coefficient) were produced by another ensemble member, 
# then include these winds in the post processing
wind10mFound=no
wind10mContoursFinished=no
dirWind10m=$ADVISDIR/${ENSTORM}Wind10m
if [[ -d $dirWind10m ]]; then
   logMessage "$ENSTORM: $THIS: Corresponding 10m wind ensemble member was found."
   wind10mFound=yes
   for file in fort.72.nc fort.74.nc maxwvel.63.nc ; do
      if [[ -e $dirWind10m/$file ]]; then
         logMessage "Found $dirWind10m/${file}."
         ln -s $dirWind10m/${file} ./wind10m.${file}
         # update the run.properties file
         case $file in
         "fort.72.nc")
            echo "Wind Velocity 10m Stations File Name : wind10m.fort.72.nc" >> run.properties
            echo "Wind Velocity 10m Stations Format : netcdf" >> run.properties
            ;;
         "fort.74.nc")
            echo "Wind Velocity 10m File Name : wind10m.fort.74.nc" >> run.properties
            echo "Wind Velocity 10m Format : netcdf" >> run.properties
            ;;
       "maxwvel.63.nc")
            echo "Maximum Wind Speed 10m File Name : wind10m.maxwvel.63.nc" >> run.properties
            echo "Maximum Wind Speed 10m Format : netcdf" >> run.properties
            ;;
         *)
            warn "$ENSTORM: $THIS: The file $file was not recognized."
         ;;
         esac
      else
         logMessage "$ENSTORM: $THIS: The file $dirWind10m/${file} was not found."
      fi
   done
else
   logMessage "$ENSTORM: $THIS: Corresponding 10m wind ensemble member was not found."
fi
#------------------------------------------------------------------------
# accumulate min/max
#previousAdvisory=`expr $ADVISORY - 1`
#for file in maxele.63.nc maxinundepth.63.nc maxrs.63.nc maxvel.63.nc maxwvel.63.nc swan_HS_max.63.nc swan_TPS_max.63.nc ; do
#   if [[ -e $file ]]; then
#      ${OUTPUTDIR}/collectMinMax.x --source ../../$previousAdvisory/nowcast/$file --destination $file
#   fi
#done
#
#-------------------------------------------------------------------
#               C E R A   F I L E   P R I O R I T Y
#-------------------------------------------------------------------
# @jasonfleming: Hack in a notification email once the bare minimum files
# needed by CERA have been posted. 
logMessage "Creating list of files to post to opendap."
if [[ -e ../al${STORM}${YEAR}.fst ]]; then
   cp ../al${STORM}${YEAR}.fst . 2>> $SYSLOG
fi
if [[ -e ../bal${STORM}${YEAR}.dat ]]; then
   cp ../bal${STORM}${YEAR}.dat . 2>> $SYSLOG
fi
#FILES=(`ls *.nc al${STORM}${YEAR}.fst bal${STORM}${YEAR}.dat fort.15 fort.22 CERA.tar run.properties 2>> /dev/null`)
ceraNonPriorityFiles=( `ls endrisinginun.63.nc everdried.63.nc fort.64.nc fort.68.nc fort.71.nc fort.72.nc fort.73.nc initiallydry.63.nc inundationtime.63.nc maxinundepth.63.nc maxrs.63.nc maxvel.63.nc minpr.63.nc rads.64.nc swan_DIR.63.nc swan_DIR_max.63.nc swan_TMM10.63.nc swan_TMM10_max.63.nc` )
ceraPriorityFiles=(`ls run.properties maxele.63.nc fort.63.nc fort.61.nc fort.15 fort.22`)
if [[ $ceraContoursAvailable = yes ]]; then
   ceraPriorityFiles=( ${ceraPriorityFiles[*]} "CERA.tar" )
fi
if [[ $TROPICALCYCLONE = on ]]; then
   ceraPriorityFiles=( ${ceraPriorityFiles[*]} `ls al${STORM}${YEAR}.fst bal${STORM}${YEAR}.dat` )
fi
if [[ $WAVES = on ]]; then
   ceraPriorityFiles=( ${ceraPriorityFiles[*]} `ls swan_HS_max.63.nc swan_TPS_max.63.nc swan_HS.63.nc swan_TPS.63.nc` )
fi
dirWind10m=$ADVISDIR/${ENSTORM}Wind10m
if [[ -d $dirWind10m ]]; then
   ceraPriorityFiles=( ${ceraPriorityFiles[*]} `ls wind10m.maxwvel.63.nc wind10m.fort.74.nc` )
   ceraNonPriorityFiles=( ${ceraNonPriorityFiles[*]} `ls maxwvel.63.nc fort.74.nc` )
else
   ceraPriorityFiles=( ${ceraPriorityFiles[*]} `ls maxwvel.63.nc fort.74.nc` )
fi
FILES=( ${ceraPriorityFiles[*]} "sendNotification" ${ceraNonPriorityFiles[*]} )
#
#-----------------------------------------------------------------------
#         O P E N  D A P    P U B L I C A T I O N 
#-----------------------------------------------------------------------
#
# For each opendap server in the list in ASGS config file.
primaryCount=0
for server in ${TDS[*]}; do 
   logMessage "$ENSTORM: $THIS: Posting to $server opendap using the following command: ${OUTPUTDIR}/opendap_post.sh $CONFIG $ADVISDIR $ADVISORY $HOSTNAME $ENSTORM $HSTIME $SYSLOG $server \"${FILES[*]}\" $OPENDAPNOTIFY"
   ${OUTPUTDIR}/opendap_post.sh $CONFIG $ADVISDIR $ADVISORY $HOSTNAME $ENSTORM $HSTIME $SYSLOG $server "${FILES[*]}" $OPENDAPNOTIFY >> ${SYSLOG} 2>&1
   # add downloadurl_backup propert(ies) to the properties file that 
   # refer to previously posted results
   backupCount=0
   for backup in ${TDS[*]}; do
      # don't list the same server as primary and backup and don't list
      # a server as a backup if nothing has been posted there yet
      if [[ $backupCount -ge $primaryCount ]]; then
         break
      fi
      # opendap_post.sh writes each primary download URL to the file
      # downloadurl.txt as it posts the results. Use these to populate
      # the downloadurl_backupX properties.
      # add +1 b/c the 0th backup url is on 1st line of the file
      backupURL=`sed -n $(($backupCount+1))p downloadurl.log`
      OPENDAPDIR=`sed -n $(($backupCount+1))p opendapdir.log`
      propertyName="downloadurl_backup"$(($backupServer+1))
      # need to grab the SSHPORT from the configuration
      env_dispatch $backup
      # Establish the method of posting results for service via opendap
      OPENDAPPOSTMETHOD=scp
      for hpc in ${COPYABLEHOSTS[*]}; do
         if [[ $hpc = $TARGET ]]; then
            OPENDAPPOSTMETHOD=copy
         fi
      done
      for hpc in ${LINKABLEHOSTS[*]}; do
         if [[ $hpc = $TARGET ]]; then
            OPENDAPPOSTMETHOD=link
         fi
      done
      case $OPENDAPPOSTMETHOD in
      "scp")
         if [[ $SSHPORT != "null" ]]; then
            ssh $OPENDAPHOST -l $OPENDAPUSER -p $SSHPORT "echo $propertyName : $backupURL >> $OPENDAPDIR/run.properties"
         else
            ssh $OPENDAPHOST -l $OPENDAPUSER "echo $propertyName : $backupURL >> $OPENDAPDIR/run.properties"
        fi
        ;;
      "copy"|"link")
         echo $propertyName : $backupURL >> $OPENDAPDIR/run.properties 2>> $SYSLOG
         ;;
      *)
         warn "$ENSTORM: $THIS: OPeNDAP post method unrecogrnized."
         ;;
      esac
      backupCount=$(($backupCount+1))
   done
   primaryCount=$((primaryCount+1))
done
