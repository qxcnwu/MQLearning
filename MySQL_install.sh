#!/bin/bash

# install mysql shell scripts
# config

user=mysql
group=mysql
# install dir
install_dir="/usr/local"
# soft link
link_dir="/usr/local/mysql"
# mysql configuration
cnf_path="/etc/mysql/my.cnf"
# mysql data dir
data_dir="/mdata/mysql_test_data"
# mysql binary package
mysql_tar=${1}
# auto create password save file
passwd_file="$HOME/mysql_temp_password"

function get_current_dir () {
    CRTDIR=$(pwd)
    echo "current work dir:" "${CRTDIR}"
}

#check if pkg has installed
function install_pkg () {
    dpkg -l|grep "$1" >& /dev/null
    if [ $? -ne 0 ];then
        apt-get install "$1" >& /dev/null
        echo "succeed install " "$1"
    else
        echo "$1" "is existsed installed"
    fi
}

function create_dir () {
    if [ -d "$1" ]; then
        echo "directory \"$1\" exists"
    else
        mkdir -p "$1" >& /dev/null
        echo "directory \"$1\" created"
    fi
}


# install libaio1
install_pkg "libaio1"
# install libncurses5
install_pkg "libncurses5"

#create group if not exists
grep -E "^$group" /etc/group >& /dev/null
if [ $? -ne 0 ];then
    groupadd $group
    echo "succeed create group mysql"
else
    echo "mysql group is existsed"
fi

#create user if not exists
grep -E "^$user" /etc/passwd >& /dev/null
if [ $? -ne 0 ]
then
    useradd -r -g $group $user
    echo "succeed create user mysql"
else
    echo "mysql user is existsed"
fi

# change work dir
cd ${install_dir} >& /dev/null || mkdir ${install_dir}

# get current work dir
get_current_dir

# unzip mysql binary
tar zxvf "${mysql_tar}"

# get file name
file_name=$(basename "${mysql_tar}" .tar.gz)

# create link
ln -sf "${file_name}" mysql
if [ $? -ne 0 ]
then
    echo "create link error"
else
    echo "create link successful"
fi

# change work dir
cd ${link_dir} || echo "no such link dir ${link_dir}"

# create dir mysql-files and data dir
create_dir "mysql-files"
create_dir ${data_dir}

# change owner
chmod 770 mysql-files
chown -R mysql . 
chgrp -R mysql . 

# create mysql config
if [ -f ${cnf_path} ]; then
    rm ${cnf_path}
    echo "my.cnf file deleted and created"
else
    echo "my.cnf file created"
fi

# write file
touch ${cnf_path}
cat<<EOF>>${cnf_path}
[mysql]
prompt = (\\u@\\h) [\\d]>\\
[mysqld]
port = 3306
user = mysql
datadir = ${data_dir}
log_error = error.log
log_timestamps = SYSTEM
explicit_defaults_for_timestamp = 1
EOF
echo "my.cnf writen default config"

# init files
bin/mysqld --initialize --user=mysql >& /dev/null

# get and save password
grep "A temporary password is generated" ${data_dir}/error.log|awk -F'localhost: ' '{print $2}' > "${passwd_file}"
cat "${passwd_file}"

# rsa start
bin/mysql_ssl_rsa_setup >& /dev/null

# change owner
chown -R root . >& /dev/null

# change owner
chown -R mysql data mysql-files >& /dev/null

# change owner
bin/mysqld_safe --user=mysql

# Next command is optional
cp support-files/mysql.server /etc/init.d/mysql.server >& /dev/null

# add path to ~/.bashrc
export PATH=$PATH:${link_dir}/bin
export PATH=$PATH:${link_dir}/support-files
echo "$HOME/.bashrc writen default config"

# auto service
systemctl enable mysql.service

# start service
systemctl start mysql.service