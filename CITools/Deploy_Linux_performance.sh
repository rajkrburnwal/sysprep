#!/bin/bash
begin=$(date +"%s")
echo "***********************************************************************************************"
if [ "$1" == "" ]; then
	echo No parameters have been provided.
	echo Provide Order.zip Location. i.e: /home/CB_10.0/ISO/Portal/CB_10.0/webapps
	exit 1
fi

order_location=$1
echo order_location: $order_location

################### User variables ###################
SYNERGY_HOME="/usr/share/tomcat/webapps/escm"
CATALINA_HOME="/usr/share/tomcat"

##############################################################

################### Initializing variables ###################
citools_location="$PWD"
Compare_War_location="$PWD/Compare_War"
BACKUP_DIRECTORY_NAME=$(date "+%d.%m.%Y-%H.%M.%S")
Backup_location="$PWD/BACKUP/$BACKUP_DIRECTORY_NAME"
compare_list="plugins;resources;lib;i18n"
##############################################################

#****************** Fresh Deploy War/ESCM-DataFiles Function *********************#
fresh(){
    echo "Deploying WAR"
	echo "WAR Location: $citools_location"
	cp "$citools_location/order.war" "$SYNERGY_HOME.war"
	if [ "$?" != "0" ]; then
		echo "[Error] WAR Deploy failed!"
		exit 1
	fi
	rm -rf "$citools_location/order.war"
	echo "Deployment ESCM-DataFiles"
	cp -r "$DataFiles_location/ESCM-DataFiles" "$CATALINA_HOME/"
	if [ "$?" != "0" ]; then
		echo "[Error] ESCM-DataFiles Deploy failed!"
		exit 1
	fi
}
#*******************************************************************#


#****************** Taking Backup War/ESCM-DataFiles Function *********************#
backup(){
    echo "Taking Backup War/ESCM-DataFiles"
	mkdir -p "$Backup_location"
	if [ "$?" != "0" ]; then
		echo "[Error] $Backup_location directory creation failed!"
		exit 1
	fi
	
	cp -r "$SYNERGY_HOME" "$Backup_location/"
	if [ "$?" != "0" ]; then
		echo "[Error] WAR Backup failed!"
		exit 1
	fi

	cp "$SYNERGY_HOME.war" "$Backup_location/"
	if [ "$?" != "0" ]; then
		echo "[Error] WAR Backup failed!"
		exit 1
	fi

	cp -r "$CATALINA_HOME/ESCM-DataFiles/" "$Backup_location/"
	if [ "$?" != "0" ]; then
		echo "[Error] ESCM-DataFiles Backup failed!"
		exit 1
	fi
}
#*******************************************************************#

#****************** Restore War/ESCM-DataFiles Function *********************#
restore(){
    echo "Restoring to previous state"
	rm -rf "$SYNERGY_HOME"
	rm -rf "$SYNERGY_HOME.war"
	rm -rf "$SYNERGY_HOME""_old"
	rm -rf "$SYNERGY_HOME""_old.war"
	echo "New files deleted"
	cp -r "$Backup_location/$appname" "$CATALINA_HOME/webapps/"
	if [ "$?" != "0" ]; then
		echo "[Error] $appname Restore failed!"
		echo "Proceed for manual restore from location $Backup_location"
		exit 1
	fi

	cp "$Backup_location/$appname.war" "$CATALINA_HOME/webapps/"
	if [ "$?" != "0" ]; then
		echo "[Error] $appname.war Restore failed!"
		echo "Proceed for manual restore from location $Backup_location"
		exit 1
	fi

	echo yes | cp -fru "$Backup_location/ESCM-DataFiles/." "$CATALINA_HOME/ESCM-DataFiles/"
	if [ "$?" != "0" ]; then
		echo "[Error] ESCM-DataFiles Restore failed!"
		echo "Proceed for manual restore from location $Backup_location"
		exit 1
	fi
	echo Restore Completed.
	exit 0
}
#*******************************************************************#

#****************** Copying ESCM-DataFiles For Merging Function *********************#
df_copy(){
	echo "Copying ESCM-DataFiles For Merging"
	rm -rf "$Compare_War_location/DF_WAR_Struct"
	mkdir -p "$Compare_War_location/DF_WAR_Struct"
	mkdir -p "$Compare_War_location/DF_WAR_Struct/WEB-INF/grails-app/i18n"

	echo "Moving OLD CSS from ESCM-DataFiles to SYNERGY HOME"
	rm -rf "$SYNERGY_HOME/css"
	if [ -d "$CATALINA_HOME/ESCM-DataFiles/css" ]; then 
		mv -f "$CATALINA_HOME/ESCM-DataFiles/css" "$SYNERGY_HOME/"
	fi
	if [ "$?" != "0" ]; then
		echo "[Error] Moving OLD CSS from ESCM-DataFiles to SYNERGY HOME failed!"
		restore
	fi
	
	echo "Moving OLD Images from ESCM-DataFiles to SYNERGY HOME"
	rm -rf "$SYNERGY_HOME/images"
	if [ -d "$CATALINA_HOME/ESCM-DataFiles/images" ]; then 
		mv -f "$CATALINA_HOME/ESCM-DataFiles/images" "$SYNERGY_HOME/"
	fi
	if [ "$?" != "0" ]; then
		echo "[Error] Moving OLD Images from ESCM-DataFiles to SYNERGY HOME failed!"
		restore
	fi
	
	echo "Removing Old Branding from ESCM-DataFiles"
	if [ -d  "$CATALINA_HOME/ESCM-DataFiles/branding/DeltaBranding" ]; then 
		rm -rf "$CATALINA_HOME/ESCM-DataFiles/branding/DeltaBranding"
		rm -rf "$CATALINA_HOME/ESCM-DataFiles/branding/BrandingCSSandLESSfile.zip"
		rm -rf "$CATALINA_HOME/ESCM-DataFiles/branding/defaultTheme.zip"
	fi
	if [ "$?" != "0" ]; then
		echo "[Error] Removing Old Branding from ESCM-DataFiles failed!"
		restore
	fi
 
	echo "Copying New Branding from SYNERGY HOME to ESCM-DataFiles"
	if [ -d  "$SYNERGY_HOME/branding" ]; then 
		echo yes | cp -fru "$SYNERGY_HOME/branding/." "$CATALINA_HOME/ESCM-DataFiles/branding/"
	fi
	if [ "$?" != "0" ]; then
		echo "[Error] Copying New Branding from SYNERGY HOME to ESCM-DataFiles failed!"
		restore
	fi
	
	echo "Moving Reseller Branding from ESCM-DataFiles to SYNERGY HOME"
	rm -rf "$SYNERGY_HOME/branding"
	if [ -d  "$CATALINA_HOME/ESCM-DataFiles/branding" ]; then
		mv -f "$CATALINA_HOME/ESCM-DataFiles/branding" "$SYNERGY_HOME/"   
	fi
	if [ "$?" != "0" ]; then
		echo "[Error] Moving Reseller Branding from ESCM-DataFiles to SYNERGY HOME failed!"
		restore
	fi
	
	echo "Copying $compare_list from ESCM-DataFiles"
	export IFS=";"
	for word in $compare_list; do
	if [ "$word" == "lib" ]; then
		echo "Copying $word"
		cp -r "$CATALINA_HOME/ESCM-DataFiles/$word" "$Compare_War_location/DF_WAR_Struct/WEB-INF/"
		if [ "$?" != "0" ]; then
			echo "[Error] $word Copy failed! from DataFiles"
			restore
		fi
	elif [ "$word" == "i18n" ]; then
		echo "Copying $word"
		cp -r "$CATALINA_HOME/ESCM-DataFiles/$word" "$Compare_War_location/DF_WAR_Struct/WEB-INF/grails-app/"
		if [ "$?" != "0" ]; then
			echo "[Error] $word Copy failed! from DataFiles"
			restore
		fi
	else
		echo "Copying $word"
		cp -r "$CATALINA_HOME/ESCM-DataFiles/$word" "$Compare_War_location/DF_WAR_Struct/"
		if [ "$?" != "0" ]; then
			echo "[Error] $word Copy failed! from DataFiles"
			restore
		fi
	fi
	done
	echo yes | cp -fru "$CATALINA_HOME/ESCM-DataFiles/web.xml" "$SYNERGY_HOME/WEB-INF/"
	if [ "$?" != "0" ]; then
		echo "[Error] web.xml Copy failed! from DataFiles"
		restore
	fi
}
#*******************************************************************#

#****************** Copying Old WAR For Merging Function *********************#
old_war_copy(){
	echo "Copying Old WAR For Merging"
	rm -rf "$Compare_War_location/old_war"
	mkdir -p "$Compare_War_location/old_war"
	mkdir -p "$Compare_War_location/old_war/WEB-INF/grails-app/i18n"
	
	echo "Moving OLD CSS from OLD SYNERGY_HOME to SYNERGY HOME"
	rm -rf "$SYNERGY_HOME/css"
	if [ -d "$SYNERGY_HOME""_old/css" ]; then 
		mv -f "$SYNERGY_HOME""_old/css" "$SYNERGY_HOME/"
	fi
	if [ "$?" != "0" ]; then
		echo "[Error] Moving OLD CSS from OLD SYNERGY_HOME to SYNERGY HOME failed!"
		restore
	fi
	
	echo "Moving OLD Images from OLD SYNERGY_HOME to SYNERGY HOME"
	rm -rf "$SYNERGY_HOME/images"
	if [ -d "$SYNERGY_HOME""_old/images" ]; then 
		mv -f "$SYNERGY_HOME""_old/images" "$SYNERGY_HOME/"
	fi
	if [ "$?" != "0" ]; then
		echo "[Error] Moving OLD Images from OLD SYNERGY_HOME to SYNERGY HOME failed!"
		restore
	fi
	
	echo "Removing Old Branding from OLD SYNERGY_HOME"
	if [ -d  "$SYNERGY_HOME""_old/branding/DeltaBranding" ]; then 
		rm -rf "$SYNERGY_HOME""_old/branding/DeltaBranding"
		rm -rf "$SYNERGY_HOME""_old/branding/BrandingCSSandLESSfile.zip"
		rm -rf "$SYNERGY_HOME""_old/branding/defaultTheme.zip"
	fi
	if [ "$?" != "0" ]; then
		echo "[Error] Removing Old Branding from OLD SYNERGY_HOME failed!"
		restore
	fi
	
	echo "Copying New Branding from SYNERGY HOME to OLD SYNERGY_HOME"
	if [ -d  "$SYNERGY_HOME/branding" ]; then 
		echo yes | cp -fru "$SYNERGY_HOME/branding/." "$SYNERGY_HOME""_old/branding/"
	fi
	if [ "$?" != "0" ]; then
		echo "[Error] Copying New Branding from SYNERGY HOME to OLD SYNERGY_HOME failed!"
		restore
	fi
	
	echo "Moving Reseller Branding from OLD SYNERGY_HOME to SYNERGY HOME"
	rm -rf "$SYNERGY_HOME/branding"
	if [ -d  "$SYNERGY_HOME""_old/branding" ]; then
		mv -f "$SYNERGY_HOME""_old/branding" "$SYNERGY_HOME/"   
	fi
	if [ "$?" != "0" ]; then
		echo "[Error] Moving Reseller Branding from OLD SYNERGY_HOME to SYNERGY HOME failed!"
		restore
	fi
	
	echo "Copying old $compare_list from SYNERGY_HOME"
	export IFS=";"
	for word in $compare_list; do
	if [ "$word" == "lib" ]; then
		echo "Copying $word"
		cp -r "$SYNERGY_HOME""_old/WEB-INF/$word" "$Compare_War_location/old_war/WEB-INF/"
		if [ "$?" != "0" ]; then
			echo "[Error] $word Copy failed! from Old WAR"
			restore
		fi
	elif [ "$word" == "i18n" ]; then
		echo "Copying $word"
		cp -r "$SYNERGY_HOME""_old/WEB-INF/grails-app/$word" "$Compare_War_location/old_war/WEB-INF/grails-app/"
		if [ "$?" != "0" ]; then
			echo "[Error] $word Copy failed! from Old WAR"
			restore
		fi
	else
	   echo "Copying $word"
	   cp -r "$SYNERGY_HOME""_old/$word" "$Compare_War_location/old_war/"
	   if [ "$?" != "0" ]; then
			echo "[Error] $word Copy failed! from Old WAR"
			restore
		fi
	fi
	done
	echo yes | cp -fru "$SYNERGY_HOME""_old/WEB-INF/web.xml" "$SYNERGY_HOME/WEB-INF/"
	if [ "$?" != "0" ]; then
		echo "[Error] web.xml Copy failed! from Old WAR"
		restore
	fi
}
#*******************************************************************#

#****************** Copying New WAR For Merging Function *********************#
new_war_copy(){
	echo "Copying New WAR For Merging"
	rm -rf "$Compare_War_location/new_war"
	mkdir -p "$Compare_War_location/new_war"
	mkdir -p "$Compare_War_location/new_war/WEB-INF/grails-app/i18n"
	
	echo Renaming Exsisting WAR to OLD from SYNERGY HOME Location
	if [ -d  "$SYNERGY_HOME" ]; then 
		mv "$SYNERGY_HOME" "$SYNERGY_HOME""_old"
	fi
	if [ "$?" != "0" ]; then
		echo "[Error] Renaming Exsisting Old WAR failed!"
		restore
	fi
	
	if [ -f  "$SYNERGY_HOME.war" ]; then 
		mv "$SYNERGY_HOME.war" "$SYNERGY_HOME""_old.war"
	fi
	if [ "$?" != "0" ]; then
		echo "[Error] Renaming Exsisting Old WAR failed!"
		restore
	fi

	echo Copying New WAR to SYNERGY HOME Location
	cp "$citools_location/order.war" "$SYNERGY_HOME.war"
	if [ "$?" != "0" ]; then
		echo "[Error] New WAR Copy failed!  to SYNERGY HOME Location"
		restore
	fi
	rm -rf "$citools_location/order.war"
	echo Extracting New WAR
	unzip -o "$SYNERGY_HOME.war" -d "$SYNERGY_HOME"
	if [ "$?" != "0" ]; then
		echo "[Error] New WAR Unzip failed!"
		restore
	fi
	
	echo "Copying New $compare_list from SYNERGY_HOME"
	export IFS=";"
	for word in $compare_list; do
	if [ "$word" == "lib" ]; then
		echo "Copying $word"
		cp -r "$SYNERGY_HOME/WEB-INF/$word" "$Compare_War_location/new_war/WEB-INF/"
		if [ "$?" != "0" ]; then
			echo "[Error] $word Copy failed! from New WAR"
			restore
		fi
	elif [ "$word" == "i18n" ]; then
		echo "Copying $word"
		cp -r "$SYNERGY_HOME/WEB-INF/grails-app/$word" "$Compare_War_location/new_war/WEB-INF/grails-app/"
		if [ "$?" != "0" ]; then
			echo "[Error] $word Copy failed! from New WAR"
			restore
		fi
	else
	   echo "Copying $word"
	   cp -r "$SYNERGY_HOME/$word" "$Compare_War_location/new_war/"
	   if [ "$?" != "0" ]; then
			echo "[Error] $word Copy failed! from New WAR"
			restore
		fi
	fi
	done
}
#*******************************************************************#

#****************** Merging ESCM-DataFiles/Old WAR & New War Function *********************#
compare_folder(){
	echo Comparing Folders

	local source_dir=$1
	local dest_dir=$2
	echo Source Folder: $source_dir
	echo Destination Folder: $dest_dir
	 
	echo Comparing for extracting the Delta-WAR
	cd "$citools_location/lib"
	java -jar CompareFile.jar "$source_dir" "$dest_dir"
	if [ "$?" != "0" ]; then
		echo "[Error] Comparing failed!"
		restore
	fi
	
	echo Merging Delta WAR with the existing customized WAR
	export IFS=";"
	for word in $compare_list; do
	if [ "$word" == "lib" ]; then
		if [ -d "$dest_dir/WEB-INF/$word" ]; then
			echo "Copying $word"
			echo yes | cp -fru "$dest_dir/WEB-INF/$word/." "$source_dir/WEB-INF/$word"
			if [ "$?" != "0" ]; then
				echo "[Error] Merging failed!"
				restore
			fi
		fi
	else
		if [ -d "$dest_dir/$word" ]; then
			echo "Copying $word"
			echo yes | cp -fru "$dest_dir/$word/." "$source_dir/$word"
			if [ "$?" != "0" ]; then
				echo "[Error] Merging failed!"
				restore
			fi
		fi
	fi
	done

	echo Copy Merged WAR to SYNERGY_HOME location
	export IFS=";"
	for word in $compare_list; do
	if [ "$word" == "lib" ]; then
		if [ -d "$source_dir/WEB-INF/$word" ]; then
			echo "Copying $word"
			echo yes | cp -fru "$source_dir/WEB-INF/$word/." "$SYNERGY_HOME/WEB-INF/$word/"
			if [ "$?" != "0" ]; then
				echo "[Error] Merging failed! to SYNERGY_HOME location"
				restore
			fi
		fi
	elif [ "$word" == "i18n" ]; then
		if [ -d "$source_dir/WEB-INF/grails-app/$word" ]; then
			echo "Copying $word"
			echo yes | cp -fru "$source_dir/WEB-INF/grails-app/$word/." "$SYNERGY_HOME/WEB-INF/grails-app/$word/"
			if [ "$?" != "0" ]; then
				echo "[Error] Merging failed! to SYNERGY_HOME location"
				restore
			fi
		fi
	else
		if [ -d "$source_dir/$word" ]; then
		   echo "Copying $word"
		   echo yes | cp -fru "$source_dir/$word/." "$SYNERGY_HOME/$word/"
		   if [ "$?" != "0" ]; then
				echo "[Error] Merging failed! to SYNERGY_HOME location"
				restore
			fi
		fi
	fi
	done
	
	echo Removing Exsisting WAR from SYNERGY HOME Location
	if [ -d "$SYNERGY_HOME""_old" ]; then
		rm -rf "$SYNERGY_HOME""_old"
	fi
	if [ "$?" != "0" ]; then
		echo "[Error] Old WAR Delete failed!"
		restore
	fi
	
	if [ -f "$SYNERGY_HOME""_old.war" ]; then
		rm -rf "$SYNERGY_HOME""_old.war"
	fi
	if [ "$?" != "0" ]; then
		echo "[Error] Old WAR Delete failed!"
		restore
	fi
	
	echo Successfully Upgraded
}
#*******************************************************************#

#****************** Removing ESCM-DataFiles Content Function *********************#
rm_df(){
	export IFS=";"
	for word in $compare_list; do
		if [ -d "$CATALINA_HOME/ESCM-DataFiles/$word" ]; then
			echo "Removing $word"
			rm -rf "$CATALINA_HOME/ESCM-DataFiles/$word"
		fi
	done
	if [ -d "$CATALINA_HOME/ESCM-DataFiles/unused_files" ]; then
		rm -rf "$CATALINA_HOME/ESCM-DataFiles/unused_files"
	fi
}
#*******************************************************************#

###### Taking Decision {Fresh, Upgrade:DF2War, War2War} #######
export IFS=";"
if [ -d "$CATALINA_HOME/ESCM-DataFiles" ]; then     ##Checking ESCM-DataFiles exist
    if [ -d "$CATALINA_HOME/ESCM-DataFiles/branding" ]; then      ##Checking images,lib,css inside ESCM-DataFiles exist
	##=============ESCM-DataFiles to WAR Upgrade::=============
		for word in $compare_list; do
			if [ -d "$CATALINA_HOME/ESCM-DataFiles/$word" ]; then
				echo "$word Found"
				flag=2
			else
				echo "$word Not Found in ESCM-DataFiles"
				flag=0
				echo "Inconsistent ESCM-DataFiles"
				exit 1
			fi
		done
		
    else
	##=============WAR to WAR Upgrade::=============
		for word in $compare_list; do
			if [ ! -d "$CATALINA_HOME/ESCM-DataFiles/$word" ]; then
				echo "$word Not Found"
				flag=3
			else
				echo "$word Found in ESCM-DataFiles"
				flag=0
				echo "Inconsistent ESCM-DataFiles"
				exit 1
			fi
		done
    fi
else
	##=============Fresh installation=============
	flag=1
fi
echo "Flag Value: $flag"

if [ -d "$Compare_War_location" ]; then
	rm -rf "$Compare_War_location"
fi

##############################################################

########################## Extract zip #######################
echo "Extracting Order.zip"
echo "war location: $citools_location"
unzip -o "$order_location/order.zip" -d "$citools_location"
if [ "$?" != "0" ]; then
    echo "[Error] order.zip unzip failed!"
    exit 1
fi
# cd "$order_location"
# cd ..
# DataFiles_location=$PWD
# echo DataFiles_location: $DataFiles_location

DataFiles_location=${order_location%w*}
echo DataFiles_location: $DataFiles_location
############ Get APP Name from SYNERGY_HOME ##########
appname=${SYNERGY_HOME##*/}
echo App Name: $appname
##############################################################

###### Deploying according to flag value #######
case "$flag" in                 ## case responds to flag
            "1" )
                echo ============================ 
				echo =    Fresh Installation    =	 
				echo ============================
				fresh
                break                    
                ;;
            "2" )         
                echo ======================================= 
				echo =    ESCM-DataFiles to WAR Upgrade    =	 
				echo =======================================
				backup
				new_war_copy
				df_copy
				compare_folder "$Compare_War_location/DF_WAR_Struct" "$Compare_War_location/new_war"
				rm_df
                break
                ;;
            "3" )
                echo ============================
				echo =    WAR to WAR Upgrade    =	 
				echo ============================
				backup
				new_war_copy
				old_war_copy
				compare_folder "$Compare_War_location/old_war" "$Compare_War_location/new_war"
                break
                ;;
esac
echo "Deployment Completed, proceed for next steps."
sh "$citools_location/CleanupScript/LinuxCleanupScript.sh" "$SYNERGY_HOME"
termin=$(date +"%s")
difftimelps=$(($termin-$begin))
echo -----------------------------------------------
echo Total Time Duration: "$(($difftimelps / 60)) minutes and $(($difftimelps % 60)) seconds"
exit 0
##############################################################

