// load shared libraries
@Library('jenkins_ss_shared') _

pipeline
{
	agent {label 'LX-MASTER'}
	parameters 
	{
		// get Core drop version
		string(defaultValue: '2.0.1b', description: 'Enter CORE Version', name: 'CORE_Version')
		string(defaultValue: '20180626_191936', description: 'Enter CORE Code Drop Version', name: 'CORE_Code_Drop_Version')
		booleanParam(defaultValue: true, description: 'Select to enable CORE build', name: 'CORE')
		// get Country drop version
		string(defaultValue: 'ID', description: 'Select Country', name: 'Country')
		string(defaultValue: '1.0', description: 'Enter UOBI Version', name: 'Country_Version')
		string(defaultValue: '20180626_192142', description: 'Enter UOBI Code Drop Version', name: 'Country_Code_Drop_Version')
		booleanParam(defaultValue: true, description: 'Select to enable country ONLINE build', name: 'COUNTRY_Online')
		booleanParam(defaultValue: true, description: 'Select to enable country BATCH build', name: 'COUNTRY_Batch')
		booleanParam(defaultValue: true, description: 'Select to enable country REPORTS build', name: 'COUNTRY_Reports')
		booleanParam(defaultValue: true, description: 'Select to enable country SCRIPTS(Bin/CD) build', name: 'COUNTRY_Scripts')
		booleanParam(defaultValue: true, description: 'Select to enable country TEMPLATES build', name: 'COUNTRY_Templates')
		// get SIT env
		string(defaultValue: 'sit3', description: 'Enter Country SIT Environment to deploy', name: 'SIT_Environment')
	}

	environment 
	{
		// generate build 
		def build_version = sh ( script: 'date +%d%m%Y_%H%M%S',	returnStdout: true ).trim()
		// define download path
		def download_dir = "${WORKSPACE}/download"
		// define CORE code drop file
		def core_code_drop_zip = "${CORE_Version}-${CORE_Code_Drop_Version}.zip"
		// define Country code drop file
		def country_code_drop_zip = "${Country_Version}-${Country_Code_Drop_Version}.zip"
		// set country build
		def COUNTRY_Build = expression { params.COUNTRY_Online || params.COUNTRY_Batch || params.COUNTRY_Reports || params.COUNTRY_Scripts || params.COUNTRY_Templates }
	}

	stages
	{
		
		stage("[Master] Initialize Jenkins Environment")	
		{
			agent {label 'LX-MASTER'}
			steps
			{
				sh "if [ -d ${WORKSPACE}/logs ]; then rm -rf ${WORKSPACE}/logs/*; else mkdir -p ${WORKSPACE}/logs; fi"
				sh "if [ -d ${env.download_dir} ]; then rm -rf ${env.download_dir}/*; else mkdir -p ${env.download_dir}; fi"
				sh "echo '------------------------------------------------' > ${WORKSPACE}/logs/pipeline.log"
				sh "echo 'Jenkins pipeline started at : '\$(date) >> ${WORKSPACE}/logs/pipeline.log"
				sh "echo 'Build Version : '${env.build_version} >> ${WORKSPACE}/logs/pipeline.log"
				sh "echo '------------------------------------------------' >> ${WORKSPACE}/logs/pipeline.log"
				// check whether anything selected
				script
				{
					if(!params.CORE && !env.COUNTRY_Build)
					{
						sh "echo 'ERROR: Build aborted as no selected modules' >> ${WORKSPACE}/logs/pipeline.log"
						error("ERROR: No module selected. Nothing to do...")
						currentBuild.rawBuild.result = Result.ABORTED
					}

				}
			
			}
		}
		
		stage("[Build-Slave] Initialize Jenkins Environment")	
		{
			agent {label 'CLSTSG80-AIX'}
			steps
			{
				sh "if [ -d ${WORKSPACE}/logs ]; then rm -rf ${WORKSPACE}/logs/*; else mkdir -p ${WORKSPACE}/logs; fi"
				sh "if [ -d ${env.download_dir} ]; then rm -rf ${env.download_dir}/*; else mkdir -p ${env.download_dir}; fi"
				sh "echo '------------------------------------------------' > ${WORKSPACE}/logs/pipeline.log"
				sh "echo 'Jenkins pipeline started at : '\$(date) >> ${WORKSPACE}/logs/pipeline.log"
				sh "echo 'Build Version : '${env.build_version} >> ${WORKSPACE}/logs/pipeline.log"
				sh "echo '------------------------------------------------' >> ${WORKSPACE}/logs/pipeline.log"			
			}
		}

		stage("[Master] Download Source Drops") 
		{
			agent {label 'LX-MASTER'}
			steps
			{
				script
				{
					if (params.CORE)
					{	
						echo "CORE - Downloading code drop ${env.core_code_drop_zip}"
						sh "echo 'CORE - Downloading code drop '${env.core_code_drop_zip}  >> ${WORKSPACE}/logs/pipeline.log"
						downloadCodeDrop(downloadDir: "${env.download_dir}", module: 'CORE', moduleVersion: "${CORE_Version}", dropVersion: "${CORE_Code_Drop_Version}")
						//stash includes: "${WORKSPACE}/download/${core_code_drop_zip}", name: 'CORE-ZIP'
					}
					if (env.COUNTRY_Build)
					{
						echo "${Country} - Downloading code drop ${env.country_code_drop_zip}"
						sh "echo ${Country}' - Downloading code drop '${env.country_code_drop_zip}  >> ${WORKSPACE}/logs/pipeline.log"
						downloadCodeDrop(downloadDir: "${env.download_dir}", module: "${Country}", moduleVersion: "${Country_Version}", dropVersion: "${Country_Code_Drop_Version}")
					}
				}
			}
		}

		stage("[Master] Upload Source Drops to Build-Slave") 
		{
			agent {label 'LX-MASTER'}
			steps
			{
				script
				{
					echo "Preparing Slave CLSTSG80 to recieve code drops"
					sh "echo 'Preparing Slave CLSTSG80 to recieve code drops' >> ${WORKSPACE}/logs/pipeline.log"
					prepareSlaveDir(slave: "CLSTSG80", destinationDir: "download", logFile: "${WORKSPACE}/logs/pipeline.log")

					if (params.CORE)
					{
						echo "CORE - Uploading code drop ${env.core_code_drop_zip}"
						sh "echo 'CORE - Uploading code drop '${env.core_code_drop_zip}  >> ${WORKSPACE}/logs/pipeline.log"
						uploadToSlave(slave: "CLSTSG80", sourceDir: "${env.download_dir}", file: "${env.core_code_drop_zip}", destinationDir: "download", logFile: "${WORKSPACE}/logs/pipeline.log")
					}

					if (env.COUNTRY_Build)
					{
						echo "${Country} - Uploading code drop ${env.country_code_drop_zip}"
						sh "echo ${Country}' - Uploading code drop '${env.country_code_drop_zip}  >> ${WORKSPACE}/logs/pipeline.log"
						uploadToSlave(slave: "CLSTSG80", sourceDir: "${env.download_dir}", file: "${env.country_code_drop_zip}", destinationDir: 'download', logFile: "${WORKSPACE}/logs/pipeline.log")
					}
				}
			}
		}

		stage("[Master] Prepare Sources to check-in to BB")
		{		
			agent {label 'LX-MASTER'}
			steps
			{
				script
				{
					echo "TO-DO"
				}
			}
		}

		stage("[Master] Check-in to BB")
		{		
			agent {label 'LX-MASTER'}
			steps
			{
				script
				{
					echo "TO-DO"
				}
			}
		}

		stage("[Build-Slave] Prepare Sources")
		{		
			agent {label 'CLSTSG80-AIX'}
			steps
			{
				script
				{
					if (params.CORE)
					{
						//unstash 'CORE-ZIP'
						sh "if [ -d ${WORKSPACE}/src_CORE ]; then rm -rf ${WORKSPACE}/src_CORE/*; else mkdir -p ${WORKSPACE}/src_CORE; fi"
						sh "echo 'CORE - Extracting code drop '${env.core_code_drop_zip}  >> ${WORKSPACE}/logs/pipeline.log"
						sh "cd ${WORKSPACE}/src_CORE; unzip ${WORKSPACE}/download/${core_code_drop_zip} >> ${WORKSPACE}/logs/pipeline.log"
					}

					if (env.COUNTRY_Build)
					{
						sh "if [ -d ${WORKSPACE}/src_${env.Country} ]; then rm -rf ${WORKSPACE}/src_${env.Country}/*; else mkdir -p ${WORKSPACE}/src_${env.Country}; fi"
						sh "echo ${env.Country}' - Extracting code drop '${env.country_code_drop_zip}  >> ${WORKSPACE}/logs/pipeline.log"
						sh "cd ${WORKSPACE}/src_${env.Country}; unzip ${WORKSPACE}/download/${country_code_drop_zip} >> ${WORKSPACE}/logs/pipeline.log"
					}
				}
			}
		}

		stage("[Build-Slave] CORE - Compile Sources")
		{
			when 
			{
				expression { return params.CORE }
			}                                    
			agent {label 'CLSTSG80-AIX'}
			steps
			{
				script
				{
					echo "CORE - Prepare Environment"
					//prepareSSCompileEnv( baseModule: 'CORE', logFile: "${WORKSPACE}/logs/pipeline.log" )
					echo "CORE - Compie and Build"
					//compileSSSources( baseModule: 'CORE', logFile: "${WORKSPACE}/logs/pipeline.log" )
				}
				
			}
		}

		stage("[Build-Slave] Country - Compile Sources")
		{
			when 
			{
				expression { return env.COUNTRY_Build }
			}                                    
			agent {label 'CLSTSG80-AIX'}
			steps
			{
				script
				{
					echo "${env.Country} - Prepare Environment"
					//prepareSSCompileEnv( baseModule: "${env.Country}", logFile: "${WORKSPACE}/logs/pipeline.log" )
					echo "${env.Country} - Compie and Build"
					//compileSSSources( baseModule: "${env.Country}", logFile: "${WORKSPACE}/logs/pipeline.log" )
				}
				
			}
		}  


	}
	
	
	post
	{
		always
		{
			node ('LX-MASTER' && 'CLSTSG80-AIX')
			{
				step (archiveArtifacts(artifacts: "logs/pipeline.log", allowEmptyArchive: true))
			}
		}
	}
}

