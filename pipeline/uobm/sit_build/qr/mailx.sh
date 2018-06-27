#!/bin/ksh
################################################################
# Post deployment email script for aldon base/delta release
# Author: Vipul Kuruppu
# Created on: 31-10-2016
################################################################

mepath=`dirname $0`
. ${mepath}/setBuildEnv.sh

# function to send notice email
send_Notice_msg()
{
# emai notice
#----------------------------------------------
MAIL_SUBJECT=$2
mailx -s "${MAIL_SUBJECT}" `cat ${mepath}/mail.list | grep -v ^# ` << _eom

`echo $3`

_eom
}

# function to send P code sync email
send_PCodeSync_msg()
{
# set parameters
src_dir=$2
status=$3
logfile=$4

if [ ${status} -ne 0 ];then 
	syncstat="failed"
else
	syncstat="successful"
fi
# emai status to infra team
#----------------------------------------------
MAIL_SUBJECT="CLR${CCODE} - P Code Sync to ${src_dir} ${syncstat}"
mailx -s "${MAIL_SUBJECT}" `cat ${mepath}/mail.list | grep -v ^# ` << _eom

CLR${CCODE} - P Code Sync to ${src_dir} ${syncstat}

Please check $(hostname) : ${logfile} for details

_eom
}

# function to send build sync email
send_EnvSync_msg()
{
# set parameters
rel_dtstamp=$(cat $2)
status=$3
envs="$4"
country=$5
release=CLS${country}_${rel_dtstamp}

if [ ${status} -ne 0 ];then 
	syncstat="failed"
else
	syncstat="successful"
fi

MAIL_SUBJECT="${release} - Sync ${deploy_env} build to ${envs} ${syncstat}"
mailx -s "${MAIL_SUBJECT}" `cat ${mepath}/mail.list | grep -v ^# ` << _eom
	
${release} - Sync ${deploy_env} build to ${envs} ${syncstat}

_eom
}

# function to send compile/import status email
send_CompileImport_msg()
{
# set parameters
rel_dtstamp=$(cat $1)
status=$2
stage=$3
logfile=$4
country=$5
deploy_env=$6
release=CLS${country}_${rel_dtstamp}

case ${deploy_env} in
	"sit"	) deploy_env_label="SIT-BAU";;
	"sit2"	) deploy_env_label="SIT2-Project";;
	"sit5"	) deploy_env_label="SIT5-QR";;
esac

# emai status 
deploystat="successful"
if [ ${status} -ne 0 ];then deploystat="failed"; fi
deploystage="Import"
if [ ${stage} -eq 1 ];then deploystage="Compile / Build"; fi
if [ ${stage} -eq 2 ];then deploystage="Non Import Deployment"; fi

MAIL_SUBJECT="PLCE ${country} ${deploy_env_label} - ${deploystage} ${deploystat}"
mailx -s "${MAIL_SUBJECT}" `cat ${mepath}/mail.list | grep -v ^# ` << _eom
	
Label - ${release}

${deploystage} Log:
----------------------------------------------------------------------------

`cat ${logfile}`

_eom
}

# main program
msg_type=$1
case ${msg_type} in
	"NOTICE"		) send_Notice_msg "$1" "$2" "$3";;
	"P_CODE_SYNC"	) send_PCodeSync_msg "$1" "$2" "$3" "$4";;
	"BUILD_SYNC"	) send_EnvSync_msg "$1" "$2" "$3" "$4" "$5";;
	*				) send_CompileImport_msg "$1" "$2" "$3" "$4" "$5";;
esac
