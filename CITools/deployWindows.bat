@ECHO OFF
SETLOCAL ENABLEEXTENSIONS

echo "***********************************************************************************************"

REM SET /P order_location="Please provide ISO [war-file location (till webapps)]: "  

REM if "%~1"=="" (
    REM echo No parameters have been provided.
	REM echo Provide Order.zip Location. i.e: D:\CB_10.0\ISO\Portal\CB_10.0\webapps
	REM goto :EOF
REM )

REM set order_location=%1%
set order_location="D:\Ensim Automation Suite\CB-10\CB_10.0\ISO\Portal\CB_10.0\webapps"
REM set order_location="D:\Ensim Automation Suite\EAS-5.2\EAS_5.2\ISO\Portal\EAS_5.2\webapps"
REM set order_location="D:\Ensim Automation Suite\EAS-4.8\RTO\EAS_4.8\ISO\Portal\EAS_4.8\webapps"
echo order_location: %order_location%

::################### User variables ###################
REM set SYNERGY_HOME="/usr/share/tomcat/webapps/escm"
REM set CATALINA_HOME="/usr/share/tomcat"

::##############################################################

::################### Initializing variables ###################
set current_dir=%cd%
set Compare_War_location=%current_dir%\Compare_War
set BACKUP_DIRECTORY_NAME=%date%_%time:~0,2%_%time:~3,2%_%time:~6,2%
set Backup_location=%current_dir%\BACKUP\%BACKUP_DIRECTORY_NAME%
set compare_list=branding,css,images,plugins,resources,lib,i18n
::##############################################################


::###### Taking Decision {Fresh, Upgrade:DF2War, War2War} #######

IF DEFINED SYNERGY_HOME (
	IF DEFINED CATALINA_HOME (		 
		if exist %CATALINA_HOME%\ESCM-DataFiles (
			if exist %CATALINA_HOME%\ESCM-DataFiles\branding (
			::::=============ESCM-DataFiles to WAR Upgrade::=============
				For %%i in (%compare_list%) do (
					if exist %CATALINA_HOME%\ESCM-DataFiles\%%i (
						ECHO "%%i found"
						set flag=2

					)Else (
						ECHO "%%i not found"
						set flag=0
						Goto :error	

					)
				)
			)Else (
			::::=============WAR to WAR Upgrade::=============
				For %%i in (%compare_list%) do (
					if not exist %CATALINA_HOME%\ESCM-DataFiles\%%i (
						ECHO "%%i not found"
						set flag=3

					)Else (
						ECHO "%%i found"
						set flag=0
						Goto :error	

					)
				)
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

::########################## Extract zip #######################
echo "Extracting Order.zip"
echo current_dir %current_dir%
unzip -o %order_location%/order.zip -d "%current_dir%"
if NOT %ERRORLEVEL% == 0 (
	echo "[Error] Unzip failed!"
	GOTO :EOF
)
cd %order_location%
cd ..
set "DataFiles_location=%cd%"
echo DataFiles_location: %DataFiles_location%
::############ Get APP Name from SYNERGY_HOME ##########
for %%f in (%SYNERGY_HOME%) do set appname=%%~nxf
echo APP Name: %appname%
::##############################################################

::###### Deploying according to flag value #######
	:Start	
	2>NUL CALL :CASE_%flag% # jump to :CASE_1, :CASE_2, etc.
	EXIT /B

	:CASE_1
		Echo ============================ 
		Echo =    Fresh Installation    =	 
		Echo ============================
		call :fresh
		GOTO :END
	  
	:CASE_2 
		Echo ======================================= 
		Echo =    ESCM-DataFiles to WAR Upgrade    =	 
		Echo =======================================
		call :backup
		call :df_copy
		call :new_war_copy
		call :compare_folder "%Compare_War_location%\DF_WAR_Struct", "%Compare_War_location%\new_war"
		call :rm_df
		GOTO :END
		
	:CASE_3 
		Echo ============================
		Echo =    WAR to WAR Upgrade    =	 
		Echo ============================
		call :backup
		call :old_war_copy
		call :new_war_copy
		call :compare_folder "%Compare_War_location%\old_war", "%Compare_War_location%\new_war"
		GOTO :END

::##############################################################

::****************** Fresh Deploy War/ESCM-DataFiles Function *********************#
:fresh
	echo "Deploying WAR"
	move "%current_dir%\order.war" "%SYNERGY_HOME%.war"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Deployment failed!"
		pause
		exit 1
	)
	
	echo "Deployment ESCM-DataFiles"
	xcopy "%DataFiles_location%\ESCM-DataFiles" "%CATALINA_HOME%\ESCM-DataFiles" /HEYI
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Deployment failed!"
		pause
		exit 1
	)
exit /b

::*******************************************************************#

::****************** Taking Backup War/ESCM-DataFiles Function *********************#
:backup
	echo "Taking Backup War/ESCM-DataFiles"
	mkdir "%Backup_location%"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] %Backup_location% directory creation failed!"
		pause
		exit 1
	)
	
	xcopy %SYNERGY_HOME% "%Backup_location%\%appname%" /HEYI
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Backup failed!"
		pause
		exit 1
	)

	copy "%SYNERGY_HOME%.war" "%Backup_location%"

	xcopy "%CATALINA_HOME%\ESCM-DataFiles" "%Backup_location%\ESCM-DataFiles" /HEYI 
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Backup failed!"
		pause
		exit 1
	)
exit /b

::*******************************************************************#

::****************** Restore War/ESCM-DataFiles Function *********************#
:restore
	echo "Restoring to previous state"
	xcopy "%Backup_location%\%appname%" "%CATALINA_HOME%\webapps\%appname%"  /HEYI
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Restore failed!"
		echo "Proceed for manual restore from location %Backup_location%"
		pause
		exit 1
	)

	copy "%Backup_location%\%appname%.war" "%CATALINA_HOME%\webapps\"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Restore failed!"
		echo "Proceed for manual restore from location %Backup_location%"
		pause
		exit 1
	)

	xcopy "%Backup_location%\ESCM-DataFiles" %CATALINA_HOME%\ESCM-DataFiles /HEYI 
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Restore failed!"
		echo "Proceed for manual restore from location %Backup_location%"
		pause
		exit 1
	)
exit /b
::*******************************************************************#

::****************** Copying ESCM-DataFiles For Merging Function *********************#
:df_copy
	echo "Copying ESCM-DataFiles For Merging"
	rd "%Compare_War_location%\DF_WAR_Struct" /s /q
	mkdir "%Compare_War_location%\DF_WAR_Struct\WEB-INF\grails-app\i18n"
	echo "Copying %compare_list% from ESCM-DataFiles for Merging"
	For %%i in (%compare_list%) do (
		if %%i == lib (
			echo "Copying %%i"
			xcopy %CATALINA_HOME%\ESCM-DataFiles\%%i "%Compare_War_location%\DF_WAR_Struct\WEB-INF\%%i" /HEYI 
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] Copy failed!"
				pause
				exit 1
			)
		) else if %%i == i18n (
			echo "Copying %%i"
			xcopy %CATALINA_HOME%\ESCM-DataFiles\%%i "%Compare_War_location%\DF_WAR_Struct\WEB-INF\grails-app\%%i" /HEYI 
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] Copy failed!"
				pause
				exit 1
			)
		) else (
			echo "Copying %%i"
			xcopy %CATALINA_HOME%\ESCM-DataFiles\%%i "%Compare_War_location%\DF_WAR_Struct\%%i" /HEYI
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] Copy failed!"
				pause
				exit 1
			)
		)
	)
	)
	::copy "%CATALINA_HOME%\ESCM-DataFiles\i18n\messages.properties" "%Compare_War_location%\DF_WAR_Struct\WEB-INF\grails-app\i18n\"
	copy "%SYNERGY_HOME%\WEB-INF\web.xml" "%Compare_War_location%"
	
exit /b
::*******************************************************************#

::****************** Copying Old WAR For Merging Function *********************#
:old_war_copy
	echo "Copying Old WAR For Merging"
	rd "%Compare_War_location%\old_war" /s /q
	mkdir "%Compare_War_location%\old_war\WEB-INF\grails-app\i18n"
	echo "Copying old %compare_list% from SYNERGY_HOME for Merging"
	For %%i in (%compare_list%) do (
		if %%i == lib (
			echo "Copying %%i"
			xcopy %SYNERGY_HOME%\WEB-INF\%%i "%Compare_War_location%\old_war\WEB-INF\%%i" /HEYI 
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] Copy failed!"
				pause
				exit 1
			)
		) else if %%i == i18n (
			echo "Copying %%i"
			xcopy %SYNERGY_HOME%\WEB-INF\grails-app\%%i "%Compare_War_location%\old_war\WEB-INF\grails-app\%%i" /HEYI 
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] Copy failed!"
				pause
				exit 1
			)
		) else (
			echo "Copying %%i"
			xcopy %SYNERGY_HOME%\%%i "%Compare_War_location%\old_war\%%i" /HEYI
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] Copy failed!"
				pause
				exit 1
			)
		)
	)
	)
	::copy "%SYNERGY_HOME%\WEB-INF\grails-app\i18n\messages.properties" "%Compare_War_location%\old_war\WEB-INF\grails-app\i18n\"
	copy "%SYNERGY_HOME%\WEB-INF\web.xml" "%Compare_War_location%"
	
exit /b
::*******************************************************************#

::****************** Copying New WAR For Merging Function *********************#
:new_war_copy
echo "Copying New WAR For Merging"
	echo Removing Exsisting WAR
	rd %SYNERGY_HOME% /s /q
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Delete failed!"
		call :restore
	)
	
	del %SYNERGY_HOME%.war
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Delete failed!"
		call :restore
	)
	rd "%Compare_War_location%\new_war" /s /q
	mkdir "%Compare_War_location%\new_war\WEB-INF\grails-app\i18n"
	echo Copying New WAR
	move "%current_dir%\order.war" "%SYNERGY_HOME%.war"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Copy failed!"
		call :restore
	)
	del "%current_dir%\order.war"
	echo Extracting New WAR
	unzip -o "%SYNERGY_HOME%.war" -d "%SYNERGY_HOME%"
	
	echo "Copying New %compare_list% from SYNERGY_HOME for Merging"
	For %%i in (%compare_list%) do (
		if %%i == lib (
			echo "Copying %%i"
			xcopy %SYNERGY_HOME%\WEB-INF\%%i "%Compare_War_location%\new_war\WEB-INF\%%i" /HEYI 
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] Copy failed!"
				call :restore
			)
		) else if %%i == i18n (
			echo "Copying %%i"
			xcopy %SYNERGY_HOME%\WEB-INF\grails-app\%%i "%Compare_War_location%\new_war\WEB-INF\grails-app\%%i" /HEYI 
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] Copy failed!"
				call :restore
			)
		) else (
			echo "Copying %%i"
			xcopy %SYNERGY_HOME%\%%i "%Compare_War_location%\new_war\%%i" /HEYI
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] Copy failed!"
				call :restore
			)
		)
	)
	)
	::copy "%SYNERGY_HOME%\WEB-INF\grails-app\i18n\messages.properties" "%Compare_War_location%\new_war\WEB-INF\grails-app\i18n\"

exit /b
::*******************************************************************#

::****************** Merging ESCM-DataFiles/Old WAR & New War Function *********************#
:compare_folder
	echo Comparing Folders
	echo "%current_dir%\lib\CompareFile.class"
	copy "%current_dir%\lib\CompareFile.class" "%Compare_War_location%"
	
	set "source_dir=%~1"
	set "dest_dir=%~2"
	echo Source Folder: %source_dir%
	echo Destination Folder: %dest_dir%
	
	echo "Copy latest Branding folder to existing WAR before merging"
	xcopy %dest_dir%\branding\* %source_dir%\branding\ /s /e
	
	echo "Removing Branding folder from New War"
	rd "%dest_dir%\branding" /s /q
  
	echo Comparing for extracting the Delta-WAR
	cd "%Compare_War_location%"
	"%JAVA_HOME%\bin\java" CompareFile "%source_dir%" "%dest_dir%"
	if NOT %ERRORLEVEL% == 0 (
		echo "[Error] Merging failed!"
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
			if exist "%dest_dir%\WEB-INF\grails-app\%%i" xcopy "%dest_dir%\WEB-INF\grails-app\%%i" "%source_dir%\WEB-INF\grails-app\%%i" /HEYI 
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] Merging failed!"
				call :restore
			)
		) else (
			echo "Copying %%i"
			if exist "%dest_dir%\%%i" xcopy "%dest_dir%\%%i" "%source_dir%\%%i" /HEYI
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] Merging failed!"
				call :restore
			)
		)
	)

	echo Copy Merged WAR to SYNERGY_HOME location
	For %%i in (%compare_list%) do (
		if %%i == lib (
			echo "Copying %%i"
			if exist "%source_dir%\WEB-INF\%%i" xcopy "%source_dir%\WEB-INF\%%i" "%SYNERGY_HOME%\WEB-INF\%%i" /HEYI 
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] Merging failed!"
				call :restore
			)
		) else if %%i == i18n (
			echo "Copying %%i"
			if exist "%source_dir%\WEB-INF\grails-app\%%i" xcopy "%source_dir%\WEB-INF\grails-app\%%i" "%SYNERGY_HOME%\WEB-INF\grails-app\%%i" /HEYI 
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] Merging failed!"
				call :restore
			)
		) else (
			echo "Copying %%i"
			if exist "%source_dir%\%%i" xcopy "%source_dir%\%%i" "%SYNERGY_HOME%\%%i" /HEYI
			if NOT %ERRORLEVEL% == 0 (
				echo "[Error] Merging failed!"
				call :restore
			)
		)
	)
	
	::copy "%source_dir%/WEB-INF/grails-app/i18n/messages.properties" "%SYNERGY_HOME%/WEB-INF/grails-app/i18n/" 
	copy "%Compare_War_location%/web.xml" "%SYNERGY_HOME%/WEB-INF/"
	echo Successfully Upgraded

exit /b
::*******************************************************************#

::****************** Removing ESCM-DataFiles Content Function *********************#
:rm_df
	echo "Removing ESCM-DataFiles Content"
	For %%i in (%compare_list%) do (
		echo "Removing %%i"
		if exist %CATALINA_HOME%\ESCM-DataFiles\%%i rd %CATALINA_HOME%\ESCM-DataFiles\%%i /s /q
	)
	::if exist %CATALINA_HOME%\ESCM-DataFiles\i18n rd %CATALINA_HOME%\ESCM-DataFiles\i18n /s /q
	if exist %CATALINA_HOME%\ESCM-DataFiles\unused_files rd %CATALINA_HOME%\ESCM-DataFiles\unused_files /s /q
exit /b
::*******************************************************************#

:END
echo "Deployment Completed, proceed for next steps."
pause
goto :EOF

:error
echo "Inconsistent ESCM-DataFiles"
pause