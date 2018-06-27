#!/bin/ksh
################################################################
# PLCE cdscripts compile/build script for jenkins
# Author: Vipul Kuruppu
# Created on: 11-04-2018
################################################################

# Set environemnt
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
export svn_script_src_dir=${svn_code_base}/$(echo ${module} | tr [:upper:] [:lower:])
export working_dir=${svn_code_base}/$(echo ${module} | tr [:upper:] [:lower:])_build_dir
export build_dist=${working_dir}/build

src_dir=${working_dir}/src
build_src=${working_dir}/build/src

# clean previously built package
if [ -d ${ALDON_DIST} ]; then echo "Removing ${ALDON_DIST}"; rm -rf ${ALDON_DIST}; fi
if [ -d ${build_src} ]; then echo "Removing ${build_src}"; rm -rf ${build_src}; fi
if [ -d ${build_dist} ]; then echo "Removing ${build_dist}"; rm -rf ${build_dist}; fi

echo BUILD PATH=${working_dir} 
echo RELEASE=${release} 
echo Working Directory ${working_dir}

# setup code for build
if [ -d ${working_dir} ]; then 
	rm -rf ${working_dir}/*
	mkdir -p ${src_dir}
else
	mkdir -p ${src_dir}
fi
# copy sources
cd ${svn_script_src_dir}
cp -pR * ${src_dir}/
# copy properties and other required files
cd ${svn_code_base}
cp *.properties ${working_dir}/
cp *.xml ${working_dir}/
cp *.list ${working_dir}/
if [ -d ${src_dir}/deploy ]; then rm -rf ${src_dir}/deploy; fi
if [ -d ${src_dir}/luntbuild ]; then rm -rf ${src_dir}/luntbuild; fi

# strip ^M
cd ${src_dir}
for _file in $(find . -type f)
do
	/app/dos2unix/dos2unix ${_file}
done

# separate common scripts and env specific in to two folders
mkdir -p ${ALDON_DIST}/scripts
mkdir -p ${build_src}

cd ${src_dir}
for _script in `find . -type f`
do
	if [ -n "`grep \"@[A-Za-z0-9\. ]*@\" ${_script}`" ]; then
		if [ ! -d ${build_src}/`dirname ${_script}` ]; then
			mkdir -p ${build_src}/`dirname ${_script}`
		fi
		cp ${_script}  ${build_src}/${_script}
	else
		if [ ! -d ${ALDON_DIST}/scripts/`dirname ${_script}` ]; then
			mkdir -p ${ALDON_DIST}/scripts/`dirname ${_script}`
		fi
		cp ${_script}  ${ALDON_DIST}/scripts/${_script}
	fi
done

# prepare environment specific files for all sit/uat & pdn
cd ${working_dir}
for dist_env in `egrep -v "^$|^#" environment.list`
do
	echo "Preparing files for -- ${dist_env}"
	echo "Config dir for ${dist_env} --- ${ALDON_DIST}/config/${dist_env}"
	${ANT_HOME}/bin/ant -Dccm.uat.env=${dist_env} -Dccm.uat.dir=${ALDON_DIST}/config/${dist_env} -Daldon.dist=${ALDON_DIST} -buildfile binscriptsbuild.xml prepare-envscripts
done
retcode=$?
if [ ${retcode} -ne 0 ];then
	echo "------------------------------------------------------------------------------------------------"
	echo "$(date) - ERROR [${country}] [${module}]: Compile / Buid failed"
	echo "------------------------------------------------------------------------------------------------"
	exit ${retcode}
fi

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

echo "Env dependent script list ------- ";echo
find ${ALDON_DIST}/config/pdn -type f | awk -F"/pdn/" {'print $2'}
echo

# update for SIT
#if [ ${ENVIRON} = ${SITSERVER} ]; then
#	cd ${ALDON_DIST}/bin
#	sed "s/\$mepath\/runSLsql/\$mepath\/runsql/g" execsql.sh > execsql.sh.new
#	mv execsql.sh.new execsql.sh
#	chmod 754 execsql.sh
#fi

echo "------------------------------------------------------------------------------------------------"
echo "$(date) - INFO [${country}] [${module}]: Compile / Buid successful"
echo " Release - ${release}"
echo "------------------------------------------------------------------------------------------------"

return $?
