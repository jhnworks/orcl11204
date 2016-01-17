#!/bin/bash

PERSISTENT_DATA=/u01/app/oracle/data
export ORACLE_HOME=/u01/app/oracle/product/11.2.0.4/dbhome_1
export ORACLE_SID=$(hostname)

stop_database() {
	$ORACLE_HOME/bin/sqlplus / as sysdba << EOF
	shutdown abort
	exit
EOF
	exit
}
start_database() {
	$ORACLE_HOME/bin/sqlplus / as sysdba << EOF
	startup
	exit
EOF
}
create_pfile() {
	$ORACLE_HOME/bin/sqlplus -S / as sysdba << EOF
	set echo off pages 0 lines 200 feed off head off sqlblanklines off trimspool on trimout on
	spool $PERSISTENT_DATA/init_$(hostname).ora
	select 'spfile="'||value||'"' from v\$parameter where name = 'spfile';
	spool off
	exit
EOF
}

trap stop_database SIGTERM

printf "LISTENER=(DESCRIPTION_LIST=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=$(hostname))(PORT=1521))(ADDRESS=(PROTOCOL=IPC)(KEY=EXTPROC1521))))\n" > $ORACLE_HOME/network/admin/listener.ora
$ORACLE_HOME/bin/lsnrctl start

if [ ! -f ${PERSISTENT_DATA}/DATABASE_IS_SETUP ]; then
	sed -i "s/{{ db_create_file_dest }}/\/u01\/app\/oracle\/data\/$(hostname)/" /home/oracle/db_install.dbt
	sed -i "s/{{ oracle_base }}/\/u01\/app\/oracle/" /home/oracle/db_install.dbt
	sed -i "s/{{ database_name }}/$(hostname)/" /home/oracle/db_install.dbt
	$ORACLE_HOME/bin/dbca -silent -createdatabase -templatename /home/oracle/db_install.dbt -gdbname $(hostname) -sid $(hostname) -syspassword oracle -systempassword oracle -dbsnmppassword oracle
	create_pfile
	if [ $? -eq 0 ]; then
		touch ${PERSISTENT_DATA}/DATABASE_IS_SETUP
	fi
else
	mkdir -p /u01/app/oracle/admin/$(hostname)/adump
	$ORACLE_HOME/bin/sqlplus / as sysdba << EOF
	startup pfile=$PERSISTENT_DATA/init_$(hostname).ora
	exit
EOF
fi

tail -f /u01/app/oracle/diag/rdbms/$(hostname)/*/trace/alert_$(hostname).log &
wait
