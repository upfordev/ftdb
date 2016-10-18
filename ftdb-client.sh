#!/bin/bash

# Filename for the remote executable
FTDB_FILENAME='ftdb'
# Directory in user's home where we'll store anything FTDB related
LOCAL_FTDB_DIR="$HOME/.ftdb"
# This is where we'll store dumps of local database taken before replacing with remote
FTDB_BACK_DIR="$LOCAL_FTDB_DIR/backups"

# Prompt user for input. Read and print what the user inputted.
function read_prompt {
		# $1 what do we want from the user?
		# $2 default value to be printed when nothing inputted
		# $3 do not print input as typed, for password inputs
		local message="$1" default="$2" silent="$3" var="" command="read "
		if [ "$silent" == 'silent' ]; then command="$command -s"; fi
		$command -p "$message" var
		if [ -z "$var" ]; then var="$default"; fi
		echo "$var"
}

# Echo $1 and exit
function die {
		echo "$1"
		exit 1
}

# Prompt user for mysql superuser credentials
# Test connection, exit if can't connect
function mysql_read_root_credentials {
	mysql_root_u=$(read_prompt "Enter Mysql root username [root]: " "root")
	mysql_root_p=$(read_prompt "Enter Mysql password for $mysql_root_u: " "" "silent")
	echo -e "\nConnecting to local Mysql server as $mysql_root_u..."
	mysql -u $mysql_root_u -p$mysql_root_p -e ";"
	if [ $? == 0 ]; then
		echo "Connection succeeded"
	else
		die "Connection failed"
	fi
}

# Parse command options
while [[ ${1} ]]; do
	case "${1}" in
		#
		--h)
				remote_host=${2}
				shift
				;;
		#
		--u)
				remote_user=${2}
				# Remote's ftdb dir in user's home
				FTDB_REMOTE_HOME_DIR="/home/$remote_user/.ftdb"
				shift
				;;
		#
		--d)
				mysql_db=${2}
				shift
				;;
		#
		--p)
				remote_path=${2}
				shift
				;;
		# catch all for unknown options
		*)
			echo "Unknown parameter: ${1}" >&2
	esac

	if ! shift; then
		echo 'Missing parameter argument.' >&2
	fi
done

# Trigger remote database dump
echo "Executing remote database dump..."
ssh $remote_user@$remote_host $remote_path/$FTDB_FILENAME
if [ $? == 0 ]; then
	# Get the name of the remote dump file that was just created
	dump_file=$(ssh $remote_user@$remote_host ls -t $FTDB_REMOTE_HOME_DIR/\*.sql | head -1)
	echo "Remote database dump completed"
else
	die "Remote database dump failed"
fi

# Let's make sure all directories we need exist
mkdir -p $FTDB_BACK_DIR

echo "Downloading remote dump..."
scp $remote_user@$remote_host:$dump_file $LOCAL_FTDB_DIR/
if [ $? == 0 ]; then
	echo "Remote dump downloaded"
else
	die "Remote dump download failed"
fi

echo "Removing remote dump..."
ssh $remote_user@$remote_host rm $dump_file
if [ $? == 0 ]; then
	echo "Done"
else
	echo "Could not remove remote dump"
fi

mysql_read_root_credentials

echo "Dumping local copy of $mysql_db before replacing with remote..."
timestamp=$(date +%Y%m%d%H%M%S%N)
mysqldump -u $mysql_root_u -p$mysql_root_p $mysql_db > $FTDB_BACK_DIR/$mysql_db-$timestamp.sql
if [ $? == 0 ]; then
	echo "Dump available at $FTDB_BACK_DIR/$mysql_db-$timestamp.sql"
else
	die "Could not backup local copy of $mysql_db"
fi

# Drop and recreate current DB
echo "Emptying database $mysql_db..."
mysql -u $mysql_root_u -p$mysql_root_p -e "drop database $mysql_db; create database $mysql_db;"
if [ $? == 0 ]; then
	echo "Done"
else
	die "Could not empty and recreate $mysql_db"
fi

# Import remote dump
echo "Importing remote dump into $mysql_db..."
mysql -u $mysql_root_u -p$mysql_root_p $mysql_db < $(ls -t $LOCAL_FTDB_DIR/*.sql | head -1)
if [ $? == 0 ]; then
	echo "Done"
else
	die "Could not import remote dump into $mysql_db"
fi

exit 0
