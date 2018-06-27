#!/bin/ksh
################################################################
# set build env script
# Author: Vipul Kuruppu
# Created on: 08-12-2016
################################################################

# Set environment
export jenkins_workspace=$(dirname $0)
export ald_devenv_root=${jenkins_workspace}/ald_devenv_root
export svn_code_home=${jenkins_workspace}/svn_src
export svn_artifacts_home=${jenkins_workspace}/articacts
export tmp_dir=${jenkins_workspace}/tmp
export ENVIRON=`hostname`

# set ID
export myid="ownclssg"
export deployid="ownclsmy"

# set other required environment 
export WL_BASE=/app/weblogic
export ALDON_HOME=/opt/aldon/aldonlmc
export PATH=${ALDON_HOME}/current/bin:${JAVA_HOME}/bin:${PATH}
export JAVA_HOME=/app/java/java6_64
export ANT_HOME=${WL_BASE}/modules/org.apache.ant_1.7.1
export ANT_OPTS=-mx1024m  
export HOME=`grep -w ^\`whoami\` /etc/passwd | awk -F: {'print $6'}`

export APP_SERVER=clstsg84
export CD_SERVER=clstsg82

################################################################################################
# function to retrieve key from key=value pair
# input parameter: key=value
################################################################################################
get_key(){

	kvpair=$1

	# check whether this is really a key=value pair
	if [ $(echo ${kvpair} | tr -cd '=' | wc -c) -ne 1 ]; then
		return 1
	# else means valid key=value pair so look for the key
	else
		echo ${kvpair} | awk -F= {'print $1'}
	fi
}

################################################################################################
# function to retrieve value from key=value pair
# input parameters: 1.key=value 2.key
################################################################################################
get_key_value(){

	kvpair=$1
	keyname=$2
	
	# check whether this is really a key=value pair
	if [ $(echo ${kvpair} | tr -cd '=' | wc -c) -ne 1 ]; then
		return 1
	# else means valid key=value pair so look for the value
	else
		echo ${kvpair} | awk -F${keyname}= {'print $2'}
		return 0
	fi
}



