@ECHO OFF
::::Version: CB_10.1.2
SETLOCAL ENABLEEXTENSIONS
setlocal enabledelayedexpansion
set STARTTIME=%TIME%
::################### User variables ###################
REM ::set SYNERGY_HOME="C:\apache-tomcat-8.0.46\webapps\cloudblue"
REM ::set CATALINA_HOME="C:\apache-tomcat-8.0.46"
::##############################################################
::################### Initializing variables ###################
set "Version=CB_10.1.2"
set current_dir=%cd%
set Compare_War_location=%CATALINA_HOME%\Compare_War
set BACKUP_DIRECTORY_NAME=%date:~10,4%_%date:~4,2%_%date:~7,2%_%time:~0,2%_%time:~3,2%_%time:~6,2%_%time:~9,2%
set Backup_location=%CATALINA_HOME%\BACKUP\current_backup
set compare_list=plugins,resources,lib,i18n
::##############################################################
echo "***********************************************************************************************"
if "%~1"=="" (
    echo No parameters have been provided.
	echo Provide Order.zip Location. i.e: D:\CB_10.0\ISO\Portal\CB_10.0\webapps
	echo "Command to execute:> Deploy_Windows.bat "D:\CB_10.0\ISO\Portal\CB_10.0\webapps" >> LogCloudBlue.txt"
	goto :EOF
) else if "%~1"=="-v" (
	echo Script Version: %Version%
	goto :EOF
)

set order_location=%1%
echo order_location: %order_location%
if exist %order_location%\order.zip (
	echo Order.zip found.
)else (
	echo Order.zip not found in location: %order_location%
	goto :EOF
)

::Checking Unzip is working or not
REM unzip /? 2> nul
REM if NOT %ERRORLEVEL% == 0 (
	REM echo "Unzip is not working, please install unzip first"
	REM goto :EOF
REM )
::##############################################################
::#### Values Used for Measuring the state of deployment #######
:: * = File Not Exist, not upgraded
:: 0 = Initial Stage, not upgraded
:: 1 = Backup Completed, but deployment failed need to restore first
:: 2 = Deployment Completed, upgraded successfully
::##############################################################

REM ::######### Measuring the state of deployment ############
REM if exist "%CATALINA_HOME%\deployment_status.txt" (
	REM for /f "tokens=1 delims= " %%a in (%CATALINA_HOME%\deployment_status.txt) do (
		REM set ds_value=%%a
	REM )
REM )else (
	REM echo 0 > "%CATALINA_HOME%\deployment_status.txt"
	REM for /f "tokens=1 delims= " %%a in (%CATALINA_HOME%\deployment_status.txt) do (
		REM set ds_value=%%a
	REM )
REM )
REM ::###### Deployment state #######
	REM 2>NUL CALL :STATE_%ds_value% # jump to :STATE_0, :STATE_1, etc.
	REM EXIT /B
	REM :STATE_0
		REM echo =================================================
		REM echo Deployment Status: %ds_value%, Initial Stage, not upgraded	 
		REM echo =================================================
		REM GOTO :StartDeployment
	  
	REM :STATE_1 
		REM echo ============================================================================================
		REM echo Deployment Status: %ds_value%, Backup Completed, but previous deployment failed need to restore first	 
		REM echo ============================================================================================
		REM GOTO :StartDeployment
		
	REM :STATE_2 
		REM echo ===========================================================================
		REM echo Deployment Status: %ds_value%, Previous Deployment Completed, upgraded successfully	 
		REM echo ===========================================================================
		REM GOTO :StartDeployment
REM ::##############################################################

:StartDeployment
::###### Taking Decision {Fresh, Upgrade:DF2War, War2War} #######
IF DEFINED SYNERGY_HOME (
	IF DEFINED CATALINA_HOME (		 
		if exist %CATALINA_HOME%\ESCM-DataFiles (
			if exist %CATALINA_HOME%\ESCM-DataFiles\branding (
			::::=============ESCM-DataFiles to WAR Upgrade::=============
					set flag=2
			)Else (
			::::=============WAR to WAR Upgrade::=============
					set flag=3
			)			
		)Else (
			::=============Fresh installation=============
			set flag=1
		)	
	)ELSE (
		ECHO CATALINA_HOME is NOT defined please install tomcat first 
		Goto :EOF			
	)
)ELSE (
	ECHO SYNERGY_HOME is NOT defined Configure SYNERGY_HOME first. 
	Goto :EOF
)

::##############################################################
echo Flag Value: %flag%
if exist "%Compare_War_location%" rd "%Compare_War_location%" /s /q
::##############################################################

::############ Get APP Name from SYNERGY_HOME ##########
for %%f in (%SYNERGY_HOME%) do set appname=%%~nxf
echo APP Name: %appname%
::##############################################################

::###### Deploying according to flag value #######

	2>NUL CALL :CASE_%flag% # jump to :CASE_1, :CASE_2, etc.
	EXIT /B

	:CASE_1
		echo ============================ 
		echo =    Fresh Installation    =	 
		echo ============================
		call :extractorder
		call :fresh
		GOTO :END
	  
	:CASE_2 
		echo ======================================= 
		echo =    ESCM-DataFiles to WAR Upgrade    =	 
		echo =======================================
		REM if "%ds_value%" == "1" (
			REM call :error_restore
		REM )
		call :backup
		REM echo 1 > "%CATALINA_HOME%\deployment_status.txt"
		call :extractorder
		call :new_war_copy
		call :df_copy
		call :compare_folder "%Compare_War_location%\DF_WAR_Struct", "%Compare_War_location%\new_war"
		call :rm_df
		REM echo 2 > "%CATALINA_HOME%\deployment_status.txt"
		GOTO :END
		
	:CASE_3 
		echo ============================
		echo =    WAR to WAR Upgrade    =	 
		echo ============================
		REM if "%ds_value%" == "1" (
			REM call :error_restore
		REM )
		REM call :backup
		REM echo 1 > "%CATALINA_HOME%\deployment_status.txt"
		call :extractorder
		REM call :new_war_copy
		REM call :old_war_copy
		REM call :compare_folder "%Compare_War_location%\old_war", "%Compare_War_location%\new_war"
		REM echo 2 > "%CATALINA_HOME%\deployment_status.txt"
		call :war2war_upgrade
		GOTO :END

::##############################################################

::****************** Extracting WAR Function *********************#
:extractorder
	echo "Extracting Order.zip"
	echo WAR Location: %current_dir%
	unzip -o %order_location%/order.zip -d "%current_dir%"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] WAR Unzip failed!"
		exit 1
	)
	set "DataFiles_location1=%order_location%"
	set "DataFiles_location=%DataFiles_location1:~0,-9%"
	set "DataFiles_location1=%DataFiles_location%"
	set "DataFiles_location=%DataFiles_location1:~1%"
	echo DataFiles_location: %DataFiles_location%
exit /b

::*******************************************************************#

::****************** Fresh Deploy War/ESCM-DataFiles Function *********************#
:fresh
	echo "Deploying WAR"
	move "%current_dir%\order.war" "%SYNERGY_HOME%.war"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] WAR Deployment failed!"
		exit 1
	)
	
	echo "Deployment ESCM-DataFiles"
	xcopy "%DataFiles_location%\ESCM-DataFiles" "%CATALINA_HOME%\ESCM-DataFiles" /HEYI
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] ESCM-DataFiles Deployment failed!"
		exit 1
	)
exit /b

::*******************************************************************#

::****************** Taking Backup War/ESCM-DataFiles Function *********************#
:backup
	echo "Taking Backup War/ESCM-DataFiles"
	echo Creating Final Deployment Backup Location
	if exist "%Backup_location%" move "%Backup_location%" "%CATALINA_HOME%\BACKUP\%BACKUP_DIRECTORY_NAME%"
	mkdir "%Backup_location%"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] %Backup_location% directory creation failed!"
		exit 1
	)


	robocopy "%SYNERGY_HOME%" "%Backup_location%\%appname%" /s /e
	if NOT %ERRORLEVEL% == 1 (
		echo "[Error] WAR Backup failed!"
		exit 1
	)

	copy "%SYNERGY_HOME%.war" "%Backup_location%"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] WAR Backup failed!"
		exit 1
	)

	robocopy "%CATALINA_HOME%\ESCM-DataFiles" "%Backup_location%\ESCM-DataFiles" /s /e 
	if NOT %ERRORLEVEL% == 1 (
		echo "[Error] ESCM-DataFiles Backup failed!"
		exit 1
	)

exit /b

::*******************************************************************#

::****************** Restore War/ESCM-DataFiles Function *********************#
:restore
	echo "Restoring to previous state"
	if exist "%SYNERGY_HOME%" rd "%SYNERGY_HOME%" /s /q
	if exist "%SYNERGY_HOME%.war" del "%SYNERGY_HOME%.war"
	if exist "%SYNERGY_HOME%_old" rd "%SYNERGY_HOME%_old" /s /q
	if exist "%SYNERGY_HOME%_old.war" del "%SYNERGY_HOME%_old.war"
	echo "New files deleted"
	robocopy "%Backup_location%\%appname%" "%CATALINA_HOME%\webapps\%appname%"  /s /e
	if NOT %ERRORLEVEL% == 1 (
		echo "[Error] %appname% Restore failed!"
		echo "Proceed for manual restore from location %Backup_location%"
		exit 1
	)

	copy "%Backup_location%\%appname%.war" "%CATALINA_HOME%\webapps\"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] %appname%.war Restore failed!"
		echo "Proceed for manual restore from location %Backup_location%"
		exit 1
	)

	robocopy "%Backup_location%\ESCM-DataFiles" "%CATALINA_HOME%\ESCM-DataFiles" /s /e 

	echo Restore Completed.
	del "%CATALINA_HOME%\deployment_status.txt"
	exit 0
exit /b
::*******************************************************************#

::****************** Restore War/ESCM-DataFiles Function in case of failed deployment *********************#
:error_restore
	echo "Error in previous deployment"
	echo "Restoring to previous state"
	if not exist "%Backup_location%" (
		echo "Previous backup location not found"
		exit 1
	)
	if exist "%SYNERGY_HOME%" rd "%SYNERGY_HOME%" /s /q
	if exist "%SYNERGY_HOME%.war" del "%SYNERGY_HOME%.war"
	if exist "%SYNERGY_HOME%_old" rd "%SYNERGY_HOME%_old" /s /q
	if exist "%SYNERGY_HOME%_old.war" del "%SYNERGY_HOME%_old.war"
	echo "New files deleted"
	robocopy "%Backup_location%\%appname%" "%CATALINA_HOME%\webapps\%appname%"  /s /e
	if NOT %ERRORLEVEL% == 1 (
		echo "[Error] %appname% Restore failed!"
		echo "Proceed for manual restore from location %Backup_location%"
		exit 1
	)

	copy "%Backup_location%\%appname%.war" "%CATALINA_HOME%\webapps\"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] %appname%.war Restore failed!"
		echo "Proceed for manual restore from location %Backup_location%"
		exit 1
	)

	robocopy "%Backup_location%\ESCM-DataFiles" "%CATALINA_HOME%\ESCM-DataFiles" /s /e 

	echo Restore Completed.
	echo 0 > "%CATALINA_HOME%\deployment_status.txt"

exit /b
::*******************************************************************#

::****************** Copying ESCM-DataFiles For Merging Function *********************#
:df_copy
	echo "Copying ESCM-DataFiles For Merging"
	rd "%Compare_War_location%\DF_WAR_Struct" /s /q
	mkdir "%Compare_War_location%\DF_WAR_Struct\WEB-INF\grails-app\i18n"
	
	echo "Moving OLD CSS from ESCM-DataFiles to SYNERGY HOME"
	rd "%SYNERGY_HOME%\css" /s /q
	if exist "%CATALINA_HOME%\ESCM-DataFiles\css" move /Y "%CATALINA_HOME%\ESCM-DataFiles\css" "%SYNERGY_HOME%\"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Moving OLD CSS from ESCM-DataFiles to SYNERGY HOME failed!"
		call :restore
	)
	
	echo "Moving OLD Images from ESCM-DataFiles to SYNERGY HOME"
	rd "%SYNERGY_HOME%\images" /s /q
	if exist "%CATALINA_HOME%\ESCM-DataFiles\images" move /Y "%CATALINA_HOME%\ESCM-DataFiles\images" "%SYNERGY_HOME%\"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Moving OLD Images from ESCM-DataFiles to SYNERGY HOME failed!"
		call :restore
	)
	
	echo "Removing Old Branding from ESCM-DataFiles"
	if exist "%CATALINA_HOME%\ESCM-DataFiles\branding\DeltaBranding" (
		rd "%CATALINA_HOME%\ESCM-DataFiles\branding\DeltaBranding" /s /q
		del "%CATALINA_HOME%\ESCM-DataFiles\branding\BrandingCSSandLESSfile.zip"
		del "%CATALINA_HOME%\ESCM-DataFiles\branding\defaultTheme.zip"
	)
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Removing Old Branding from ESCM-DataFiles failed!"
		call :restore
	)
	
	echo "Moving Reseller Branding from ESCM-DataFiles to SYNERGY HOME"
	::if exist "%CATALINA_HOME%\ESCM-DataFiles\branding" move /Y "%CATALINA_HOME%\ESCM-DataFiles\branding\*" "%SYNERGY_HOME%\branding\"
	for /d %%d in (%CATALINA_HOME%\ESCM-DataFiles\branding\*) do (
		echo Dir: "%%d"
		move /Y %%d "%SYNERGY_HOME%\branding\"
	)
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Moving Reseller Branding from ESCM-DataFiles to SYNERGY HOME failed!"
		call :restore
	)
	
	echo "Copying %compare_list% from ESCM-DataFiles for Merging"
	For %%i in (%compare_list%) do (
		if %%i == lib (
			echo "Copying %%i"
			xcopy "%CATALINA_HOME%\ESCM-DataFiles\%%i" "%Compare_War_location%\DF_WAR_Struct\WEB-INF\%%i" /HEYI 
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] %%i Copy failed! from DataFiles"
				call :restore
			)
		) else if %%i == i18n (
			echo "Copying %%i"
			copy /Y "%CATALINA_HOME%\ESCM-DataFiles\%%i\messages.properties" "%Compare_War_location%\DF_WAR_Struct\WEB-INF\grails-app\%%i\messages.properties"
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] %%i Copy failed! from DataFiles"
				call :restore
			)
		) else (
			echo "Copying %%i"
			xcopy "%CATALINA_HOME%\ESCM-DataFiles\%%i" "%Compare_War_location%\DF_WAR_Struct\%%i" /HEYI
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] %%i Copy failed! from DataFiles"
				call :restore
			)
		)
	)
	
	echo "Moving Connector Message file from ESCM-DataFiles to SYNERGY HOME"
	if exist "%SYNERGY_HOME%\WEB-INF\grails-app\i18n" rd "%SYNERGY_HOME%\WEB-INF\grails-app\i18n" /s /q
	if exist "%CATALINA_HOME%\ESCM-DataFiles\i18n" move /Y "%CATALINA_HOME%\ESCM-DataFiles\i18n" "%SYNERGY_HOME%\WEB-INF\grails-app\i18n"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Moving Connector Message file from ESCM-DataFiles to SYNERGY HOME failed!"
		call :restore
	)
	
	copy /Y "%CATALINA_HOME%\ESCM-DataFiles\web.xml" "%SYNERGY_HOME%\WEB-INF\"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] web.xml Copy failed! from DataFiles"
		call :restore
	)
	
exit /b
::*******************************************************************#

::****************** Copying Old WAR For Merging Function *********************#
:old_war_copy
	echo "Copying Old WAR For Merging"
	rd "%Compare_War_location%\old_war" /s /q
	mkdir "%Compare_War_location%\old_war\WEB-INF\grails-app\i18n"
	
	echo "Moving OLD CSS from SYNERGY HOME old to SYNERGY HOME"
	rd "%SYNERGY_HOME%\css" /s /q
	if exist "%SYNERGY_HOME%_old\css" move /Y "%SYNERGY_HOME%_old\css" "%SYNERGY_HOME%\"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Moving OLD CSS from SYNERGY HOME old to SYNERGY HOME failed!"
		call :restore
	)
	
	echo "Moving OLD Images from SYNERGY HOME old to SYNERGY HOME"
	rd "%SYNERGY_HOME%\images" /s /q
	if exist "%SYNERGY_HOME%_old\images" move /Y "%SYNERGY_HOME%_old\images" "%SYNERGY_HOME%\"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Moving OLD Images from SYNERGY HOME old to SYNERGY HOME failed!"
		call :restore
	)
	
	echo "Removing Old Branding from SYNERGY HOME old"
	if exist "%SYNERGY_HOME%_old\branding\DeltaBranding" (
		rd "%SYNERGY_HOME%_old\branding\DeltaBranding" /s /q
		del "%SYNERGY_HOME%_old\branding\BrandingCSSandLESSfile.zip"
		del "%SYNERGY_HOME%_old\branding\defaultTheme.zip"
	)
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Removing Old Branding from SYNERGY HOME old failed!"
		call :restore
	)
	
	echo "Moving Reseller Branding from SYNERGY HOME old to SYNERGY HOME"
	::if exist "%SYNERGY_HOME%_old\branding" move /Y "%SYNERGY_HOME%_old\branding\*" "%SYNERGY_HOME%\branding\"
	for /d %%d in (%SYNERGY_HOME%_old\branding\*) do (
		echo Dir: "%%d"
		move /Y %%d "%SYNERGY_HOME%\branding\"
	)
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Moving Reseller Branding from SYNERGY HOME old to SYNERGY HOME failed!"
		call :restore
	)
	
	echo "Copying old %compare_list% from SYNERGY_HOME for Merging"
	For %%i in (%compare_list%) do (
		if %%i == lib (
			echo "Copying %%i"
			xcopy "%SYNERGY_HOME%_old\WEB-INF\%%i" "%Compare_War_location%\old_war\WEB-INF\%%i" /HEYI 
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] %%i Copy failed! from Old WAR"
				call :restore
			)
		) else if %%i == i18n (
			echo "Copying %%i"
			copy /Y "%SYNERGY_HOME%_old\WEB-INF\grails-app\%%i\messages.properties" "%Compare_War_location%\old_war\WEB-INF\grails-app\%%i\messages.properties"
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] %%i Copy failed! from Old WAR"
				call :restore
			)
		) else (
			echo "Copying %%i"
			xcopy "%SYNERGY_HOME%_old\%%i" "%Compare_War_location%\old_war\%%i" /HEYI
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] %%i Copy failed! from Old WAR"
				call :restore
			)
		)
	)

	echo "Moving Connector Message file from SYNERGY HOME old to SYNERGY HOME"
	if exist "%SYNERGY_HOME%\WEB-INF\grails-app\i18n" rd "%SYNERGY_HOME%\WEB-INF\grails-app\i18n" /s /q
	if exist "%SYNERGY_HOME%_old\WEB-INF\grails-app\i18n" move /Y "%SYNERGY_HOME%_old\WEB-INF\grails-app\i18n" "%SYNERGY_HOME%\WEB-INF\grails-app\i18n"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Moving Connector Message file from SYNERGY HOME old to SYNERGY HOME failed!"
		call :restore
	)
	
	copy /Y "%SYNERGY_HOME%_old\WEB-INF\web.xml" "%SYNERGY_HOME%\WEB-INF\"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] web.xml Copy failed! from Old WAR"
		call :restore
	)
	
exit /b
::*******************************************************************#

::****************** Copying New WAR For Merging Function *********************#
:new_war_copy
	echo "Copying New WAR For Merging"
	mkdir "%Compare_War_location%\new_war\WEB-INF\grails-app\i18n"
	echo Renaming Exsisting WAR to OLD from SYNERGY HOME Location
	if exist %SYNERGY_HOME% move "%SYNERGY_HOME%" "%SYNERGY_HOME%_old"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Renaming Exsisting Old WAR failed!"
		call :restore
	)
	
	if exist %SYNERGY_HOME%.war move "%SYNERGY_HOME%.war" "%SYNERGY_HOME%_old.war"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Renaming Exsisting Old WAR failed!"
		call :restore
	)

	echo Copying New WAR to SYNERGY HOME Location
	move "%current_dir%\order.war" "%SYNERGY_HOME%.war"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] New WAR Copy failed! to SYNERGY HOME Location"
		call :restore
	)
	
	del "%current_dir%\order.war"
	echo Extracting New WAR
	unzip -o "%SYNERGY_HOME%.war" -d "%SYNERGY_HOME%"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] New WAR Unzip failed!"
		call :restore
	)
	
	echo "Copying New %compare_list% from SYNERGY HOME for Merging"
	For %%i in (%compare_list%) do (
		if %%i == lib (
			echo "Copying %%i"
			xcopy "%SYNERGY_HOME%\WEB-INF\%%i" "%Compare_War_location%\new_war\WEB-INF\%%i" /HEYI 
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] %%i Copy failed! from New WAR"
				call :restore
			)
		) else if %%i == i18n (
			echo "Copying %%i"
			xcopy "%SYNERGY_HOME%\WEB-INF\grails-app\%%i" "%Compare_War_location%\new_war\WEB-INF\grails-app\%%i" /HEYI 
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] %%i Copy failed! from New WAR"
				call :restore
			)
		) else (
			echo "Copying %%i"
			xcopy "%SYNERGY_HOME%\%%i" "%Compare_War_location%\new_war\%%i" /HEYI
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] %%i Copy failed! from New WAR"
				call :restore
			)
		)
	)

exit /b
::*******************************************************************#

::****************** WAR To WAR Upgrade Function *********************#
:war2war_upgrade
	mkdir "%Compare_War_location%\new_war\WEB-INF\grails-app\i18n"
	mkdir "%Compare_War_location%\old_war\WEB-INF\grails-app\i18n"
	
	echo "Taking backup Customized CSS from SYNERGY HOME"
	if exist "%SYNERGY_HOME%\css" move /Y "%SYNERGY_HOME%\css" "%Compare_War_location%\old_war\"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Taking backup Customized CSS from SYNERGY HOME failed!"
		goto :EOF
	)
	
	echo "Taking backup Customized Images from SYNERGY HOME"
	if exist "%SYNERGY_HOME%\images" move /Y "%SYNERGY_HOME%\images" "%Compare_War_location%\old_war\"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Taking backup Customized Images from SYNERGY HOME failed!"
		goto :EOF
	)
	
	echo "Taking backup Customized web.xml from SYNERGY HOME"
	copy /Y "%SYNERGY_HOME%\WEB-INF\web.xml" "%Compare_War_location%\old_war\WEB-INF\"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Taking backup Customized web.xml from SYNERGY HOME failed!"
		goto :EOF
	)
	
	echo "Taking backup Customized messages.properties from SYNERGY HOME"
	move /Y "%SYNERGY_HOME%\WEB-INF\grails-app\i18n\messages.properties" "%Compare_War_location%\old_war\WEB-INF\grails-app\i18n\messages.properties"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] messages.properties Copy failed! from Old WAR"
		goto :EOF
	)
	
	echo Renaming Exsisting WAR to OLD from SYNERGY HOME Location
	if exist %SYNERGY_HOME%.war move "%SYNERGY_HOME%.war" "%SYNERGY_HOME%_old.war"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Renaming Exsisting Old WAR failed!"
		goto :EOF
	)

	echo "Deleting OLD files from SYNERGY HOME"
	FOR /D %%i IN ("%SYNERGY_HOME%\*") DO (
		if not "%%i"=="%SYNERGY_HOME%\branding" if not "%%i"=="%SYNERGY_HOME%\plugins" if not "%%i"=="%SYNERGY_HOME%\css" if not "%%i"=="%SYNERGY_HOME%\images" if not "%%i"=="%SYNERGY_HOME%\resources" if not "%%i"=="%SYNERGY_HOME%\WEB-INF" ( 
			rd /s /q "%%i"
			echo Deleting %%i
		)
	)

	FOR /D %%i IN ("%SYNERGY_HOME%\WEB-INF\*") DO (
		if not "%%i"=="%SYNERGY_HOME%\WEB-INF\lib" if not "%%i"=="%SYNERGY_HOME%\WEB-INF\grails-app" (
			rd /s /q "%%i"
			echo Deleting %%i
		)
	)

	FOR /D %%i IN ("%SYNERGY_HOME%\WEB-INF\grails-app\*") DO (
		if not "%%i"=="%SYNERGY_HOME%\WEB-INF\grails-app\i18n" (
			rd /s /q "%%i"
			echo Deleting %%i
		)
	)
	
	echo Copying New WAR to SYNERGY HOME Location
	move "%current_dir%\order.war" "%SYNERGY_HOME%.war"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] New WAR Copy failed! to SYNERGY HOME Location"
		goto :EOF
	)
	
	del "%current_dir%\order.war"
	echo Extracting New WAR
	unzip -o "%SYNERGY_HOME%.war" -d "%SYNERGY_HOME%"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] New WAR Unzip failed!"
		goto :EOF
	)
	
	echo "Taking backup New messages.properties from New WAR"
	move /Y "%SYNERGY_HOME%\WEB-INF\grails-app\i18n\messages.properties" "%Compare_War_location%\new_war\WEB-INF\grails-app\i18n\messages.properties"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] messages.properties Copy failed! from New WAR"
		goto :EOF
	)
	

	echo Comparing for extracting the Delta-WAR
	cd "%current_dir%\lib"
	"%JAVA_HOME%\bin\java" -jar CompareFile.jar "%Compare_War_location%\old_war\WEB-INF\grails-app\i18n" "%Compare_War_location%\new_war\WEB-INF\grails-app\i18n"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Comparing failed!"
		goto :EOF
	)
	
	echo "Replacing Customized CSS to SYNERGY HOME"
	rd "%SYNERGY_HOME%\css" /s /q
	if exist "%Compare_War_location%\old_war\css" move /Y "%Compare_War_location%\old_war\css" "%SYNERGY_HOME%\"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Replacing Customized CSS to SYNERGY HOME failed!"
		goto :EOF
	)
	
	echo "Replacing Customized Images to SYNERGY HOME"
	rd "%SYNERGY_HOME%\images" /s /q
	if exist "%Compare_War_location%\old_war\images" move /Y "%Compare_War_location%\old_war\images" "%SYNERGY_HOME%\"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Replacing Customized Images to SYNERGY HOME failed!"
		goto :EOF
	)
	
	echo "Replacing Customized web.xml to SYNERGY HOME"
	copy /Y "%Compare_War_location%\old_war\WEB-INF\web.xml" "%SYNERGY_HOME%\WEB-INF\web.xml"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Replacing Customized web.xml to SYNERGY HOME failed!"
		goto :EOF
	)
	
	echo "Replacing New Customized messages.properties to SYNERGY HOME"
	move /Y "%Compare_War_location%\old_war\WEB-INF\grails-app\i18n\messages.properties" "%SYNERGY_HOME%\WEB-INF\grails-app\i18n\messages.properties"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] messages.properties Copy failed! to New WAR"
		goto :EOF
	)
	
	del "%SYNERGY_HOME%_old.war"

exit /b
::*******************************************************************#


::****************** Merging ESCM-DataFiles/Old WAR & New War Function *********************#
:compare_folder
	echo Comparing Folders
	
	set "source_dir=%~1"
	set "dest_dir=%~2"
	echo Source Folder: %source_dir%
	echo Destination Folder: %dest_dir%
	
	echo Comparing for extracting the Delta-WAR
	cd "%current_dir%\lib"
	"%JAVA_HOME%\bin\java" -jar CompareFile.jar "%source_dir%" "%dest_dir%"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Comparing failed!"
		call :restore
	)
		
	echo Merging Delta WAR with the existing customized WAR
	For %%i in (%compare_list%) do (
		if %%i == lib (
			echo "Copying %%i"
			if exist "%dest_dir%\WEB-INF\%%i" xcopy "%dest_dir%\WEB-INF\%%i" "%source_dir%\WEB-INF\%%i" /HEYI 
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] Merging failed!"
				call :restore
			)
		) else if %%i == i18n (
			echo "Copying %%i"
		) else (
			echo "Copying %%i"
			if exist "%dest_dir%\%%i" xcopy "%dest_dir%\%%i" "%source_dir%\%%i" /HEYI
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] Merging failed!"
				call :restore
			)
		)
	)

	echo Copy Merged WAR to SYNERGY HOME location
	For %%i in (%compare_list%) do (
		if %%i == lib (
			echo "Copying %%i"
			if exist "%source_dir%\WEB-INF\%%i" xcopy "%source_dir%\WEB-INF\%%i" "%SYNERGY_HOME%\WEB-INF\%%i" /HEYI 
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] %%i Merging failed! to SYNERGY HOME location"
				call :restore
			)
		) else if %%i == i18n (
			echo "Copying %%i"
			if exist "%source_dir%\WEB-INF\grails-app\%%i" xcopy "%source_dir%\WEB-INF\grails-app\%%i" "%SYNERGY_HOME%\WEB-INF\grails-app\%%i" /HEYI 
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] %%i Merging failed! to SYNERGY HOME location"
				call :restore
			)
		) else (
			echo "Copying %%i"
			if exist "%source_dir%\%%i" xcopy "%source_dir%\%%i" "%SYNERGY_HOME%\%%i" /HEYI
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] %%i Merging failed! to SYNERGY HOME location"
				call :restore
			)
		)
	)
	
	echo Removing Exsisting WAR from SYNERGY HOME Location
	if exist "%SYNERGY_HOME%_old" rd "%SYNERGY_HOME%_old" /s /q
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Old WAR Delete failed!"
		call :restore
	)
	
	if exist "%SYNERGY_HOME%_old.war" del "%SYNERGY_HOME%_old.war"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Old WAR Delete failed!"
		call :restore
	)
	
	echo Successfully Upgraded

exit /b
::*******************************************************************#

::****************** Removing ESCM-DataFiles Content Function *********************#
:rm_df
	echo "Removing ESCM-DataFiles Content"
	For %%i in (%compare_list%) do (
		echo "Removing %%i"
		if exist "%CATALINA_HOME%\ESCM-DataFiles\%%i" rd "%CATALINA_HOME%\ESCM-DataFiles\%%i" /s /q
	)
	if exist "%CATALINA_HOME%\ESCM-DataFiles\branding" rd "%CATALINA_HOME%\ESCM-DataFiles\branding" /s /q
	if exist "%CATALINA_HOME%\ESCM-DataFiles\css" rd "%CATALINA_HOME%\ESCM-DataFiles\css" /s /q
	if exist "%CATALINA_HOME%\ESCM-DataFiles\images" rd "%CATALINA_HOME%\ESCM-DataFiles\images" /s /q
	if exist "%CATALINA_HOME%\ESCM-DataFiles\unused_files" rd "%CATALINA_HOME%\ESCM-DataFiles\unused_files" /s /q
exit /b
::*******************************************************************#

:END
call "%current_dir%\CleanupScript\WindowsCleanupScript.bat"
echo "Deployment Completed, proceed for next steps."

set ENDTIME=%TIME%
    for /F "tokens=1-4 delims=:.," %%a in ("%STARTTIME%") do (
       set /A "start=(((%%a*60)+1%%b %% 100)*60+1%%c %% 100)*100+1%%d %% 100"
    )
    for /F "tokens=1-4 delims=:.," %%a in ("%ENDTIME%") do (
       set /A "end=(((%%a*60)+1%%b %% 100)*60+1%%c %% 100)*100+1%%d %% 100"
    )
    set /A elapsed=end-start
    set /A hh=elapsed/(60*60*100), rest=elapsed%%(60*60*100), mm=rest/(60*100), rest%%=60*100, ss=rest/100, cc=rest%%100
    if %hh% lss 10 set hh=0%hh%
    if %mm% lss 10 set mm=0%mm%
    if %ss% lss 10 set ss=0%ss%
    if %cc% lss 10 set cc=0%cc%
    set DURATION=%hh%:%mm%:%ss%,%cc%

    echo Start Time		: %STARTTIME%
    echo Finish Time		: %ENDTIME%
    echo ------------------------------------
    echo Total Time Duration	: %DURATION%
	
goto :EOF

:error
echo "Inconsistent ESCM-DataFiles"

