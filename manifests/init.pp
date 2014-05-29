# Class: duply
#
# This module manages backups using Duply and Duplicity
#
# Parameters:
#
# $version = ['latest' | 'present']
#
# Actions:
#   - Installs duply, duplicity, and necessary packages based on storage backend
#
# Requires:
#
# Sample Usage:
#
#  class { 'duply': }
#
# [Remember: No empty lines between comments and class definition]
class duply (
  $version = 'present'
) {

  package {['duplicity','duply']: 
    ensure  => $version,
  }
  
  @package { 'ncftp':
    ensure => $version,
    tag => 'duplicity-ftp'
  }
  
  @package { 'python-boto':
    ensure => $version,
    tag => 'duplicity-s3'
  }

  file { '/etc/duply' :
    ensure => directory,
    owner  => root,
    group => 0,
    mode => 0755,
  }
}