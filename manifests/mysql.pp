define duply::mysql (
  $mysql_host = 'localhost',
  $mysql_user = root,
  $mysql_pass = undef,
  $db_backup_folder = '/root/db_backups',
  $ensure = present,
) {
    
  file { "/etc/duply/${name}/pre":
    content => template('duply/pre.erb'),
    ensure  => $ensure ? {
      absent  => absent,
      default => file
    },
    owner   => root,
    group   => 0,
    mode    => 0700,
    require => [File["/etc/duply/${name}"], Package['duplicity','duply']],
  }
    
  if ($ensure == present) {
    
    exec { "mkdir_mysql_db_temp_${name}":
      path    => [ '/bin', '/usr/bin' ],
      command => "mkdir -p ${db_backup_folder}",
      unless  => "test -d ${db_backup_folder}",
    }
    file { "mysql_db_temp_${name}" :
      path   => $db_backup_folder,
      ensure => directory,
      owner  => root,
      group  => 0,
      mode   => 0755,
      require => Exec["mkdir_mysql_db_temp_${name}"]
    }
  } else {
    file { "mysql_db_temp_${name}":
      ensure  => absent,
      recurse => true,
      purge => true,
      force => true,
    }
  }
  
  file { "/etc/duply/${name}/post":
    content => template('duply/post.erb'),
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