# Define: duply::profile
#
# Define Duply profiles
#
# Parameters:
#
# $ensure = [present | absent]
# $backend = ['file' | 'ftp' | 's3' | 's3+http' ]
# $destination is backup destination URI (without the backend scheme)
# $gpg_key = 'disabled' - disables encryption alltogether
#     $gpg_key = '<key1>[,<key2>]'; 
#   $gpg_password = 'pass' - encrypt with keys, sign with key1 if secret key 
#               available and use $gpg_password for sign & decrypt
# $gpg_password = 'passphrase' - symmetric encryption using passphrase only
# $backend_user = Backend username
# $backend_pass = Backend password
# $backup_filelist = a globbing list of included or excluded files/folders 
#           using '+' and '-'. Leave undefined to backup everything
#           add a '- **' line to exclude everything not explicitly included
#           make sure there is no whitespace at the beginning of lines
# $source = '/' Source path to backup
# $max_age = timeframe for keeping old backups
# $max_full_backups = Number of full backups to keep
# $max_fullbkp_age = forces a full backup if last full backup reaches a specified age
# $volsize = set the size of backup chunks to VOLSIZE MB
# $add_options = more duplicity command line options. Leave a separating space char at the end
# $automate = [true | false] schedule backup job using cron
# $minute, $hour, $monthday, $month = when backups will occur (default everyday at 1:05 AM
#
# Actions:
# - Creates a duply backup profile and cronjob
# - Backs up selected files
#
# Requires:
#
# Sample Usage:
#
#  duply::profile { 'mybackup': 
#  backend => 's3+http',
#  destination => 'com.yoursite.yourbucket',
#  backend_user => 'Your AWS Access ID',
#  backend_pass => 'Your AWS Secret Access Key',
#    backup_filelist => '+ /etc
# + /home
# - **'
#  }
#
# [Remember: No empty lines between comments and class definition]
define duply::profile (
  $ensure = present,
  $backend,
  $destination,
  $gpg_key = 'disabled',
  $gpg_password = undef,
  $backend_user = undef,
  $backend_pass = undef,
  $backup_filelist = undef,
  $source = '/',
  $max_age = '3M',
  $max_full_backups = '1',
  $max_fullbkp_age = '1M',
  $volsize = '25',
  $add_options = undef,
  $automate = true,
  $minute = 5,
  $hour = 1,
  $monthday = '*',
  $month = '*'
) {

  if ! ($backend in [ 'file', 'ftp', 's3', 's3+http' ]) {
    fail('Backend scheme parameter must be file, ftp, s3 or s3+http')
  }
  if (!$destination) {
    fail('You need to define a file destination for backups')
  }

  if ($backend == 'ftp') {
    Package <| tag == 'duplicity-ftp' |>
    
    if (!$backend_user) {
      fail('You need a user to connect over FTP')
    }
  }
  
  if ($backend == 's3' or $backend == 's3+http') {
    Package <| tag == 'duplicity-s3' |>
    
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
  
  if ($ensure == present) {
    file { "/etc/duply/${name}":
      ensure  => directory,
      owner  => root,
      group => 0,
      mode => 0700,
      require => File['/etc/duply']
    }
  } else {
    file { "/etc/duply/${name}":
      ensure  => absent,
      recurse => true,
      purge => true,
      force => true,
      require => File['/etc/duply']
    }
  }
  
  file { "/etc/duply/${name}/conf":
    content => template('duply/conf.erb'),
    require => [File["/etc/duply/${name}"], Package['duplicity','duply']],
    owner   => root, group => 0, mode => 0700,
    ensure  => $ensure ? {
      absent  => absent,
      default => file
    }
  }
  
  if ($backup_filelist) {
    file { "/etc/duply/${name}/exclude":
      content => "$backup_filelist",
      ensure  => $ensure ? {
        absent  => absent,
        default => file
      },
      owner   => root,
      group   => 0,
      mode    => 0700,
      require => [File["/etc/duply/${name}"], Package['duplicity','duply']],
    }
  }
    
  $log_file = "/var/log/duplicity_${name}.log"
  if ($automate and $ensure == present) {
    cron { "duply_${name}_backup_cron":
      command  => "duply ${name} backup_verify_purge --force > $log_file 2>&1",
      ensure   => present,
      user     => 'root',
      minute   => $minute,
      hour     => $hour,
      monthday => $monthday,
      month    => $month,
      require  => File["/etc/duply/${name}"],
    }
    
    file { "duply_${name}_logrotate" :
      path    => "/etc/logrotate.d/duplicity_${name}",
      content => template('duply/logrotate.erb'),
      ensure  => file,
      owner   => root,
      group   => 0,
      mode    => 0755,
      require => Cron["duply_${name}_backup_cron"]
    }
  } else {
    cron { "duply_${name}_backup_cron":
      command  => "duply ${name} backup_verify_purge --force > $log_file 2>&1",
      ensure   => absent,
      user     => 'root',
    }
    
    file { "duply_${name}_logrotate" :
      path    => "/etc/logrotate.d/duplicity_${name}",
      ensure  => absent,
    }
  }

}