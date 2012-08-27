# Class: duply
#
# This module manages backups using Duply and Duplicity
#
# Parameters:
#
#	$version = ['latest' | 'present']
#	$backend = ['file' | 'ftp' | 's3' | 's3+http' ]
#	$destination is backup destination URI (without the backend scheme)
#	$gpg_key = 'disabled' - disables encryption alltogether
#  		$gpg_key = '<key1>[,<key2>]'; 
#		$gpg_password = 'pass' - encrypt with keys, sign with key1 if secret key 
#								available and use $gpg_password for sign & decrypt
#	$gpg_password = 'passphrase' - symmetric encryption using passphrase only
#	$backend_user = Backend username
#	$backend_pass = Backend password
#	$backup_filelist = a globbing list of included or excluded files/folders 
#						using '+' and '-'. Leave undefined to backup everything
#						add a '- **' line to exclude everything not explicitly included
#						make sure there is no whitespace at the beginning of lines
#	$max_age = timeframe for keeping old backups
#	$max_full_backups = Number of full backups to keep
#	$max_fullbkp_age = forces a full backup if last full backup reaches a specified age
#	$volsize = set the size of backup chunks to VOLSIZE MB
#	$add_options = more duplicity command line options. Leave a separating space char at the end
#	$mysql = [true | false] backup MySQL database
#	$mysql_user = user to connect to MySQL database
#	$mysql_pass = password to connect to MySQL database
#	$mysql_host = MySQL database host
#	$db_backup_folder = folder to use for temporary database dumps
#	$automate = [true | false] schedule backup job using cron
#	$minute, $hour, $monthday, $month = when backups will occur (default everyday at 1:05 AM
#
# Actions:
#   - Installs duply, duplicity, and necessary packages based on storage backend
#	- Backs up selected files and all MySQL databases
#
# Requires:
#
# Sample Usage:
#
#  class { 'duply': 
#	 backend => 's3+http',
#	 destination => 'com.yoursite.yourbucket',
#	 backend_user => 'Your AWS Access ID',
#	 backend_pass => 'Your AWS Secret Access Key',
#    backup_filelist => '+ /etc
#	+ /home
#	- **'
#  }
#
# [Remember: No empty lines between comments and class definition]
class duply (
	$version = 'present',
	$backend,
	$destination,
	$gpg_key = 'disabled',
	$gpg_password = undef,
	$backend_user = undef,
	$backend_pass = undef,
	$backup_filelist = undef,
	$max_age = '3M',
	$max_full_backups = '1',
	$max_fullbkp_age = '1M',
	$volsize = '25',
	$add_options = undef,
	$mysql = false,
	$mysql_host = 'localhost',
	$mysql_user = root,
	$mysql_pass = undef,
	$db_backup_folder = '/root/db_backups',
	$automate = true,
	$minute = 5,
	$hour = 1,
	$monthday = '*',
	$month = '*'
){

  if ! ($backend in [ 'file', 'ftp', 's3', 's3+http' ]) {
    fail('Backend scheme parameter must be file, ftp, s3 or s3+http')
  }
  if (!$destination) {
    fail('You need to define a file destination for backups')
  }

  package {['duplicity','duply']: 
    ensure 	=> $version,
  }
  if ($backend == 'ftp') {
  	package {'ncftp':
  	  ensure => $version
  	}
    if (!$backend_user) {
      fail('You need a user to connect over FTP')
    }
  } 
  if ($backend == 's3' or $backend == 's3+http') {
  	package {'python-boto':
  	  ensure => $version
  	}
  	if ($add_options) {
  	  $more_options = "$add_options --s3-use-new-style"
  	} else {
  	  $more_options = '--s3-use-new-style'
  	}
    if (!$backend_user) {
      fail('You need to supply your Amazon Access Key ID as the user to backup to S3')
    }
    if (!$backend_pass) {
      fail('You need to supply your Amazon Secret Access Key as the password to backup to S3')
    }
  } else {
    if ($add_options) {
  	  $more_options = "$add_options"
    } else {
      $more_options = undef
    }
  }
  
  file { '/etc/duply' :
  	ensure => directory,
	owner  => root, group => 0, mode => 0755,
  }
  
  file { '/etc/duply/profile1':
  	ensure => directory,
  	owner  => root, group => 0, mode => 0700,
    require => File['/etc/duply']
  }
  
  file { 'configuration-file':
    path 	=> '/etc/duply/profile1/conf',
    content => template('duply/conf.erb'),
    require => [File['/etc/duply/profile1'], Package['duplicity','duply']],
    owner 	=> root, group => 0, mode => 0700,
    ensure 	=> file,
  }
  
  if ($backup_filelist) {
    file { 'backup-filelist' :
      path    => '/etc/duply/profile1/exclude',
      content => "$backup_filelist",
      ensure  => file,
      owner   => root, group => 0, mode => 0700,
      require => [File['/etc/duply/profile1'], Package['duplicity','duply']],
    }
  }
  
  if ($mysql) {
    file { 'pre-backup' :
      path    => '/etc/duply/profile1/pre',
      content => template('duply/pre.erb'),
      ensure  => file,
      owner   => root, group => 0, mode => 0700,
      require => [File['/etc/duply/profile1'], Package['duplicity','duply']],
    }
    
    file { 'db_temp' :
    	path   => '$db_backup_folder',
    	ensure => directory,
  	    owner  => root, group => 0, mode => 0755,
    }
    
    file { 'post-backup' :
      path    => '/etc/duply/profile1/post',
      content => template('duply/post.erb'),
      ensure  => file,
      owner   => root, group => 0, mode => 0700,
      require => [File['/etc/duply/profile1'], Package['duplicity','duply']],
    }
  }
  
  $log_file = '/var/log/duplicity.log'
  if ($automate) {
    cron { 'duply_backup_cron':
      command  => "duply profile1 backup_verify_purge --force > $log_file 2>&1",
	  ensure   => present,
      user 	   => 'root',
      minute   => $minute,
      hour     => $hour,
      monthday => $monthday,
      month    => $month,
      require  => File['/etc/duply/profile1'],
    }
    
    file { 'duply_logrotate' :
    	path    => '/etc/logrotate.d/duplicity',
    	content => template('duply/logrotate.erb'),
    	ensure  => file,
        owner   => root, group => 0, mode => 0755,
        require => Cron['duply_backup_cron']
    }
  } else {
  	cron { 'duply_backup_cron':
      command  => "duply profile1 backup_verify_purge --force > $log_file 2>&1",
	  ensure   => absent,
      user 	   => 'root',
  	}
    
    file { 'duply_logrotate' :
    	path    => '/etc/logrotate.d/duplicity',
    	ensure  => absent,
    }
  }
}