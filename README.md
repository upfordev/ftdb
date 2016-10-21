#ftdb
####Follow that DB!

A couple of shell scripts to automate creating and downloading a MySql database dump from a remote server and importing such dump into a local database server.

Covers both server and client side tasks.

##Requirements
###For the server
- sudo access
- root local MySql access

###For the client
- password less ssh access to the remote server
- root local MySql access

##Installation
###For the server
1. Clone this repository
2. `sudo cp ftdb/ftdb /usr/local/bin/`
3. `sudo ln -s /usr/local/bin/ftdb /bin/ftdb`
4. `sudo chmod 754 /usr/local/bin/ftdb`
5. You're all set! (see workflow below)

###For the client
1. Clone this repository
2. `chmod 754 ftdb/ftdb-client`
3. You're all set! Have your server admin set everything up for you to follow that database! (see workflow below)

##Basic workflow
1. Server sets up a database as _"followable"_ (is prompted for MySql root credentials)

 `ftdb --mode follow --db [DB_NAME] --dir [PROJECT_DIR]`

 **DB_NAME:** the name of the database

 **PROJECT_DIR:** path to some directory where the script will store config files and symlinks. Take note of this path since the client will need it.

2. Server sets up file permission for a server's user account to _"follow"_ that database

 `sudo ftdb --mode adduser --user [USER_NAME] --dir [PROJECT_DIR]`

 **USER_NAME:** server's username for the user we're setting up to be able to follow a database

 **PROJECT_DIR:** same as for 1

3. Server gives Client the options to run the client script with

 The Client needs to get the **PROJECT_DIR** and the **DB_NAME** from you

4. Client uses the client script to create and download a dump of the remote database and replace its local copy with the downloaded remote copy (is prompted for MySql root credentials)

 **Note that, by running this script, you're removing your local copy of the database before importing the remote's. As a safety measure, a dump of the database being removed is first saved in your home dir under .ftdb/backups**

 `./ftdb-client --h [HOST_NAME] --u [USER_NAME] --d [DB_NAME] --p [PROJECT_DIR]`

 **HOST_NAME:** remote server's host name

 **USER_NAME:** user account to login to remote server

 **DB_NAME:** name of the database in the remote server we want to replace our local database (of the same name) with

 **PROJECT_DIR:** path in the remote server as given by the server admin

 The user can now re run the command above as many times as wanted to get the latest remote database copy mounted locally without any further server actions needed

Server repeats step 1 any time it wants to make a new database _"followable"_

Server repeats steps 2, 3 any time it wants to make a user able to _follow_ a _followable_ database

##Undoing server changes
Use _unfollow_ mode to undo changes made by _follow_ mode (prompts for MySql root credentials):

`ftdb --mode unfollow --db [DB_NAME] --dir [PROJECT_DIR]`

Use _removeuser_ mode to undo changes made by _adduser_ mode:

`sudo ftdb --mode removeuser --user [USER_NAME] --dir [PROJECT_DIR]`

##Footprints
###On the server
- .ftdb directory created on home directory of every user that ran the client script at least once. Its purpose is just to temporarily store the database dump, which is removed after downloading to the client. Should be empty most of the time
- MySql user created: 'ftdb'@'localhost'
- MySql user granted permissions to run mysqldump on every _"followable"_ database (revoked on a per db basis using _"unfollow"_ mode)
- [PROJECT\_DIR]/.ftdb.conf: config values read when the client script runs (removed using _"unfollow"_ mode)
- [PROJECT\_DIR]/ftdb: symlink to /usr/local/bin/ftdb (removed using _"unfollow"_ mode)
- rX permissions on /usr/bin/local/ftdb and [PROJECT\_DIR] for every user added via _"adduser"_ mode (removed using _"removeuser"_ mode)

###On the client
- .ftdb directory created on user's home directory storing each dump downloaded from the server with filenames of the form

 `[DB_NAME]-[TIMESTAMP].sql`
 i.e: my\_db-20161018115423644443212.sql

- .ftdb/backups created on user's home directory storing each dump of the local database taken right before being replaced with the remote's dump, with filenames in the same form as above

 As of now, none of these dumps get removed by the script itself. The decision of when to discard dumps is left to the user.
