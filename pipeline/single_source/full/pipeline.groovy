pipeline
{
	agent any
	parameters 
	{
		string(defaultValue: 'https://lxclstsgv99.sg.uobnet.com:9999/svn/PLCE_SS/Core/branches/devmt/CORE_QR1_2018', description: 'Enter full CORE SVN URL up to the branch root', name: 'CORE_SVN_Branch')
		string(defaultValue: 'UOB/CLR/CLR(CORE)', description: 'CORE Aldon Release', name: 'CORE_Aldon_Release')
		booleanParam(defaultValue: true, description: 'Select to check-in CORE in to Aldon', name: 'CORE')
		string(defaultValue: 'core_task', description: 'CORE Aldon Task Assembly', name: 'CORE_Aldon_Task')
		choice(choices: 'SKIP\nNO\nYES', description: 'Proceed to mark as delete automatically in CORE?', name: 'CORE_Auto_Delete')

		string(defaultValue: 'https://lxclstsgv99.sg.uobnet.com:9999/svn/PLCE_SS/TH/branches/devmt/TH_QR2_2018', description: 'Enter full Country SVN URL up to the branch root', name: 'COUNTRY_SVN_Branch')
		choice(choices: 'SG\nTH\nMY\nID\nCN\nVN', description: 'Select country', name: 'Country')
		string(defaultValue: 'UOB/CLR/CLR(SG_SS)', description: 'Country specific Aldon Release', name: 'Country_Aldon_Release')
		booleanParam(defaultValue: true, description: 'Select to check-in Country specific online in to Aldon', name: 'ONLINE')
		string(defaultValue: 'online_task', description: 'Country Aldon Online Task Assembly', name: 'Country_Online_Aldon_Task')
		choice(choices: 'SKIP\nNO\nYES', description: 'Proceed to mark as delete automatically in Online?', name: 'Online_Auto_Delete')
		booleanParam(defaultValue: true, description: 'Select to check-in Country specific bin/cd scripts in to Aldon', name: 'SCRIPTS')
		string(defaultValue: 'scripts_task', description: 'Country Aldon Scripts Task Assembly', name: 'Country_Scripts_Aldon_Task')
		choice(choices: 'SKIP\nNO\nYES', description: 'Proceed to mark as delete automatically in scripts?', name: 'Scripts_Auto_Delete')
		booleanParam(defaultValue: true, description: 'Select to check-in Country specific templates in to Aldon', name: 'TEMPLATES')
		string(defaultValue: 'templates_task', description: 'Country Aldon Templates Task Assembly', name: 'Country_Templates_Aldon_Task')
		choice(choices: 'SKIP\nNO\nYES', description: 'Proceed to mark as delete automatically in templates?', name: 'Templates_Auto_Delete')

		string(defaultValue: 'vipulkuruppu', description: 'Enter Aldon Username', name: 'Username')
		password(defaultValue: '12345', description: 'Enter Aldon Password', name: 'Password')
		choice(choices: 'QUEUED\nFORCEQUEUED\nFORCE', description: 'Select run option. FORCE=Force run, QUEUED=Queue until timeout if another build is running, FORCEQUEUED=Wait for timeout and force run', name: 'Run_Mode')
		choice(choices: '10\n20\n30\n40\n50\n60\n70\n80\n90', description: 'Select duration (in minutes) to queue. No effect if FORCE mode is selected', name: 'Queue_Timeout')
	}

	stages
	{

		stage("Initialize Jenkins Environment")	
		{
			steps
			{
				sh "if [ -d ${WORKSPACE}/logs ]; then rm -rf ${WORKSPACE}/logs/*; else mkdir -p ${WORKSPACE}/logs; fi"
				sh "echo '------------------------------------------------' > ${WORKSPACE}/logs/pipeline.log"
				sh "echo 'Jenkins pipeline started at : '\$(date) >> ${WORKSPACE}/logs/pipeline.log"
				sh "echo '------------------------------------------------' >> ${WORKSPACE}/logs/pipeline.log"
			}
		}
		
		stage("Checkout CORE Code From SVN") 
		{
			when 
			{
				expression { return params.CORE }
			}
			steps
			{
				echo "CORE - Checking out ${CORE_SVN_Branch}"
				sh "echo 'CORE - Checking out '${CORE_SVN_Branch} >> ${WORKSPACE}/logs/pipeline.log"
				checkout([
					$class: 'SubversionSCM', 
					additionalCredentials: [], 
					excludedCommitMessages: '', 
					excludedRegions: '', 
					excludedRevprop: '', 
					excludedUsers: '', 
					filterChangelog: false, 
					ignoreDirPropChanges: false, 
					includedRegions: '', 
					locations: [[credentialsId: '33092bcd-d979-4279-8540-c137b47a01f4', 
								depthOption: 'infinity', 
								ignoreExternalsOption: true, 
								local: "./svn_src/CORE", 
								remote: "${CORE_SVN_Branch}" ]], 
					workspaceUpdater: [$class: 'CheckoutUpdater']
				])

			}
		}

		stage("CORE - Initialize Aldon Release")
		{
			when 
			{
				expression { return params.CORE }
			}
			steps
			{
				echo "CORE - Initialiting ${CORE_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh INIT ald_release=\"${CORE_Aldon_Release}::\\\\\\\$UX_APP\" country=CORE module=ONLINE >> ${WORKSPACE}/logs/pipeline.log"
			}
		}

		stage("CORE - Aldon Sign On")
		{
			when 
			{
				expression { return params.CORE }
			}
			steps
			{
				echo "CORE - Signing On to Aldon for ${CORE_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs: [[password: "${Password}", var: 'Password']]]) 
				{
					sh "${WORKSPACE}/pipeline/pipeline.sh SIGNON ald_user=${Username} ald_scrt=${Password} country=CORE module=ONLINE run_mode=${Run_Mode} queue_timeout=${Queue_Timeout} >> ${WORKSPACE}/logs/pipeline.log"
				}
			}
		}

		stage("CORE - Get Latest From Aldon")
		{
			when 
			{
				expression { return params.CORE }
			}
			steps
			{
				echo "CORE - Get Latest From Aldon for ${CORE_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh GETLATEST country=CORE module=ONLINE >> ${WORKSPACE}/logs/pipeline.log"
			}
		}

		stage("CORE - Generate Diff Reports")
		{
			when 
			{
				expression { return params.CORE }
			}
			steps
			{
				echo "CORE - Generate Diff Reports for ${CORE_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh GENDIFF country=CORE module=ONLINE >> ${WORKSPACE}/logs/pipeline.log"
			}
			post
			{
				success
				{
					archiveArtifacts(artifacts: "ald_devenv_root/CORE/ONLINE/CORE_*files.txt", allowEmptyArchive: true)
				}
			}
		}

		stage("CORE - Checkout Changed Objects")
		{
			when 
			{
				expression { return params.CORE }
			}
			steps
			{
				echo "CORE - Checkout Changed Objects From Aldon for ${CORE_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh CHECKOUT country=CORE module=ONLINE ald_task=${CORE_Aldon_Task} >> ${WORKSPACE}/logs/pipeline.log"
			}
		}

		stage("CORE - Update Dev Environment")
		{
			when 
			{
				expression { return params.CORE }
			}
			steps
			{
				echo "CORE - Update Dev Environment for ${CORE_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh UPDATEDEVENV country=CORE module=ONLINE >> ${WORKSPACE}/logs/pipeline.log"
			}
		}

		stage("CORE - Add New Objects to Aldon")
		{
			when 
			{
				expression { return params.CORE }
			}
			steps
			{
				echo "CORE - Add New Objects to Aldon for ${CORE_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh ADDNEWOBJECTS country=CORE module=ONLINE ald_task=${CORE_Aldon_Task} >> ${WORKSPACE}/logs/pipeline.log"
			}
		}

		stage("CORE - Mark As Delete from Aldon")
		{
			when 
			{
				allOf
				{
					expression { return params.CORE }
					expression { params.CORE_Auto_Delete == 'NO' || params.CORE_Auto_Delete == 'YES' }
				}
			}
			environment 
			{
				def delobjectsurl = "${env.BUILD_URL}/artifact/ald_devenv_root/CORE/ONLINE/CORE_ONLINE_deleted_files.txt"
				def delconfirmation = "YES"
			}
			steps
			{
				script
				{
					if (params.CORE_Auto_Delete == 'NO')
					{
						input ( id: 'delconfirmation', message: 'CORE - Proceed with mark as delete [YES/NO]?', parameters: [choice(choices: 'NO\nYES', description: "Deleted objects:\n${delobjectsurl}", name: 'CORE_MARK_AS_DELETE')])
					}
					
					if (delconfirmation == 'YES')
					{
						echo "CORE - Marking Objects as Deleted in Aldon for ${CORE_Aldon_Release}::\\\$UX_APP"
						sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
						sh "${WORKSPACE}/pipeline/pipeline.sh MARKASDELETE country=CORE module=ONLINE ald_task=${CORE_Aldon_Task} >> ${WORKSPACE}/logs/pipeline.log"
					}
					else
					{
						echo "CORE - Skipping Mark As Delete as NO Selected"
						sh "echo \$(date)'- INFO [CORE] [ald_mark_for_delete]: Skipping Mark As Delete as NO Selected...' >> ${WORKSPACE}/logs/pipeline.log"
					}
				}
			}
		}

		stage("CORE - Check-in Objects to Aldon")
		{
			when 
			{
				expression { return params.CORE }
			}                                    
			steps
			{
				echo "CORE - Check-in Objects to Aldon for ${CORE_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh CHECKIN country=CORE module=ONLINE >> ${WORKSPACE}/logs/pipeline.log"
			}
		}
		
		stage("CORE - Aldon Sign Off and Shutdown")
		{
			when 
			{
				expression { return params.CORE }
			}                                    
			steps
			{
				echo "CORE - Sign Off and Shutdown From Aldon for ${CORE_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh SHUTDOWN >> ${WORKSPACE}/logs/pipeline.log"
			}
		}

		stage("Checkout Country Code From SVN") 
		{
			when 
			{
				expression { return ( params.ONLINE || params.SCRIPTS || params.TEMPLATES ) }
			}
			steps
			{
				echo "${Country} - Checking out ${COUNTRY_SVN_Branch}"
				sh "echo >> ${WORKSPACE}/logs/pipeline.log"
				sh "echo 'Starting '${Country}' Specific Actions -------------------' >> ${WORKSPACE}/logs/pipeline.log"
				sh "echo >> ${WORKSPACE}/logs/pipeline.log"
				sh "echo ${Country}' - Checking out '${COUNTRY_SVN_Branch} >> ${WORKSPACE}/logs/pipeline.log"
				checkout([
					$class: 'SubversionSCM', 
					additionalCredentials: [], 
					excludedCommitMessages: '', 
					excludedRegions: '', 
					excludedRevprop: '', 
					excludedUsers: '', 
					filterChangelog: false, 
					ignoreDirPropChanges: false, 
					includedRegions: '', 
					locations: [[credentialsId: '33092bcd-d979-4279-8540-c137b47a01f4', 
								depthOption: 'infinity', 
								ignoreExternalsOption: true, 
								local: "./svn_src/${Country}", 
								remote: "${COUNTRY_SVN_Branch}" ]], 
					workspaceUpdater: [$class: 'CheckoutUpdater']
				])

			}
		}

		stage("Country - ONLINE - Initialize Aldon Release")
		{
			when 
			{
				expression { return params.ONLINE }
			}                                    
			steps
			{
				echo "${Country} - ONLINE - Initialiting ${Country_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh INIT ald_release=\"${Country_Aldon_Release}::\\\\\\\$UX_APP\" country=${Country} module=ONLINE >> ${WORKSPACE}/logs/pipeline.log"
			}
		}
		
		stage("Country - ONLINE - Aldon Sign On")
		{
			when 
			{
				expression { return params.ONLINE }
			}                                    
			steps
			{
				echo "${Country} - ONLINE - Signing On to Aldon for ${Country_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs: [[password: "${Password}", var: 'Password']]]) 
				{
					sh "${WORKSPACE}/pipeline/pipeline.sh SIGNON ald_user=${Username} ald_scrt=${Password} country=${Country} module=ONLINE run_mode=${Run_Mode} queue_timeout=${Queue_Timeout} >> ${WORKSPACE}/logs/pipeline.log"
				}
			}
		}
		
		stage("Country - ONLINE - Get Latest From Aldon")
		{
			when 
			{
				expression { return params.ONLINE }
			}                                    
			steps
			{
				echo "${Country} - ONLINE - Get Latest From Aldon for ${Country_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh GETLATEST country=${Country} module=ONLINE >> ${WORKSPACE}/logs/pipeline.log"
			}
		}   
		
		stage("Country - ONLINE - Generate Diff Reports")
		{
			when 
			{
				expression { return params.ONLINE }
			}
			steps
			{
				echo "${Country} - ONLINE - Generate Diff Reports"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh GENDIFF country=${Country} module=ONLINE >> ${WORKSPACE}/logs/pipeline.log"
			}
			post
			{
				success
				{
					archiveArtifacts(artifacts: "ald_devenv_root/${Country}/ONLINE/${Country}_*files.txt", allowEmptyArchive: true)
				}
			}
		}
		
		stage("Country - ONLINE - Checkout Changed Objects")
		{
			when 
			{
				expression { return params.ONLINE }
			}                                    
			steps
			{
				echo "${Country} - ONLINE - Checkout Changed Objects From Aldon for ${Country_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh CHECKOUT country=${Country} module=ONLINE ald_task=${Country_Online_Aldon_Task} >> ${WORKSPACE}/logs/pipeline.log"
			}
		}  

		stage("Country - ONLINE - Update Dev Environment")
		{
			when 
			{
				expression { return params.ONLINE }
			}                                    
			steps
			{
				echo "${Country} - ONLINE - Update Dev Environment for ${CORE_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh UPDATEDEVENV country=${Country} module=ONLINE >> ${WORKSPACE}/logs/pipeline.log"
			}
		}  
		
		stage("Country - ONLINE - Add New Objects to Aldon")
		{
			when 
			{
				expression { return params.ONLINE }
			}                                    
			steps
			{
				echo "${Country} - ONLINE - Add New Objects to Aldon for ${Country_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh ADDNEWOBJECTS country=${Country} module=ONLINE ald_task=${Country_Online_Aldon_Task} >> ${WORKSPACE}/logs/pipeline.log"
			}
		}
		
		stage("Country - ONLINE - Mark As Delete from Aldon")
		{
			when 
			{
				allOf
				{
					expression { return params.ONLINE }
					expression { params.Online_Auto_Delete == 'NO' || params.Online_Auto_Delete == 'YES' }
				}
			}
			environment 
			{
				def delobjectsurl = "${env.BUILD_URL}/artifact/ald_devenv_root/${Country}/ONLINE/${Country}_ONLINE_deleted_files.txt"
				def delconfirmation = "YES"
			}
			steps
			{
				script
				{
					if (params.Online_Auto_Delete == 'NO')
					{
						input ( id: 'delconfirmation', message: "${Country}:ONLINE - Proceed with mark as delete [YES/NO]?", parameters: [choice(choices: 'NO\nYES', description: "Deleted objects:\n${delobjectsurl}", name: 'ONLINE_MARK_AS_DELETE')])
					}						
					
					if (delconfirmation == 'YES')
					{
						echo "${Country} - ONLINE - Marking Objects as Deleted in Aldon for ${Country_Aldon_Release}::\\\$UX_APP"
						sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
						sh "${WORKSPACE}/pipeline/pipeline.sh MARKASDELETE country=${Country} module=ONLINE ald_task=${Country_Online_Aldon_Task} >> ${WORKSPACE}/logs/pipeline.log"
					}
					else
					{
						echo "${Country} - ONLINE - Skipping Mark As Delete as NO Selected"
						sh "echo \$(date)'- INFO ['${Country}'] [ONLINE] [ald_mark_for_delete]: Skipping Mark As Delete as NO Selected...' >> ${WORKSPACE}/logs/pipeline.log"
					}
					
				}
			}
		}		

		stage("Country - ONLINE - Check-in Objects to Aldon")
		{
			when 
			{
				expression { return params.ONLINE }
			}                                    
			steps
			{
				echo "${Country} - ONLINE - Check-in Objects to Aldon for ${Country_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh CHECKIN country=${Country} module=ONLINE >> ${WORKSPACE}/logs/pipeline.log"
			}
		}
		
		stage("Country - ONLINE - Aldon Sign Off and Shutdown")
		{
			when 
			{
				expression { return params.ONLINE }
			}                                    
			steps
			{
				echo "${Country} - ONLINE - Sign Off and Shutdown From Aldon for ${Country_Aldon_Release}::\\\$UX_APP"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh SHUTDOWN >> ${WORKSPACE}/logs/pipeline.log"
			}
		}

		stage("Country - SCRIPTS - Initialize Aldon Release")
		{
			when 
			{
				expression { return params.SCRIPTS }
			}                                    
			steps
			{
				echo "${Country} - SCRIPTS - Initialiting ${Country_Aldon_Release}::\\\$UX_SCRIPTS"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh INIT ald_release=\"${Country_Aldon_Release}::\\\\\\\$UX_SCRIPTS\" country=${Country} module=SCRIPTS >> ${WORKSPACE}/logs/pipeline.log"
			}
		}
		
		stage("Country - SCRIPTS - Aldon Sign On")
		{
			when 
			{
				expression { return params.SCRIPTS }
			}                                    
			steps
			{
				echo "${Country} - SCRIPTS - Signing On to Aldon for ${Country_Aldon_Release}::\\\$UX_SCRIPTS"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs: [[password: "${Password}", var: 'Password']]]) 
				{
					sh "${WORKSPACE}/pipeline/pipeline.sh SIGNON ald_user=${Username} ald_scrt=${Password} country=${Country} module=SCRIPTS run_mode=${Run_Mode} queue_timeout=${Queue_Timeout} >> ${WORKSPACE}/logs/pipeline.log"
				}
			}
		}
		
		stage("Country - SCRIPTS - Get Latest From Aldon")
		{
			when 
			{
				expression { return params.SCRIPTS }
			}                                    
			steps
			{
				echo "${Country} - SCRIPTS - Get Latest From Aldon for ${Country_Aldon_Release}::\\\$UX_SCRIPTS"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh GETLATEST country=${Country} module=SCRIPTS >> ${WORKSPACE}/logs/pipeline.log"
			}
		}   
		
		stage("Country - SCRIPTS - Generate Diff Reports")
		{
			when 
			{
				expression { return params.SCRIPTS }
			}
			steps
			{
				echo "${Country} - SCRIPTS - Generate Diff Reports"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh GENDIFF country=${Country} module=SCRIPTS >> ${WORKSPACE}/logs/pipeline.log"
			}
			post
			{
				success
				{
					archiveArtifacts(artifacts: "ald_devenv_root/${Country}/SCRIPTS/${Country}_*files.txt", allowEmptyArchive: true)
				}
			}
		}
		
		stage("Country - SCRIPTS - Checkout Changed Objects")
		{
			when 
			{
				expression { return params.SCRIPTS }
			}                                    
			steps
			{
				echo "${Country} - SCRIPTS - Checkout Changed Objects From Aldon for ${Country_Aldon_Release}::\\\$UX_SCRIPTS"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh CHECKOUT country=${Country} module=SCRIPTS ald_task=${Country_Scripts_Aldon_Task} >> ${WORKSPACE}/logs/pipeline.log"
			}
		}  

		stage("Country - SCRIPTS - Update Dev Environment")
		{
			when 
			{
				expression { return params.SCRIPTS }
			}                                    
			steps
			{
				echo "${Country} - SCRIPTS - Update Dev Environment for ${Country_Aldon_Release}::\\\$UX_SCRIPTS"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh UPDATEDEVENV country=${Country} module=SCRIPTS >> ${WORKSPACE}/logs/pipeline.log"
			}
		} 
		
		stage("Country - SCRIPTS - Add New Objects to Aldon")
		{
			when 
			{
				expression { return params.SCRIPTS }
			}                                    
			steps
			{
				echo "${Country} - SCRIPTS - Add New Objects to Aldon for ${Country_Aldon_Release}::\\\$UX_SCRIPTS"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh ADDNEWOBJECTS country=${Country} module=SCRIPTS ald_task=${Country_Scripts_Aldon_Task} >> ${WORKSPACE}/logs/pipeline.log"
			}
		}
		
		stage("Country - SCRIPTS - Mark As Delete from Aldon")
		{
			when 
			{
				allOf
				{
					expression { return params.SCRIPTS }
					expression { params.Scripts_Auto_Delete == 'NO' || params.Scripts_Auto_Delete == 'YES' }
				}
			}
			environment 
			{
				def delobjectsurl = "${env.BUILD_URL}/artifact/ald_devenv_root/${Country}/SCRIPTS/${Country}_SCRIPTS_deleted_files.txt"
				def delconfirmation = "YES"
			}
			steps
			{
				script
				{
					if (params.Scripts_Auto_Delete == 'NO')
					{
						input ( id: 'delconfirmation', message: "${Country}:SCRIPTS - Proceed with mark as delete [YES/NO]?", parameters: [choice(choices: 'NO\nYES', description: "Deleted objects:\n${delobjectsurl}", name: 'SCRIPTS_MARK_AS_DELETE')])
					}						
					
					if (delconfirmation == 'YES')
					{
						echo "${Country} - SCRIPTS - Marking Objects as Deleted in Aldon for ${Country_Aldon_Release}::\\\$UX_SCRIPTS"
						sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
						sh "${WORKSPACE}/pipeline/pipeline.sh MARKASDELETE country=${Country} module=SCRIPTS ald_task=${Country_Scripts_Aldon_Task} >> ${WORKSPACE}/logs/pipeline.log"
					}
					else
					{
						echo "${Country} - SCRIPTS - Skipping Mark As Delete as NO Selected"
						sh "echo \$(date)'- INFO ['${Country}'] [SCRIPTS] [ald_mark_for_delete]: Skipping Mark As Delete as NO Selected...' >> ${WORKSPACE}/logs/pipeline.log"
					}
					
				}
			}
		}		

		stage("Country - SCRIPTS - Check-in Objects to Aldon")
		{
			when 
			{
				expression { return params.SCRIPTS }
			}                                    
			steps
			{
				echo "${Country} - SCRIPTS - Check-in Objects to Aldon for ${Country_Aldon_Release}::\\\$UX_SCRIPTS"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh CHECKIN country=${Country} module=SCRIPTS >> ${WORKSPACE}/logs/pipeline.log"
			}
		}
		
		stage("Country - SCRIPTS - Aldon Sign Off and Shutdown")
		{
			when 
			{
				expression { return params.SCRIPTS }
			}                                    
			steps
			{
				echo "${Country} - SCRIPTS - Sign Off and Shutdown From Aldon for ${Country_Aldon_Release}::\\\$UX_SCRIPTS"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh SHUTDOWN >> ${WORKSPACE}/logs/pipeline.log"
			}
		} 
/*
		stage("Country - TEMPLATES - Initialize Aldon Release")
		{
			when 
			{
				expression { return params.TEMPLATES }
			}
			steps
			{
				echo "${Country} - TEMPLATES - Initialiting ${Country_Aldon_Release}::\\\$UX_TEMPLATES"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh INIT ald_release=\"${Country_Aldon_Release}::\\\\\\\$UX_TEMPLATES\" country=${Country} module=TEMPLATES >> ${WORKSPACE}/logs/pipeline.log"
			}
		}
		
		stage("Country - TEMPLATES - Aldon Sign On")
		{
			when 
			{
				expression { return params.TEMPLATES }
			}
			steps
			{
				echo "${Country} - TEMPLATES - Signing On to Aldon for ${Country_Aldon_Release}::\\\$UX_TEMPLATES"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs: [[password: "${Password}", var: 'Password']]]) 
				{
					sh "${WORKSPACE}/pipeline/pipeline.sh SIGNON ald_user=${Username} ald_scrt=${Password} country=${Country} module=TEMPLATES run_mode=${Run_Mode} queue_timeout=${Queue_Timeout} >> ${WORKSPACE}/logs/pipeline.log"
				}
			}
		}
		
		stage("Country - TEMPLATES - Get Latest From Aldon")
		{
			when 
			{
				expression { return params.TEMPLATES }
			}
			steps
			{
				echo "${Country} - TEMPLATES - Get Latest From Aldon for ${Country_Aldon_Release}::\\\$UX_TEMPLATES"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh GETLATEST country=${Country} module=TEMPLATES >> ${WORKSPACE}/logs/pipeline.log"
			}
		}   
		
		stage("Country - TEMPLATES - Generate Diff Reports")
		{
			when 
			{
				expression { return params.TEMPLATES }
			}
			steps
			{
				echo "${Country} - TEMPLATES - Generate Diff Reports"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh GENDIFF country=${Country} module=TEMPLATES >> ${WORKSPACE}/logs/pipeline.log"
			}
			post
			{
				success
				{
					archiveArtifacts(artifacts: "ald_devenv_root/${Country}/TEMPLATES/${Country}_*files.txt", allowEmptyArchive: true)
				}
			}
		}
		
		stage("Country - TEMPLATES - Checkout Changed Objects")
		{
			when 
			{
				expression { return params.TEMPLATES }
			}
			steps
			{
				echo "${Country} - TEMPLATES - Checkout Changed Objects From Aldon for ${Country_Aldon_Release}::\\\$UX_TEMPLATES"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh CHECKOUT country=${Country} module=TEMPLATES ald_task=${Country_Templates_Aldon_Task} >> ${WORKSPACE}/logs/pipeline.log"
			}
		}  

		stage("Country - TEMPLATES - Update Dev Environment")
		{
			when 
			{
				expression { return params.TEMPLATES }
			}
			steps
			{
				echo "${Country} - TEMPLATES - Update Dev Environment for ${Country_Aldon_Release}::\\\$UX_TEMPLATES"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh UPDATEDEVENV country=${Country} module=TEMPLATES >> ${WORKSPACE}/logs/pipeline.log"
			}
		} 
		
		stage("Country - TEMPLATES - Add New Objects to Aldon")
		{
			when 
			{
				expression { return params.TEMPLATES }
			}
			steps
			{
				echo "${Country} - TEMPLATES - Add New Objects to Aldon for ${Country_Aldon_Release}::\\\$UX_TEMPLATES"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh ADDNEWOBJECTS country=${Country} module=TEMPLATES ald_task=${Country_Templates_Aldon_Task} >> ${WORKSPACE}/logs/pipeline.log"
			}
		}
		
		stage("Country - TEMPLATES - Mark As Delete from Aldon")
		{
			when 
			{
				allOf
				{
					expression { return params.TEMPLATES }
					expression { params.Templates_Auto_Delete == 'NO' || params.Templates_Auto_Delete == 'YES' }
				}
			}
			environment 
			{
				def delobjectsurl = "${env.BUILD_URL}/artifact/ald_devenv_root/${Country}/TEMPLATES/${Country}_TEMPLATES_deleted_files.txt"
				def delconfirmation = "YES"
			}
			steps
			{
				script
				{
					if (params.Templates_Auto_Delete == 'NO')
					{
						input ( id: 'delconfirmation', message: "${Country}:TEMPLATES - Proceed with mark as delete [YES/NO]?", parameters: [choice(choices: 'NO\nYES', description: "Deleted objects:\n${delobjectsurl}", name: 'TEMPLATES_MARK_AS_DELETE')])
					}
					
					if (delconfirmation == 'YES')
					{
						echo "${Country} - TEMPLATES - Marking Objects as Deleted in Aldon for ${Country_Aldon_Release}::\\\$UX_TEMPLATES"
						sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
						sh "${WORKSPACE}/pipeline/pipeline.sh MARKASDELETE country=${Country} module=TEMPLATES ald_task=${Country_Templates_Aldon_Task} >> ${WORKSPACE}/logs/pipeline.log"
					}
					else
					{
						echo "${Country} - TEMPLATES - Skipping Mark As Delete as NO Selected"
						sh "echo \$(date)'- INFO ['${Country}'] [TEMPLATES] [ald_mark_for_delete]: Skipping Mark As Delete as NO Selected...' >> ${WORKSPACE}/logs/pipeline.log"
					}
					
				}
			}
		}		

		stage("Country - TEMPLATES - Check-in Objects to Aldon")
		{
			when 
			{
				expression { return params.TEMPLATES }
			}
			steps
			{
				echo "${Country} - TEMPLATES - Check-in Objects to Aldon for ${Country_Aldon_Release}::\\\$UX_TEMPLATES"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh CHECKIN country=${Country} module=TEMPLATES >> ${WORKSPACE}/logs/pipeline.log"
			}
		}
		
		stage("Country - TEMPLATES - Aldon Sign Off and Shutdown")
		{
			when 
			{
				expression { return params.TEMPLATES }
			}
			steps
			{
				echo "${Country} - TEMPLATES - Sign Off and Shutdown From Aldon for ${Country_Aldon_Release}::\\\$UX_TEMPLATES"
				sh "chmod 755 ${WORKSPACE}/pipeline/pipeline.sh"
				sh "${WORKSPACE}/pipeline/pipeline.sh SHUTDOWN >> ${WORKSPACE}/logs/pipeline.log"
			}
		}*/
	}
	
	post
	{
		always 
		{
			archiveArtifacts(artifacts: "logs/pipeline.log", allowEmptyArchive: true)
		}
	}
}

