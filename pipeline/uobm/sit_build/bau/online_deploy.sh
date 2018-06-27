#!/bin/ksh
################################################################
# PLCE online deploy script for jenkins
# Author: Vipul Kuruppu
# Created on: 09-05-2018
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
		"deploy_env"	) deploy_env=$(get_key_value ${in_parm_} "deploy_env");;
		* 				) error_abort 1 "$(date) - ERROR [${country}] [${module}] : Unable to start compilation . Invalid parameter given";;
	esac
done

echo 
echo "------------------------------------------------------------------------------------------------" 
echo "$(date) - INFO [${country}] [${module}]: Deployment Script started"
echo "------------------------------------------------------------------------------------------------" 

# set required variables
if [ -f ${jenkins_workspace}/tmp/${country}.release ]; then
	export rel_dtstamp=$(cat ${jenkins_workspace}/tmp/${country}.release)
else
	echo "------------------------------------------------------------------------------------------------"
	echo "$(date) - ERROR [${country}] [${module}]: Deployment aborted. "
	echo "No release can be found in ${jenkins_workspace}/tmp/${country}.release "
	echo "------------------------------------------------------------------------------------------------"
	exit 1
fi

export release=CLS${country}_${module}_${rel_dtstamp}
export ALDON_DIST=${ald_devenv_root}/${country}/${module}/new_src

case ${deploy_env} in
	"sit"	) deploy_path=/app/CLSMY/MY;
			  deploy_domain_path=/app/CLSMY/domains/MY;
			  deploy_env_label="SIT-BAU";;
	"sit2"	) deploy_path=/app/CLSMY/MY2;
			  deploy_domain_path=/app/CLSMY/domains/MY2;
			  deploy_env_label="SIT2-Project";;
	"sit5"	) deploy_path=/app/CLSMY/MY5;
			  deploy_domain_path=/app/CLSMY/domains/MY5;
			  deploy_env_label="SIT5-QR";;
esac

# tar dist
echo "------------------------------------------------------------------------------------------------" 
echo "$(date) - INFO [${country}] [${module}]: Tarring dist started"
echo "------------------------------------------------------------------------------------------------" 
cd ${ALDON_DIST}
for dotsvn_dir in $(find . -type d -name ".svn")
do
	rm -rf ${dotsvn_dir}
done

tar -cvf ${tmp_dir}/${release}.tar *
if [ $? -ne 0 ];then
	echo "------------------------------------------------------------------------------------------------"
	echo "$(date) - ERROR [${country}] [${module}]: Tarring Dist failed"
	echo "------------------------------------------------------------------------------------------------"
	exit ${retcode}
fi

retcode=0

# run housekeep in SIT box
echo "------------------------------------------------------------------------------------------------" 
echo "$(date) - INFO [${country}] [${module}]: ${APP_SERVER} /TCM housekeep started"
echo "------------------------------------------------------------------------------------------------" 
ssh ${deployid}@${APP_SERVER} << _EOC
/TCM/swdis/TCM_housekeep.sh
_EOC
((retcode=${retcode}+$?))
if [ ${retcode} -ne 0 ];then
	echo "------------------------------------------------------------------------------------------------"
	echo "$(date) - ERROR [${country}] [${module}]: ${APP_SERVER} /TCM housekeep failed"
	echo "------------------------------------------------------------------------------------------------"
	exit ${retcode}
fi

# upload tar to /TCM
echo "------------------------------------------------------------------------------------------------"
echo "$(date) - INFO [${country}] [${module}]: Uploading ${release}.tar started"
echo "------------------------------------------------------------------------------------------------"
cd ${tmp_dir}
sftp ${deployid}@${APP_SERVER} << _EOC
cd /TCM/UAT_svr
mkdir ${release}
cd ${release}
lpwd 
put ${release}.tar
_EOC
((retcode=${retcode}+$?))
if [ ${retcode} -ne 0 ];then
	echo "------------------------------------------------------------------------------------------------"
	echo "$(date) - ERROR [${country}] [${module}]: Uploading ${release}.tar failed"
	echo "------------------------------------------------------------------------------------------------"
	exit ${retcode}
fi

# deploy files from /TCM
echo "------------------------------------------------------------------------------------------------"
echo "$(date) - INFO [${country}] [${module}]: Deploying files to environemnt started"
echo "------------------------------------------------------------------------------------------------"
ssh ${deployid}@${APP_SERVER} << _EOC
mkdir -p /TCM/UAT_svr/${release}/deploy
cd /TCM/UAT_svr/${release}/deploy
tar -xvf ../${release}.tar
echo "Deploying files from /TCM/UAT_svr/${release}/deploy to ${deploy_path}"
cd /TCM/UAT_svr/${release}/deploy/online
cp -pR * ${deploy_path}
cd /TCM/UAT_svr/${release}/deploy/config/${deploy_env}
cp -pR * ${deploy_path}
cd ${deploy_path}
chmod -R 754 *
_EOC
((retcode=${retcode}+$?))

if [ ${retcode} -ne 0 ];then
	echo "------------------------------------------------------------------------------------------------"
	echo "$(date) - ERROR [${country}] [${module}]: Deploying files to environemnt failed"
	echo "------------------------------------------------------------------------------------------------"
	exit ${retcode}
fi

# restarting app
cd ${mepath}
${ANT_HOME}/bin/ant -Ddomain.dir=${deploy_domain_path} -buildfile appl_maint.xml restart-env
((retcode=${retcode}+$?))
if [ ${retcode} -ne 0 ];then
	echo "------------------------------------------------------------------------------------------------"
	echo "$(date) - ERROR [${country}] [${module}]: Restart application failed"
	echo "------------------------------------------------------------------------------------------------"
	exit ${retcode}
fi


email_subject="PLCE CLS${country} ${deploy_env_label} ${module} Deployment Completed"

# emails - sgcreditoriginationtestsupport@sg.uob sgalertpowerlender@sg.uob
mailx -s "${email_subject}" unckur@uobgroup.com tmpmoa@sg.uob tmp3h9@sg.uob << _eom
	
PLCE CLS${country} ${deploy_env_label} ${module} Deployment Completed

Release - ${release}

_eom

echo "------------------------------------------------------------------------------------------------"
echo "$(date) - INFO [${country}] [${module}]: Deployment script completed"
echo " Release - ${release}"
echo "------------------------------------------------------------------------------------------------"

return ${retcode}

