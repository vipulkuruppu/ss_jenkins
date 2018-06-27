#!/bin/ksh
################################################################
# PLCE code tagging script for jenkins
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
echo "$(date) - INFO [${country}] [${module}]: Code tagging started"
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
export svn_artifacts_home=${svn_artifacts_home}
export svn_artifacts_tmp=${jenkins_workspace}/tmp/${country}/${module}

# create tmp folder
if [ -d ${svn_artifacts_tmp} ]; then
	rm -rf ${svn_artifacts_tmp}/*
else
	mkdir -p ${svn_artifacts_tmp}
fi

# prepare sources for zip
if [ "${module}" = "ONLINE" ]; then
	# prepare online
	cd ${working_dir}
	cp -pR com ${svn_artifacts_tmp}/
	cp -pR web ${svn_artifacts_tmp}/
	cp -pR config ${svn_artifacts_tmp}/
	cp -pR lib ${svn_artifacts_tmp}/
	cp -pR tlds ${svn_artifacts_tmp}/
	cp -pR mapping ${svn_artifacts_tmp}/
	
	mkdir -p  ${svn_artifacts_tmp}/deploy
	cd ${svn_code_base}
	cp -p build.xml ${svn_artifacts_tmp}/deploy/
	cp -p deploy.prod.properties ${svn_artifacts_tmp}/deploy/
	cp -p deploy.mr.properties ${svn_artifacts_tmp}/deploy/
	cp -p deploy.uat*.properties ${svn_artifacts_tmp}/deploy/
	
	# now archive sources and zip
	cd ${svn_artifacts_tmp}
	find . -type d -name ".svn" | xargs rm -rf > /dev/null
	tar -cvf ${svn_artifacts_home}/${module}.tar *
	gzip -9 ${svn_artifacts_home}/${module}.tar
	
elif [ "${module}" = "SCRIPTS" ]; then
	# prepare scripts
	mkdir -p ${svn_artifacts_tmp}/scripts
	cd ${working_dir}
	cp -pR * ${svn_artifacts_tmp}/scripts/
	
	mkdir -p  ${svn_artifacts_tmp}/deploy
	cd ${svn_code_base}
	cp -p deploy.prod.properties ${svn_artifacts_tmp}/deploy/
	cp -p deploy.mr.properties ${svn_artifacts_tmp}/deploy/
	cp -p deploy.uat*.properties ${svn_artifacts_tmp}/deploy/

	# now archive sources and zip
	cd ${svn_artifacts_tmp}
	find . -type d -name ".svn" | xargs rm -rf > /dev/null
	tar -cvf ${svn_artifacts_home}/${module}.tar *
	gzip -9 ${svn_artifacts_home}/${module}.tar
	
elif [ "${module}" = "CDSCRIPTS" ]; then

	# prepare cdscripts
	mkdir -p ${svn_artifacts_tmp}/cdscripts
	cd ${working_dir}
	cp -pR * ${svn_artifacts_tmp}/cdscripts/
	
	mkdir -p  ${svn_artifacts_tmp}/deploy
	cd ${svn_code_base}
	cp -p deploy.prod.properties ${svn_artifacts_tmp}/deploy/
	cp -p deploy.mr.properties ${svn_artifacts_tmp}/deploy/
	cp -p deploy.uat*.properties ${svn_artifacts_tmp}/deploy/

	# now archive sources and zip
	cd ${svn_artifacts_tmp}
	find . -type d -name ".svn" | xargs rm -rf > /dev/null
	find . -type d -name "luntbuild" | xargs rm -rf > /dev/null
	cd ${svn_artifacts_tmp}\cdscripts
	find . -type d -name "deploy" | xargs rm -rf > /dev/null
	cd ${svn_artifacts_tmp}
	tar -cvf ${svn_artifacts_home}/${module}.tar *
	gzip -9 ${svn_artifacts_home}/${module}.tar

else
	# nothing to prepare
	echo "No codes to prepare"
fi

echo "------------------------------------------------------------------------------------------------"
echo "$(date) - INFO [${country}] [${module}]: Code tagging completed"
echo "------------------------------------------------------------------------------------------------"

return ${retcode}

