class gourmestre (
  String[1] $user = 'gourmestre',
  String[1] $group = 'gourmestre',
  String[1] $app_dir = '/opt/gourmestre',
  String[1] $repo_url = 'https://github.com/tonguechaude/gourmestre.git',
  Boolean $manage_rust = true,
  String[1] $postgresql_version = '16',
) {
  if $manage_rust {
    class { 'rustup::global':
      purge_toolchains => true,
      purge_targets    => true,
    }
    rustup::global::toolchain { 'nightly':
      ensure => latest,
    }
    rustup::global::target { 'default nightly': }
  }

  class { 'postgresql::globals':
    manage_package_repo => true,
    version             => '16',
  }
  include postgresql::server

  postgresql::server::db { 'Gourmestre':
    user     => 'foo',
    password => postgresql::postgresql_password('foo', 'foobar'),
  }

  user { $user:
    ensure => present,
    system => true,
    home   => $app_dir,
    shell  => '/bin/bash',
  }

  group { $group:
    ensure => present,
    system => true,
  }

  file { $app_dir:
    ensure  => directory,
    owner   => $user,
    group   => $group,
    mode    => '0755',
    require => [User[$user], Group[$group]],
  }

  vcsrepo { $app_dir:
    ensure   => latest,
    provider => git,
    source   => $repo_url,
    owner    => $user,
    group    => $group,
    require  => File[$app_dir],
  }

  # Frontend build
  package { 'nodejs':
    ensure => present,
  }

  package { 'npm':
    ensure => present,
  }

  exec { 'npm install frontend':
    command => 'npm install',
    cwd     => "${app_dir}/frontend",
    path    => ['/usr/local/bin', '/usr/bin', '/bin'],
    user    => $user,
    require => [Vcsrepo[$app_dir], Package['npm']],
    creates => "${app_dir}/frontend/node_modules",
  }

  exec { 'npm build frontend':
    command => 'npm run build',
    cwd     => "${app_dir}/frontend",
    path    => ['/usr/local/bin', '/usr/bin', '/bin'],
    user    => $user,
    require => Exec['npm install frontend'],
    creates => "${app_dir}/frontend/dist",
  }

  # Backend Rust compilation
  exec { 'cargo build backend':
    command     => 'cargo build --release',
    cwd         => "${app_dir}/backend",
    path        => ['/usr/local/bin', '/usr/bin', '/bin', "/home/${user}/.cargo/bin"],
    user        => $user,
    environment => ["HOME=/home/${user}", "USER=${user}"],
    require     => [Vcsrepo[$app_dir], Rustup::Global::Toolchain['nightly']],
    creates     => "${app_dir}/backend/target/release/gourmestre",
    timeout     => 1800,
  }


}
