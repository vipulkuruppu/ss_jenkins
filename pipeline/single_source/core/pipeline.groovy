pipeline
{
	agent any
	parameters 
	{
		string(defaultValue: 'branches/devmt/CORE_QR1_2018', description: 'Enter Relative CORE SVN Path to branch root (Note: https://lxclstsgv99.sg.uobnet.com:9999/svn/PLCE_SS/Core/ will be added automatically)', name: 'CORE_SVN_Branch')
		choice(choices: 'BASE\nQR\nP1\nP2\nMR', description: 'Select CORE Aldon Release', name: 'CORE_Aldon_Release')
		string(defaultValue: 'core_task', description: 'CORE Aldon Task Assembly', name: 'CORE_Aldon_Task')
		choice(choices: 'SKIP\nNO\nYES', description: 'Proceed to mark as delete automatically in CORE?', name: 'CORE_Auto_Delete')

		string(defaultValue: 'aldonusername', description: 'Enter Aldon Username', name: 'Username')
		password(defaultValue: '12345', description: 'Enter Aldon Password', name: 'Password')
		choice(choices: 'QUEUED\nFORCEQUEUED\nFORCE', description: 'Select run option. FORCE=Force run, QUEUED=Queue until timeout if another build is running, FORCEQUEUED=Wait for timeout and force run', name: 'Run_Mode')
		choice(choices: '10\n20\n30\n40\n50\n60\n70\n80\n90', description: 'Select duration (in minutes) to queue. No effect if FORCE mode is selected', name: 'Queue_Timeout')
		booleanParam(defaultValue: false, description: 'Select this option to stop at diff generation', name: 'Only_Generate_Reports')

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
			steps
			{
				echo "CORE - Checking out https://lxclstsgv99.sg.uobnet.com:9999/svn/PLCE_SS/Core/${CORE_SVN_Branch}"
				sh "echo 'CORE - Checking out https://lxclstsgv99.sg.uobnet.com:9999/svn/PLCE_SS/Core/'${CORE_SVN_Branch} >> ${WORKSPACE}/logs/pipeline.log"
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
								remote: "https://lxclstsgv99.sg.uobnet.com:9999/svn/PLCE_SS/Core/${CORE_SVN_Branch}" ]], 
					workspaceUpdater: [$class: 'CheckoutUpdater']
				])

			}
		}

		stage("CORE - Initialize Aldon Release")
		{
			environment 
			{
				def ALD_RELEASE = ""
			}			
			steps
			{
				script
				{
					if (params.CORE_Aldon_Release == 'BASE')
					{
						ALD_RELEASE = "UOB/CLR/CLR(CORE)"
					}
					else
					{
						ALD_RELEASE = "UOB/CLR/CLR(CORE_${params.CORE_Aldon_Release})"
					}
					echo "CORE - Initialiting ${ALD_RELEASE}::\\\$UX_APP"
					sh "chmod 755 ${WORKSPACE}/pipeline/shell/pipeline.sh"
					sh "${WORKSPACE}/pipeline/shell/pipeline.sh INIT ald_release=\"${ALD_RELEASE}::\\\\\\\$UX_APP\" country=CORE module=ONLINE >> ${WORKSPACE}/logs/pipeline.log"
				}
			}
		}

		stage("CORE - Aldon Sign On")
		{
			steps
			{
				echo "CORE - Signing On to Aldon"
				sh "chmod 755 ${WORKSPACE}/pipeline/shell/pipeline.sh"
				wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs: [[password: "${Password}", var: 'Password']]]) 
				{
					sh "${WORKSPACE}/pipeline/shell/pipeline.sh SIGNON ald_user=${Username} ald_scrt=${Password} country=CORE module=ONLINE run_mode=${Run_Mode} queue_timeout=${Queue_Timeout} >> ${WORKSPACE}/logs/pipeline.log"
				}
			}
		}

		stage("CORE - Set Development Env")
		{
			steps
			{
				echo "CORE - ONLINE - Set Development Env"
				sh "chmod 755 ${WORKSPACE}/pipeline/shell/pipeline.sh"
				sh "${WORKSPACE}/pipeline/shell/pipeline.sh SETDEVENV country=CORE module=ONLINE >> ${WORKSPACE}/logs/pipeline.log"
			}
		}  

		stage("CORE - Get Latest From Aldon")
		{
			steps
			{
				echo "CORE - Get Latest From Aldon"
				sh "chmod 755 ${WORKSPACE}/pipeline/shell/pipeline.sh"
				sh "${WORKSPACE}/pipeline/shell/pipeline.sh GETLATEST country=CORE module=ONLINE >> ${WORKSPACE}/logs/pipeline.log"
			}
		}

		stage("CORE - Generate Diff Reports")
		{
			steps
			{
				echo "CORE - Generate Diff Reports"
				sh "chmod 755 ${WORKSPACE}/pipeline/shell/pipeline.sh"
				sh "${WORKSPACE}/pipeline/shell/pipeline.sh GENDIFF country=CORE module=ONLINE >> ${WORKSPACE}/logs/pipeline.log"
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
				expression { return ! params.Only_Generate_Reports }
			}
			steps
			{
				echo "CORE - Checkout Changed Objects From Aldon"
				sh "chmod 755 ${WORKSPACE}/pipeline/shell/pipeline.sh"
				sh "${WORKSPACE}/pipeline/shell/pipeline.sh CHECKOUT country=CORE module=ONLINE ald_task=${CORE_Aldon_Task} >> ${WORKSPACE}/logs/pipeline.log"
			}
		}

		stage("CORE - Update Dev Environment")
		{
			when
			{
				expression { return ! params.Only_Generate_Reports }
			}
			steps
			{
				echo "CORE - Update Dev Environment"
				sh "chmod 755 ${WORKSPACE}/pipeline/shell/pipeline.sh"
				sh "${WORKSPACE}/pipeline/shell/pipeline.sh UPDATEDEVENV country=CORE module=ONLINE >> ${WORKSPACE}/logs/pipeline.log"
			}
		}

		stage("CORE - Add New Objects to Aldon")
		{
			when
			{
				expression { return ! params.Only_Generate_Reports }
			}
			steps
			{
				echo "CORE - Add New Objects to Aldon"
				sh "chmod 755 ${WORKSPACE}/pipeline/shell/pipeline.sh"
				sh "${WORKSPACE}/pipeline/shell/pipeline.sh ADDNEWOBJECTS country=CORE module=ONLINE ald_task=${CORE_Aldon_Task} >> ${WORKSPACE}/logs/pipeline.log"
			}
		}

		stage("CORE - Mark As Delete from Aldon")
		{
			when 
			{
				allOf
				{
					expression { params.CORE_Auto_Delete == 'NO' || params.CORE_Auto_Delete == 'YES' }
					expression { return ! params.Only_Generate_Reports }
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
						echo "CORE - Marking Objects as Deleted in Aldon"
						sh "chmod 755 ${WORKSPACE}/pipeline/shell/pipeline.sh"
						sh "${WORKSPACE}/pipeline/shell/pipeline.sh MARKASDELETE country=CORE module=ONLINE ald_task=${CORE_Aldon_Task} >> ${WORKSPACE}/logs/pipeline.log"
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
				expression { return ! params.Only_Generate_Reports }
			}
			steps
			{
				echo "CORE - Check-in Objects to Aldon"
				sh "chmod 755 ${WORKSPACE}/pipeline/shell/pipeline.sh"
				sh "${WORKSPACE}/pipeline/shell/pipeline.sh CHECKIN country=CORE module=ONLINE >> ${WORKSPACE}/logs/pipeline.log"
			}
		}
		
		stage("CORE - Aldon Sign Off and Shutdown")
		{                                   
			steps
			{
				echo "CORE - Sign Off and Shutdown From Aldon"
				sh "chmod 755 ${WORKSPACE}/pipeline/shell/pipeline.sh"
				sh "${WORKSPACE}/pipeline/shell/pipeline.sh SHUTDOWN >> ${WORKSPACE}/logs/pipeline.log"
			}
		}
	}
	
	post
	{
		always 
		{
			archiveArtifacts(artifacts: "logs/pipeline.log", allowEmptyArchive: true)
		}
	}
}

