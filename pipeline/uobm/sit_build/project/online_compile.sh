#!/bin/ksh
################################################################
# PLCE online compile/build script for jenkins
# Author: Vipul Kuruppu
# Created on: 11-04-2018
################################################################

# set environemnt
mepath=`dirname $0`
. ${mepath}/setBuildEnv.sh

# get input parameters
for in_parm_ in $*
do
	case $(get_key ${in_parm_}) in
		"country" 		) country=$(get_key_value ${in_parm_} "country");;
		"module" 		) module=$(get_key_value ${in_parm_} "module");;
		* 				) error_abort 1 "$(date) - ERROR [${country}] [${module}] : Unable to start compilation . Invalid parameter given";;
	esac
done

echo 
echo "------------------------------------------------------------------------------------------------" 
echo "$(date) - INFO [${country}] [${module}]: Compile / Buid started"
echo "------------------------------------------------------------------------------------------------" 

# set required variables
if [ -f ${jenkins_workspace}/tmp/${country}.release ]; then
	export rel_dtstamp=$(cat ${jenkins_workspace}/tmp/${country}.release)
else
	export rel_dtstamp=$(date +%Y%m%d.%H%M)
	echo ${rel_dtstamp} > ${jenkins_workspace}/tmp/${country}.release
fi

export release=CLS${country}_${module}_${rel_dtstamp}
export ALDON_DIST=${ald_devenv_root}/${country}/${module}/new_src
export svn_code_base=${svn_code_home}/${country}
export working_dir=${svn_code_base}/$(echo ${module} | tr [:upper:] [:lower:])
export build_dist=${working_dir}/build

# clean previously built package
if [ -d ${ALDON_DIST} ]; then echo "Removing ${ALDON_DIST}"; rm -rf ${ALDON_DIST}; fi
if [ -d ${build_dist} ]; then echo "Removing ${build_dist}"; rm -rf ${build_dist}; fi

echo BUILD PATH=${working_dir} 
echo RELEASE=${release} 
echo Working Directory ${working_dir}

# setup code for build
cd ${svn_code_base}
cp *.properties ${working_dir}/
cp *.xml ${working_dir}/
cp *.list ${working_dir}/
if [ -d ${working_dir}/deploy ]; then rm -rf ${working_dir}/deploy; fi
if [ -d ${working_dir}/luntbuild ]; then rm -rf ${working_dir}/luntbuild; fi

# compile souce and buils package
cd ${working_dir}
${ANT_HOME}/bin/ant -Dweblogic.base=${WL_BASE} -Dbuild.version=${release} -Dald.build.dir=${working_dir} -Daldon.dist=${ALDON_DIST} -buildfile onlinebuild.xml prepare-binaries
retcode=$?
if [ ${retcode} -ne 0 ];then
	echo "------------------------------------------------------------------------------------------------"
	echo "$(date) - ERROR [${country}] [${module}]: Compile / Buid failed"
	echo "------------------------------------------------------------------------------------------------"
	exit ${retcode}
fi

# prepare environment specific files
for dist_env in `egrep -v "^$|^#" environment.list`
do
	echo "Preparing files for -- ${dist_env}"
	echo "Config dir for ${dist_env} --- ${ALDON_DIST}/config/${dist_env}"
	cd ${working_dir}
	${ANT_HOME}/bin/ant -Dweblogic.base=${WL_BASE} -Dccm.uat.env=${dist_env} -Daldon.dist=${ALDON_DIST} -Dccm.uat.dir=${ALDON_DIST}/config/${dist_env} -buildfile onlinebuild.xml prepare-config
	retcode=$?
	if [ ${retcode} -ne 0 ];then
		echo "------------------------------------------------------------------------------------------------"
		echo "$(date) - ERROR [${country}] [${module}]: Compile / Buid failed"
		echo "------------------------------------------------------------------------------------------------"
		exit ${retcode}
	fi
done

# check file counts in config folder to confirm all config files were created
curr_count=0
prev_count=
for dist_env in `egrep -v "^$|^#" environment.list`
do
	curr_count=`find ${ALDON_DIST}/config/${dist_env} -type f | wc -l`
	echo "Folder/file count in ${ALDON_DIST}/config/${dist_env} -- "${curr_count}
	if [ prev_count="" ]; then
		prev_count=${curr_count}
		prev_env=${dist_env}
	elif [ ${prev_count} -ne ${curr_count} ]; then
		echo "Config file count in ${prev_env} is not as ${dist_env}"
		exit 1
	else
		prev_count=${curr_count}
		prev_env=${dist_env}
	fi
done
echo
# remove env specific files from common package
echo "Env dependent file list ------- ";echo
find ${ALDON_DIST}/config/pdn -type f | awk -F"/pdn/" {'print $2'}
echo

echo "Now removing env specific files from the common package"
for env_file in `find ${ALDON_DIST}/config/pdn -type f | awk -F"/pdn/" {'print $2'}`
do
	if [ -f ${ALDON_DIST}/online/${env_file} ]; then
		echo "Removing env file -- ${ALDON_DIST}/online/${env_file}"
		rm -f ${ALDON_DIST}/online/${env_file}
		retcode=$?
		if [ ${retcode} -ne 0 ];then
			echo "------------------------------------------------------------------------------------------------"
			echo "$(date) - ERROR [${country}] [${module}]: Compile / Buid failed"
			echo "------------------------------------------------------------------------------------------------"
			exit ${retcode}
		fi
	fi
done

echo "------------------------------------------------------------------------------------------------"
echo "$(date) - INFO [${country}] [${module}]: Compile / Buid successful"
echo " Release - ${release}"
echo "------------------------------------------------------------------------------------------------"

return ${retcode}

