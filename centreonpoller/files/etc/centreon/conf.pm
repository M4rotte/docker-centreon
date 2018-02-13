$centreon_config = {
       VarLib => "/var/lib/centreon",
       CentreonDir => "/usr/local/",
       "centreon_db" => "centreon",
       "centstorage_db" => "centreon_storage",
       "db_host" => "centreondb:3306",
       "db_user" => "centreon",
       "db_passwd" => 'centreon'
};

# Central or Poller ?
$instance_mode = "central";

# Centreon Centcore Command File
$cmdFile = "/var/lib/centreon/centcore.cmd";

# Deprecated format of Config file. 
$mysql_user = "centreon";
$mysql_passwd = 'centreon';
$mysql_host = "centreondb:3306";
$mysql_database_oreon = "centreon";
$mysql_database_ods = "centreon_storage";

1;

