#!/bin/ksh
################################################################################################
# jenkins pipeline shell script for Aldon auto checkin
# created by: Vipul Kuruppu
# created on: 14-03-2018
# Change log:
# date - version - changes
# 20-03-2018 - 0.1 	- Initial version
# 14-04-2018 - 0.2 	- Updated for binary check-in
#					- Updated for non-single source
#					- Updated to include conflict resolution
################################################################################################

################################################################################################
# this script rerquires input parametes as below. designed for linux bash shell
# MANDETORY PARAMETER
# param 1 = task type - INIT, SIGNON, GETLATEST, GENDIFF, CHECKOUT, UPDATEDEVENV, ADDNEWOBJECTS,
#						MARKASDELETE, CHECKIN, SHUTDOWN
#
# SUPPORTED PARAMETERS UPON EACH TASK TYPE (key=value combinations). key=value order is flexible.
# all parameters for a perticular task are mandetory and should not be null. script should be 
# called with full path. must use key values with no spaces
# e.g.: ${script_path}/pipeline.sh INIT ald_release=UOB/CLR/CLR(SG) country=SG module=ONLINE
#
# 1. INIT ------------------------------------------------
#	ald_release=YOUR/ALDON/RELEASE::\$UX_APP (e.g. ald_release=UOB/CLR/CLR(SG))
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
# 2. SIGNON ----------------------------------------------
#	ald_user=aldonusername
#	ald_scrt=aldonpassword
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
#	run_mode=RUNMODE (available modes - FORCE, QUEUED, FORCEQUEUED)
#	queue_timeout=[timeout in minutes] maximum time to wait in queue
#	mode description:
#	FORCE - terminate any running session and proceed to sign on
#	QUEUED - wait for the "queue_timeout" and exit without proceed
#	FORCEQUEUED - wait for the "queue_timeout" and proceed by terminating any running sessions
# 3. GETLATEST -------------------------------------------
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
# 4. GENDIFF ---------------------------------------------
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
# 5. CHECKOUT ---------------------------------------------
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
#	ald_task=[aldon task assembly name]
# 6. UPDATEDEVENV ---------------------------------------------
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
# 7. ADDNEWOBJECTS ---------------------------------------------
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
#	ald_task=[aldon task assembly name]
# 8. MARKASDELETE ---------------------------------------------
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
#	ald_task=[aldon task assembly name]
# 9. CHECKIN ---------------------------------------------
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
# 10.SHUTDOWN ---------------------------------------------
#	-- no parameters --
################################################################################################

# set LME server name. check LMC configuration under /opt/aldon/aldonlmc and set accordingly
export lme_server="LMeServer"

####################### DO NOT CHANGE BEYOND THIS WITHOUT PROPER ANALISYS ######################

# setup environment - must run with full path via jenkins
mepath=$(dirname $0)
export jenkins_workspace=$(dirname $0)
export ald_devenv_root=${jenkins_workspace}/ald_devenv_root
export svn_code_home=${jenkins_workspace}/svn_src
export tmp_dir=${jenkins_workspace}/tmp
export session_id_file=${tmp_dir}/session.id
export JAVA_HOME=/app/java/java8_64
export M2_HOME=/app/apache-maven-3.5.0
export PATH=$JAVA_HOME/bin:$PATH:$HOME/bin:$M2_HOME/bin:/app/csvn/bin:/opt/aldon/aldonlmc/current/bin
export HOME=$(grep -w ^$(whoami) /etc/passwd | awk -F: {'print $6'})


################################################################################################
# function to abort with error message if return_status <> 0
# input parameters: return_status error_message
################################################################################################
error_abort(){

	# if return_status in not zero
	if [ $1 -ne 0 ]; then
		echo $2
		# remove session file
		if [ -f ${session_id_file} ]; then rm -f ${session_id_file}; fi
		# check whether already logged in to aldon and exit
		if [ $(check_session_status) -eq 1 ]; then
			ald signoff
			ald shutdown
		fi
		exit 1
	fi
}

################################################################################################
# function to clean temporary directory
################################################################################################
cleanup_tmp(){

	# clean temp directory
	if [ -d ${tmp_dir} ]; then 
		rm -rf ${tmp_dir}/*
	else
		mkdir -p ${tmp_dir}
	fi
}

################################################################################################
# function to get aldon session ID from runtime environment
# output - [session-id] if there is a runtime session or 0 otherwise
################################################################################################
get_ald_runtime_session(){

	# get session ID from runtime
	ald listsvrs > /dev/null
	if [ $? -eq 0 ] && [ ! "$(ald listsvrs | awk {'print $3'})" = "servers." ]; then
		echo $(ald listsvrs | awk {'print $3'})
	else
		echo 0
	fi
	return 0
}

################################################################################################
# function to check whether already in a valid aldon session (already logged in)
# output -  0 if no active session
#           1 if in an active session
#           2 if an active foriegn session
#           3 if an orphan session
################################################################################################
check_session_status(){

	# check aldcs process
	aldcs_pid=$(ps -ef | grep 55555 | grep -v grep | awk {'print $2'})
	
	# get runtime session
	ald_runtime_session=$(get_ald_runtime_session)

	# check recorded session ID
	if [ -f ${session_id_file} ]; then
		recorded_session_id=$(cat ${session_id_file})
	else
		recorded_session_id=0
	fi

	# return apropriate status
	if [ -z "${aldcs_pid}" ] && [ ${ald_runtime_session} -eq 0 ]; then
		# no active session
		echo 0
		return 0
	fi
	if [ -n "${aldcs_pid}" ] && [ ${ald_runtime_session} -gt 0 ] && [ ${ald_runtime_session} -eq ${recorded_session_id} ]; then
		# in an active session
		echo 1
		return 0
	fi
	if [ -n "${aldcs_pid}" ] && [ ${ald_runtime_session} -ne ${recorded_session_id} ]; then
		# foriegn session. i.e. some other job has already logged in to aldon
		echo 2
		return 0
	fi
	if [[ ( -z "${aldcs_pid}" && ${ald_runtime_session} -ne 0 ) || ( -n "${aldcs_pid}" && ${ald_runtime_session} -eq 0 ) ]]; then
		# in an orphan session
		echo 3
		return 0
	fi
}

################################################################################################
# function to check whether a directory is empty
# input parameter: /full/path/to/directory
# output : 0=empty 1=non-empty 2=not-exist
################################################################################################
is_directory_empty(){

	# return 2 if non exist
	if [ ! -d $1 ]; then 
		echo 2
		return 0
	fi
	# check for content and return status
	if [ $(find $1 -mindepth 1 -print -quit | head -1 | wc -l) -ne 0 ]; then 
		echo 1
	else 
		echo 0
	fi
	return 0
}

################################################################################################
# function to terminate existing aldon session
################################################################################################
terminate_ald_session(){

	# sign off and shutdown
	ald signoff
	ald shutdown
	# kill running aldcs
	if [ -n "$(ps -ef | grep 55555 | grep -v grep | awk {'print $2'})" ];then
		kill -9 $(ps -ef | grep 55555 | grep -v grep | awk {'print $2'})
	fi
	# clean the session file
	if [ -f ${session_id_file} ]; then
		rm -f ${session_id_file}
	fi
	return 0
}

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

################################################################################################
# function to initialize aldon release
# input parameters:
#	ald_release=YOUR/ALDON/RELEASE::\$UX_APP (e.g. ald_release=UOB/CLR/CLR(SG))
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
################################################################################################
ald_initialize(){

	# get input parameters
	for in_parm_ in $*
	do
		case $(get_key ${in_parm_}) in
			"ald_release"	) ald_release=$(get_key_value ${in_parm_} "ald_release");;
			"country" 		) country=$(get_key_value ${in_parm_} "country");;
			"module" 		) module=$(get_key_value ${in_parm_} "module");;
			* 				) error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_initialize]: Unable to initialize. Invalid parameter given";;
		esac
	done

	# exit if one or more values are empty
	error_abort $(echo "${ald_release}${country}${module}" | tr -cd ' ' | wc -c) "$(date) - ERROR [${country}] [${module}] [ald_initialize]: Unable to initialize. One or more required parameters are empty"
	
	# echo message to print in log
	echo "$(date) - INFO [${country}] [${module}] [ald_initialize]: Starting initialize with ald_release=${ald_release} country=${country} module=${module}"

	# prepare complete aldon release string
	ald_release=${lme_server}:${ald_release}
	
	# create dev environment
	rc=0
	if [ -d ${ald_devenv_root}/${country}/${module} ]; then
		rm -rf ${ald_devenv_root}/${country}/${module}/*
		rc=$?
	else
		mkdir -p ${ald_devenv_root}/${country}/${module}
		rc=$?
	fi
	# check status and abort if failed to initialize
	if [ ${rc} -ne 0 ];then
		if [ -d ${ald_devenv_root}/${country}/${module} ]; then rm -rf ${ald_devenv_root}/${country}/${module}; fi
		error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_initialize]: Unable to initialize directory ${ald_devenv_root}/${country}/${module}. Please check jenkins workspace settings"
	fi
	
	# initialize
	rc=0
	cd ${ald_devenv_root}/${country}/${module}
	ald initialize ${ald_release}
	rc=$?
	
	# check status and abort if failed to initialize
	if [ ${rc} -ne 0 ];then
		if [ -d ${ald_devenv_root}/${country}/${module} ]; then rm -rf ${ald_devenv_root}/${country}/${module}; fi
		error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_initialize]: Unable to initialize release. Please check logs for details"
	fi
	# return final status
	echo "$(date) - INFO [${country}] [${module}] [ald_initialize]: Initialized with ald_release=${ald_release} country=${country} module=${module}"
	return ${rc}
}

################################################################################################
# function to sign on to aldon and set development environment
# IMPORTANT - must initialize prior sign on
# input parameters:
#	ald_user=aldonusername
#	ald_scrt=aldonpassword
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
#	run_mode=RUNMODE (available modes - FORCE, QUEUED, FORCEQUEUED)
#	queue_timeout=[timeout in minutes] maximum time to wait in queue
################################################################################################
ald_signon(){

	# get input parameters
	for in_parm_ in $*
	do
		case $(get_key ${in_parm_}) in
			"ald_user" 		) ald_user=$(get_key_value ${in_parm_} "ald_user");;
			"ald_scrt" 		) ald_scrt=$(get_key_value ${in_parm_} "ald_scrt");;
			"country" 		) country=$(get_key_value ${in_parm_} "country");;
			"module" 		) module=$(get_key_value ${in_parm_} "module");;
			"run_mode" 		) run_mode=$(get_key_value ${in_parm_} "run_mode");;
			"queue_timeout" ) queue_timeout=$(get_key_value ${in_parm_} "queue_timeout");;
			* 				) error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_signon]: Unable to sign on. Invalid parameter given";;
		esac
	done
	# set timeout to 0 if blank
	if [ -z "${queue_timeout}" ];then queue_timeout=0; fi
	
	# exit if one or more values are empty
	error_abort $(echo "${ald_user}${ald_scrt}${country}${module}${run_mode}${queue_timeout}" | tr -cd ' ' | wc -c) "$(date) - ERROR [${country}] [${module}] [ald_signon]: Unable to sign on. One or more required parameters are empty"

	# check whether dev env already initialized. exit if not
	if [ ! -d ${ald_devenv_root}/${country}/${module} ]; then
		error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_signon]: Release has not been initialized. Not proceeding with sign on"
	fi

	# echo message to print in log
	echo "$(date) - INFO [${country}] [${module}] [ald_signon]: Starting sign on with ald_user=${ald_user} ald_scrt=[not-showing] country=${country} module=${module} run_mode=${run_mode} queue_timeout=${queue_timeout}"

	# check current aldon session status
	ald_runtime_status=$(check_session_status)
		  
	# action upon runtime status status
	case ${ald_runtime_status} in
		# no active sessions so proceed. delete session id file if exists
		0 )	echo "$(date) - INFO [${country}] [${module}] [ald_signon]: No active sessions found. Proceeding with sign on...";
			if [ -f ${session_id_file} ]; then rm -f ${session_id_file}; fi;;
		# already in an active session. no need to re sign-on
		1 )	echo "$(date) - INFO [${country}] [${module}] [ald_signon]: Already in an active session. Not re signing on...";
			signed_on="true";;
		# someone else is already signed on. proceed or wait upon run mode
		2 )	echo "$(date) - INFO [${country}] [${module}] [ald_signon]: An active foriegn session $(get_ald_runtime_session) running in background... ";
			if [ ${run_mode} = "FORCE" ]; then
			# terminate running session
				echo "$(date) - INFO [${country}] [${module}] [ald_signon]: FORCE mode. Terminating running sessions...";
				terminate_ald_session;
			elif [[ ( ${run_mode} = "QUEUED" || ${run_mode} = "FORCEQUEUED" ) ]]; then
				wait_time=0;
				# wait for one session released or timeout which comes first
				echo "$(date) - INFO [${country}] [${module}] [ald_signon]: ${run_mode} mode. Waiting for ${queue_timeout} minutes for the running session ($(get_ald_runtime_session)) to exit..."
				while [ $(get_ald_runtime_session) -ne 0 ];
				do
					sleep 60;
					((wait_time=${wait_time}+1));
					echo "$(date) - INFO [${country}] [${module}] [ald_signon]: ${wait_time} - Checking for foriegn sessions. Found session -  $(get_ald_runtime_session)"
					if [ ${wait_time} -eq ${queue_timeout} ]; then
						echo "$(date) - INFO [${country}] [${module}] [ald_signon]: Timeout reached. Going out of waiting state..."
						break
					fi
				done
				if [ ${run_mode} = "QUEUED" ] && [ $(get_ald_runtime_session) -ne 0 ]; then
					# still foriegn session is active to exit since in queue mode
					error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_signon]: Timeout exceeded. Not proceeding with sign on";
				elif [ ${run_mode} = "FORCEQUEUED" ] && [ $(get_ald_runtime_session) -ne 0 ]; then
					# terminate running session as in force-queued mode
					echo "$(date) - INFO [${country}] [${module}] [ald_signon]: FORCEQUEUED mode. Terminating running sessions after timeout...";
					terminate_ald_session;
				fi;
			fi;;
		# orphan session is running. terminating and proceed with sign on
		3 )	echo "$(date) - INFO [${country}] [${module}] [ald_signon]: Terminating orphan sessions...";
			terminate_ald_session;;
	esac

	# proceed with sign on
	module_src_home="${ald_devenv_root}/${country}/${module}"
	cd ${module_src_home}
	rc=0

	# sign on if already in an active session
	if [ ! "${signed_on}" = "true" ]; then
		echo "$(date) - INFO [${country}] [${module}] [ald_signon]: Cleaning up ${tmp_dir}..."
		cleanup_tmp
		# sign on to aldon
		if [ ${rc} -ne 0 ];then
			# exit with error
			error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_signon]: Unable change directory to ${module_src_home}. Please see log for error"
		else
			echo "$(date) - INFO [${country}] [${module}] [ald_signon]: Signing in to Aldon..."
			ald signon -q -p ${ald_scrt} ${ald_user}
			rc=$?
		fi
	fi
	# get aldon session if sign on is okay
	if [ ${rc} -ne 0 ];then
		# exit with error
		error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_signon]: Unable to sign on to Aldon. Please see log for error"
	else
		echo "$(date) - INFO [${country}] [${module}] [ald_signon]: Getting Aldon session..."
		ald listsvrs
		rc=$?
	fi
	# save aldon session to session id file if get session is okay
	if [ ${rc} -ne 0 ];then
		# exit with error
		error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_signon]: Unable to get session from Aldon. Please see log for error"
	else
		echo "$(date) - INFO [${country}] [${module}] [ald_signon]: Write Aldon session id to ${session_id_file}..."
		if [ -f ${session_id_file} ]; then rm -f ${session_id_file}; fi
		ald listsvrs | awk {'print $3'} > ${session_id_file}
		rc=$?
	fi
	# create or cleanup aldon source directory
	if [ ${rc} -ne 0 ];then
		# exit with error
		error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_signon]: Unable to save session id to file. Please see log for error"
	else
		# all okay
		echo "$(date) - INFO [${country}] [${module}] [ald_signon]: Sign On completed for ald_user=${ald_user} and Development env set for country=${country} module=${module} run_mode=${run_mode} queue_timeout=${queue_timeout}"
		return 0
	fi
}

################################################################################################
# function to sign on to aldon and set development environment
# IMPORTANT - must initialize prior sign on
# input parameters:
#	ald_user=aldonusername
#	ald_scrt=aldonpassword
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
#	run_mode=RUNMODE (available modes - FORCE, QUEUED, FORCEQUEUED)
#	queue_timeout=[timeout in minutes] maximum time to wait in queue
################################################################################################
ald_setdevpath(){

	# get input parameters
	for in_parm_ in $*
	do
		case $(get_key ${in_parm_}) in
			"country" 		) country=$(get_key_value ${in_parm_} "country");;
			"module" 		) module=$(get_key_value ${in_parm_} "module");;
			* 				) error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_setdevpath]: Unable to set development env. Invalid parameter given";;
		esac
	done
	
	# exit if one or more values are empty
	error_abort $(echo "${ald_user}${ald_scrt}${country}${module}${run_mode}${queue_timeout}" | tr -cd ' ' | wc -c) "$(date) - ERROR [${country}] [${module}] [ald_setdevpath]: Unable to set development env. One or more required parameters are empty"

	# check whether dev env already initialized. exit if not
	if [ $(check_session_status) -ne 1 ]; then
		error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_setdevpath]: Not signed on to Aldon. Cannot proceed with set development env"
	fi

	# echo message to print in log
	echo "$(date) - INFO [${country}] [${module}] [ald_setdevpath]: Starting development env for country=${country} module=${module}"

	# proceed with sign on and set dev enviornment
	module_src_home="${ald_devenv_root}/${country}/${module}"
	cd ${module_src_home}
	rc=0
	
	# create or cleanup aldon source directory
	echo "$(date) - INFO [${country}] [${module}] [ald_setdevpath]: Creating ald_src for dev env..."
	if [ -d ${module_src_home}/ald_src ]; then
		rm -rf ${module_src_home}/ald_src/*
		rc=$?
	else
		mkdir ${module_src_home}/ald_src
		rc=$?
	fi
	
	# set development env if create/cleanup dev source directory is okay
	if [ ${rc} -ne 0 ];then
		# exit with error
		error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_setdevpath]: Unable to create or clenup ${module_src_home}/ald_src . Please see log for error"
	else
		echo "$(date) - INFO [${country}] [${module}] [ald_setdevpath]: Running ald command (ald setdevpath -r)..."
		cd ${module_src_home}/ald_src
		ald setdevpath -r
		rc=$?
	fi
	# return 0 if all are okay
	if [ ${rc} -ne 0 ];then
		# exit with error
		error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_setdevpath]: Unable to set development environment. Please see log for error"
	else
		# all okay
		echo "$(date) - INFO [${country}] [${module}] [ald_setdevpath]: Development env set completed for country=${country} module=${module}"
		return 0
	fi
}

################################################################################################
# function to get latest from aldon in to development environment
# IMPORTANT - must initialize and sign on prior to get latest
# input parameters:
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
################################################################################################
ald_getlatest(){

	# get input parameters
	for in_parm_ in $*
	do
		case $(get_key ${in_parm_}) in
			"country" 		) country=$(get_key_value ${in_parm_} "country");;
			"module" 		) module=$(get_key_value ${in_parm_} "module");;
			* 				) error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_getlatest]: Unable to get latest. Invalid parameter given";;
		esac
	done

	# exit if one or more values are empty
	error_abort $(echo "${country}${module}" | tr -cd ' ' | wc -c) "$(date) - ERROR [${country}] [${module}] [ald_getlatest]: Unable to get latest. One or more required parameters are empty"
	
	# check whether dev env is set
	if [ $(check_session_status) -ne 1 ] && [ ! -d ${ald_devenv_root}/${country}/${module}/ald_src ]; then
		error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_getlatest]: Unable to get latest. Development environment not set"
	fi

	# echo message to print in log
	echo "$(date) - INFO [${country}] [${module}] [ald_getlatest]: Starting get latest with country=${country} module=${module}"
# TO-DO remove after testing
return 0

	# change to ald_src
	rc=0
	cd ${ald_devenv_root}/${country}/${module}/ald_src
	rc=$?
	error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_getlatest]: Unable to get latest. Cannot change working directory to ${ald_devenv_root}/${country}/${module}/ald_src"
	# get latest sources from aldon
	echo "$(date) - INFO [${country}] [${module}] [ald_getlatest]: Fetching latest codes. This may take some time..."
	ald get -Aaw
	rc=$?
	# check status and exit
	error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_getlatest]: Unable to get latest source from aldon. Please see log for error"
	echo "$(date) - INFO [${country}] [${module}] [ald_getlatest]: Completed get latest with country=${country} module=${module}"
	return 0
}

################################################################################################
# function to prepare the SVN code and generate diff reports against the aldon sources
# IMPORTANT - must get aldon latest source prior to generate diff
# input parameters:
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
################################################################################################
ald_generate_diff(){

	# get input parameters
	for in_parm_ in $*
	do
		case $(get_key ${in_parm_}) in
			"country" 		) country=$(get_key_value ${in_parm_} "country");;
			"module" 		) module=$(get_key_value ${in_parm_} "module");;
			* 				) error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_generate_diff]: Unable to generate diff reports. Invalid parameter given";;
		esac
	done

	# validate all parameters has values
	if [ $(echo "${country}${module}" | tr -cd ' ' | wc -c) -ne 0 ]; then
		# one or more values are empty
		error_abort "$(date) - ERROR [${country}] [${module}] [ald_generate_diff]: Unable to generate diff reports. One or more required parameters are empty"
	fi

	# check whether sources available in ald_src (get latest completed)
	if [ $(is_directory_empty ${ald_devenv_root}/${country}/${module}/ald_src) -ne 1 ]; then
		error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_generate_diff]: Unable to generate diff reports. Get latest sources not available"
	fi

	# echo message to print in log
	echo "$(date) - INFO [${country}] [${module}] [ald_generate_diff]: Starting generate diff reports for country=${country} module=${module}"
# TO-DO remove after testing
return 0

	# generate diff reports
	cd ${module_src_home}
	# generate full list
	echo "$(date) - INFO [${country}] [${module}] [ald_generate_diff]: Generating complete file list..."
	diff -rqN --strip-trailing-cr new_src ald_src | grep -v .svn | grep -v .cekey | grep -v .aldlme | gawk -F' and ' '{print $1}' | gawk -F'Files ' '{print $2}' > ${country}_${module}_objects_list.txt
	rc=$?
	error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_generate_diff]: Unable to generate diff reports. Error while generating the complete file list"
	# generate new, changed and delete lists
	echo "$(date) - INFO [${country}] [${module}] [ald_generate_diff]: Generating updated, new and deleted file lists..."
	for _file_ in $(cat ${country}_${module}_objects_list.txt)
	do
		_file_=$(echo ${_file_} | gawk -F'new_src/' {'print $2'})
		if [ -f new_src/${_file_} ] && [ -f ald_src/${_file_} ]; then
			echo ${_file_} >> ${country}_${module}_updated_files.txt
			((rc=${rc}+$?))
		else
			if [ -f new_src/${_file_} ]; then
				echo ${_file_} >> ${country}_${module}_new_files.txt
				((rc=${rc}+$?))
			fi
			if [ -f ald_src/${_file_} ]; then
				echo ${_file_} >> ${country}_${module}_deleted_files.txt
				((rc=${rc}+$?))
			fi			
		fi
	done
	# exit if error else return 0
	error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_generate_diff]: Unable to generate diff reports. Error while generating new, changed and deleted file lists"
	echo "$(date) - INFO [${country}] [${module}] [ald_generate_diff]: Generated diff reports for country=${country} module=${module}"
	return 0
}

################################################################################################
# function to checkout from aldon and clear conflicts
# IMPORTANT - must have generated diff lists
# input parameters:
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
#   ald_task=ALDON_TASK
################################################################################################
ald_checkout(){

	# get input parameters
	for in_parm_ in $*
	do
		case $(get_key ${in_parm_}) in
			"country" 		) country=$(get_key_value ${in_parm_} "country");;
			"module" 		) module=$(get_key_value ${in_parm_} "module");;
			"ald_task" 		) ald_task=$(get_key_value ${in_parm_} "ald_task");;
			* 				) error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_checkout]: Unable to check-out. Invalid parameter given";;
		esac
	done

	# exit if one or more values are empty
	error_abort $(echo "${country}${module}${ald_task}" | tr -cd ' ' | wc -c) "$(date) - ERROR [${country}] [${module}] [ald_checkout]: Unable to check-out. One or more required parameters are empty"

	# check whether diffs have generated
	if [ ! -f ${ald_devenv_root}/${country}/${module}/${country}_${module}_objects_list.txt ]; then
		error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_checkout]: Unable to check-out. Diff reports not available"
	fi

	# echo message to print in log
	echo "$(date) - INFO [${country}] [${module}] [ald_checkout]: Starting check-out for country=${country} module=${module}  ald_task=${ald_task}"
# TO-DO remove after testing
return 0

	# define local code directory name and comment
	module_src_home="${ald_devenv_root}/${country}/${module}"
	cin_comment="${country}_${module}_$(date +%d%m%Y_%H%M%S)"

	# check whether anything to check out
	if [ ! -f ${module_src_home}/${country}_${module}_updated_files.txt ]; then
		echo "$(date) - INFO [${country}] [${module}] [ald_checkout]: No changed objects to check-out. Skipping..."
		return 0
	fi

	# checking out from aldon
	rc=0
	echo "$(date) - INFO [${country}] [${module}] [ald_checkout]: Starting check-out updated files..."
	cd ${module_src_home}/ald_src
	rc=$?
	error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_checkout]: Unable to check-out. Could not change working directory to ${module_src_home}/ald_src"
	if [ -z "$(cat ${module_src_home}/${country}_${module}_updated_files.txt)" ]; then
		echo "$(date) - INFO [${country}] [${module}] [ald_checkout]: Nothing to check-out for update..."
		return 0
	else
		for updated_file in $(cat ${module_src_home}/${country}_${module}_updated_files.txt)
			do
				ald checkout -a ${ald_task} -c ${cin_comment} ${updated_file}
				((rc=${rc}+$?))
		done
		error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_checkout]: Unable to complete check-out. Error checking out some of the objects. You may need investigate with LMe"
	fi
	
	echo "$(date) - INFO [${country}] [${module}] [ald_checkout]: Completed checking out of updated files for country=${country} module=${module} ald_task=${ald_task}"
	return 0
}

################################################################################################
# function to update aldon dev env with new files
# IMPORTANT - must have checked out updated files
# input parameters:
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
################################################################################################
ald_sync_dev_env(){

	# get input parameters
	for in_parm_ in $*
	do
		case $(get_key ${in_parm_}) in
			"country" 		) country=$(get_key_value ${in_parm_} "country");;
			"module" 		) module=$(get_key_value ${in_parm_} "module");;
			* 				) error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_sync_dev_env]: Unable to update dev env. Invalid parameter given";;
		esac
	done

	# exit if one or more values are empty
	error_abort $(echo "${country}${module}" | tr -cd ' ' | wc -c) "$(date) - ERROR [${country}] [${module}] [ald_sync_dev_env]: Unable to update dev env. One or more required parameters are empty"

	# echo message to print in log
	echo "$(date) - INFO [${country}] [${module}] [ald_sync_dev_env]: Starting update dev env for country=${country} module=${module}"
# TO-DO remove after testing
return 0
	# define local code directory name
	module_src_home="${ald_devenv_root}/${country}/${module}"

	# check whether requred directories exist
	if [ ! -d ${module_src_home}/ald_src ]; then
		error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_sync_dev_env]: Unable to update dev env. Directory ${module_src_home}/ald_src doesn't exists"
	fi
	if [ ! -d ${module_src_home}/new_src ]; then
		error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_sync_dev_env]: Unable to update dev env. Directory ${module_src_home}/new_src doesn't exists"
	fi

	# backup ald_src
	cd ${module_src_home}
	echo "$(date) - INFO [${country}] [${module}] [ald_sync_dev_env]: Backing up existing aldon code"
	mv ald_src ald_src_old
	rc=$?
	error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_sync_dev_env]: Unable to update dev env. Error backing up ald_src"
	# copy new sources
	cd ${module_src_home}
	echo "$(date) - INFO [${country}] [${module}] [ald_sync_dev_env]: Syncing new_src to ald_src"
	mv new_src ald_src
	rc=$?
	error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_sync_dev_env]: Unable to update dev env. Error syncing new_src to ald_src"
	if [ -d ald_src_old/.aldlme ];then
		echo "$(date) - INFO [${country}] [${module}] [ald_sync_dev_env]: Copying .aldlme from ald_src_old to ald_src"
		cp -R ald_src_old/.aldlme ald_src
		rc=$?
		error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_sync_dev_env]: Unable to update dev env. Error copying aldon configuration (.aldlme) from ald_src_old to ald_src"
	fi
	
	echo "$(date) - INFO [${country}] [${module}] [ald_sync_dev_env]: Starting update dev env for country=${country} module=${module}"
	return 0
}

################################################################################################
# function to add new objects to aldon
# IMPORTANT - must have generated diff lists and synced folders
# input parameters:
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
#   ald_task=ALDON_TASK
################################################################################################
ald_add_new_objects(){

	# get input parameters
	for in_parm_ in $*
	do
		case $(get_key ${in_parm_}) in
			"country" 		) country=$(get_key_value ${in_parm_} "country");;
			"module" 		) module=$(get_key_value ${in_parm_} "module");;
			"ald_task" 		) ald_task=$(get_key_value ${in_parm_} "ald_task");;
			* 				) error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_add_new_objects]: Unable to add objects. Invalid parameter given";;
		esac
	done

	# exit if one or more values are empty
	error_abort $(echo "${country}${module}${ald_task}" | tr -cd ' ' | wc -c) "$(date) - ERROR [${country}] [${module}] [ald_add_new_objects]: Unable to add objects. One or more required parameters are empty"

	# define local code directory name and comment
	module_src_home="${ald_devenv_root}/${country}/${module}"
	cin_comment="${country}_${module}_$(date +%d%m%Y_%H%M%S)"

	# check whether diffs have generated
	if [ ! -f ${module_src_home}/${country}_${module}_objects_list.txt ]; then
		error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_add_new_objects]: Unable to add objects. Diff reports not available"
	fi
	# check whether folder sync has been done
	if [ -d ${module_src_home}/new_src ] && [ ! -d ${module_src_home}/ald_src ] && [ ! -d ${module_src_home}/ald_src_old ] ; then
		error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_add_new_objects]: Unable to add objects. Deroctory sync has not been done for dev env"
	fi

	# echo message to print in log
	echo "$(date) - INFO [${country}] [${module}] [ald_add_new_objects]: Starting adding objects to aldon for country=${country} module=${module} ald_task=${ald_task}"
# TO-DO remove after testing
return 0
	
	# check whether anything to check out
	if [ ! -f ${module_src_home}/${country}_${module}_new_files.txt ]; then
		echo "$(date) - INFO [${country}] [${module}] [ald_add_new_objects]: No new objects to add. Skipping..."
		return 0
	fi
	# add objects to aldon
	rc=0
	cd ${module_src_home}/ald_src
	rc=$?
	error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_add_new_objects]: Unable to check-out. Could not change working directory to ${module_src_home}/ald_src"
	if [ -z "$(cat ${module_src_home}/${country}_${module}_new_files.txt)" ]; then
		echo "$(date) - INFO [${country}] [${module}] [ald_add_new_objects]: No new objects to add..."
		return 0
	else
		for new_file in $(cat ${module_src_home}/${country}_${module}_new_files.txt)
		do
			ald add -a ${ald_task} -c ${cin_comment} ${new_file}
			((rc=${rc}+$?))
		done
	fi
	error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_add_new_objects]: Unable to complete adding new objects. You may need investigate with LMe"
	echo "$(date) - INFO [${country}] [${module}] [ald_add_new_objects]: Completed adding objects to aldon for country=${country} module=${module} ald_task=${ald_task}"
	return 0
}

################################################################################################
# function to mark objects as deleted (checkout,clear conflicts and then mark as delete)
# IMPORTANT - must have generated diff lists and synced folders
# input parameters:
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
#   ald_task=ALDON_TASK
################################################################################################
ald_mark_for_delete(){

	# get input parameters
	for in_parm_ in $*
	do
		case $(get_key ${in_parm_}) in
			"country" 		) country=$(get_key_value ${in_parm_} "country");;
			"module" 		) module=$(get_key_value ${in_parm_} "module");;
			"ald_task" 		) ald_task=$(get_key_value ${in_parm_} "ald_task");;
			* 				) error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_mark_for_delete]: Unable to mark objects as deleted. Invalid parameter given";;
		esac
	done

	# exit if one or more values are empty
	error_abort $(echo "${country}${module}${ald_task}" | tr -cd ' ' | wc -c) "$(date) - ERROR [${country}] [${module}] [ald_mark_for_delete]: Unable to mark objects as deleted. One or more required parameters are empty"

	# define local code directory name and comment
	module_src_home="${ald_devenv_root}/${country}/${module}"
	cin_comment="${country}_${module}_$(date +%d%m%Y_%H%M%S)"

	# check whether diffs have generated
	if [ ! -f ${module_src_home}/${country}_${module}_objects_list.txt ]; then
		error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_mark_for_delete]: Unable to mark objects as deleted. Diff reports not available"
	fi
	# check whether folder sync has been done
	if [ -d ${module_src_home}/new_src ] && [ ! -d ${module_src_home}/ald_src ] && [ ! -d ${module_src_home}/ald_src_old ] ; then
		error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_mark_for_delete]: Unable to mark objects as deleted. Deroctory sync has not been done for dev env"
	fi

	# echo message to print in log
	echo "$(date) - INFO [${country}] [${module}] [ald_mark_for_delete]: Starting marking objects as deleted for country=${country} module=${module} ald_task=${ald_task}"
# TO-DO remove after testing
return 0

	# check whether anything to delete
	if [ ! -f ${module_src_home}/${country}_${module}_deleted_files.txt ]; then
		echo "$(date) - INFO [${country}] [${module}] [ald_mark_for_delete]: No objects to mark as deleted. Skipping..."
		return 0
	fi

	# first checking out from aldon
	rc=0
	echo "$(date) - INFO [${country}] [${module}] [ald_mark_for_delete]: Starting check-out for mark as delete..."
	cd ${module_src_home}/ald_src
	rc=$?
	error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_mark_for_delete]: Unable to check-out for mark as delete. Could not change working directory to ${module_src_home}/ald_src"
	if [ -z "$(cat ${module_src_home}/${country}_${module}_deleted_files.txt)" ]; then
		echo "$(date) - INFO [${country}] [${module}] [ald_mark_for_delete]: Nothing to check-out for mark as delete..."
		return 0
	else
		for deleted_file in $(cat ${module_src_home}/${country}_${module}_deleted_files.txt)
			do
				ald checkout -a ${ald_task} -c ${cin_comment} ${deleted_file}
				((rc=${rc}+$?))
		done
		error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_mark_for_delete]: Unable to complete check-out for mark as delete. Error checking out some of the objects. You may need investigate with LMe"
	fi

	# proceed with mark for delete
	echo "$(date) - INFO [${country}] [${module}] [ald_mark_for_delete]: Starting mark for deletion..."
	for deleted_file in $(cat ${module_src_home}/${country}_${module}_deleted_files.txt)
	do
		ald delete ${deleted_file}
		((rc=${rc}+$?))
	done
	error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_mark_for_delete]: Unable to complete marking for delete. You may need investigate with LMe"
	echo "$(date) - INFO [${country}] [${module}] [ald_mark_for_delete]: Completed marking objects as deleted for country=${country} module=${module} ald_task=${ald_task}"
	return 0
}

################################################################################################
# function to check in all checked out objects
# IMPORTANT - must have generated diff lists and synced folders
# input parameters:
#	country=COUNTRY (CORE,SG,TH,etc)
#	module=MODULENAME (e.g.: module=ONLINE, here valid modules are ONLINE, SCRIPTS & TEMPLATES)
#   ald_task=ALDON_TASK
################################################################################################
ald_checkin(){

	# get input parameters
	for in_parm_ in $*
	do
		case $(get_key ${in_parm_}) in
			"country" 		) country=$(get_key_value ${in_parm_} "country");;
			"module" 		) module=$(get_key_value ${in_parm_} "module");;
			* 				) error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_checkin]: Unable to check-in. Invalid parameter given";;
		esac
	done

	# exit if one or more values are empty
	error_abort $(echo "${country}${module}" | tr -cd ' ' | wc -c) "$(date) - ERROR [${country}] [${module}] [ald_checkin]: Unable to check-in. One or more required parameters are empty"

	# define local code directory name and comment
	module_src_home="${ald_devenv_root}/${country}/${module}"
	cin_comment="${country}_${module}_$(date +%d%m%Y_%H%M%S)"

	# check whether folder sync has been done
	if [ -d ${module_src_home}/new_src ] && [ ! -d ${module_src_home}/ald_src ] && [ ! -d ${module_src_home}/ald_src_old ] ; then
		error_abort 1 "$(date) - ERROR [${country}] [${module}] [ald_checkin]: Unable to check-in. You may not have checked out objects"
	fi

	# first look for any conflicts
	echo "$(date) - INFO [${country}] [${module}] [ald_checkin]: Starting clearing of conflicts for country=${country} module=${module}"
# TO-DO remove after testing
return 0
	
	ald conflict list -A | findstr "Notification" | findstr "ID" > ${tmp_dir}/${country}.${module}.conflicts
	rc=$?
	error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_checkin]: Error when looking for conflicts. You may need investigate with LMe"
	
	# clear conflicts
	if [ -f ${tmp_dir}/${country}.${module}.conflicts ] && [ -n "$(cat ${tmp_dir}/${country}.${module}.conflicts)" ]; then
		echo "$(date) - INFO [${country}] [${module}] [ald_checkin]: Conflicted objects list:"
		cat ${tmp_dir}/${country}.${module}.conflicts
		echo
		for conflicted_obj in $(cat ${tmp_dir}/${country}.${module}.conflicts)
		do
			conflicted_obj_ID=$(echo ${conflicted_obj} | awk {'printf(substr($0,18,8))'})
			echo "Resolving conflicted ID - ${conflicted_obj_ID}"
			ald conflict clear ${conflicted_obj_ID}
			((rc=${rc}+$?))
		done
	fi
	error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_checkin]: Error when clearing conflicts. You may need investigate with LMe"
	echo "$(date) - INFO [${country}] [${module}] [ald_checkin]: Completed clearing of conflicts for country=${country} module=${module}"
	
	# echo message to print in log
	echo "$(date) - INFO [${country}] [${module}] [ald_checkin]: Starting to check-in for country=${country} module=${module}"

	# checking in files to aldon
	rc=0
	cd ${module_src_home}/ald_src
	rc=$?
	error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_checkin]: Unable check-in. Could not change working directory to ${module_src_home}/ald_src"

	ald checkin -A -c ${cin_comment}
	rc=$?
	error_abort ${rc} "$(date) - ERROR [${country}] [${module}] [ald_checkin]: Unable complete check-in. You may need investigate with LMe"
	echo "$(date) - INFO [${country}] [${module}] [ald_checkin]: Completed check-in for country=${country} module=${module}"
	return 0
}

################################################################################################
# function to signoff and shutdown aldon
# IMPORTANT - this function will retun 0 even if sign-off/shutdown is unsuccessful
################################################################################################
ald_shutdown(){

	# check whether already logged in to aldon and exit
	echo "$(date) - INFO [ald_shutdown]: Starting Aldon sign-off and shutdown..."
	rc=0
	if [ $(check_session_status) -eq 1 ]; then
		ald signoff
		((rc=${rc}+$?))
		ald shutdown
		((rc=${rc}+$?))
		if [ ${rc} -ne 0 ]; then
			echo "WARNING [ald_shutdown]: Error during sign-off/shutdown. Please check logs for more details"
			return 0
		fi
	else 
		echo "$(date) - INFO [ald_shutdown]: No active session to shutdown. Skipping..."
	fi
	echo "$(date) - INFO [ald_shutdown]: Completed Aldon sign-off and shutdown..."
	return 0
}

################################################################################################
# main runner
################################################################################################

# get task type
task_type=$1
if [ -z "${task_type}" ]; then
	error_abort 1 "$(date) - ERROR [main]: No task type given..!!"
fi

# shift parameter
shift

# run task with parameters
case ${task_type} in
	"INIT"			) ald_initialize $*;;
	"SIGNON"		) ald_signon $*;;
	"SETDEVENV"		) ald_setdevpath $*;;
	"GETLATEST"		) ald_getlatest $*;;
	"GENDIFF"		) ald_generate_diff $*;;
	"CHECKOUT"		) ald_checkout $*;;
	"UPDATEDEVENV"	) ald_sync_dev_env $*;;
	"ADDNEWOBJECTS"	) ald_add_new_objects $*;;
	"MARKASDELETE"	) ald_mark_for_delete $*;;
	"CHECKIN"		) ald_checkin $*;;
	"SHUTDOWN"		) ald_shutdown;;
	*				) error_abort 1 "$(date) - ERROR [main]: Invalid task type..!!";;
esac
################################################################################################
