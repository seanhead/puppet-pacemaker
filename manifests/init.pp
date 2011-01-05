import "crm/primitive.pp"
import "stonith.pp"
import "ip.pp"

define ha::authkey($method, $key="") {
    if($method == "crc") {
        $changes = ["set ${name}/method ${method}"]
    } else {
        $changes = ["set ${name}/method ${method}", "set ${name}/key ${key}"]
    }

    augeas { "Setting /etc/ha.d/authkeys/${name}":
        changes => $changes,
        context => "/files/etc/ha.d/authkeys",
        require => File["/etc/ha.d/authkeys"],
    }
}

define ha::node($autojoin="any", $nodes=[], $use_logd="on", $compression="bz2",
                $keepalive="1", $warntime="5", $deadtime="10", $initdead="60", $authkey,
                $alert_email_address, $logfacility='none', $logfile='/var/log/ha-log', $debugfile='', $debuglevel='0') {

    Augeas { context => "/files/etc/ha.d/ha.cf" }

    $email_content = "Heartbeat config on ${fqdn} has changed."
    $joined_nodes = join_array_with_spaces($nodes)
    $email_bin = $operatingsystem ? {
        Debian => "/usr/bin/mail",
        Ubuntu => "/usr/bin/mail",
        default => "/bin/mail"
    }

    case $operatingsystem {
        RedHat,CentOS: {
            case $lsbmajdistrelease {
                5: {
                    package {
                        # Force x86_64 installation when running x64 as by default it pulls both and has a dependency on 32 bit perl
                        "pacemaker":
                            name => $architecture ? {
                                x86_64 => "pacemaker.x86_64",
                                default => "pacemaker",
                            },
                            # Can't lock version and specify architecture currently - see bug #2662 - also, don't really want puppet upgrading a live cluster
                            ensure  => "installed",
                            require => Package["heartbeat"];
                        "heartbeat":
                          # dependency on our yum::centos::five::clusterlabs class here
                            require => Yumrepo["clusterlabs"],
                            ensure => "installed";
                    }
                }
            }
        }
        Debian,Ubuntu: {
            package {
                "pacemaker":
                    ensure  => "installed",
                    require => Package["heartbeat"];
                "heartbeat":
                    ensure => "installed";
                "openais":
                    ensure => purged;
            }
        }
    }

    case $operatingsystem {
        # RHEL packages have this service bundled in with the heartbeat
        # packages.
        Debian,Ubuntu: {
            service {
                "logd":
                    ensure    => running,
                    hasstatus => true,
                    enable    => true,
                    require   => [Package["pacemaker"], Package["heartbeat"]];
            }
        }
    }
    service {
        "heartbeat":
            ensure    => running,
            hasstatus => true,
            enable    => true,
            require   => [Package["pacemaker"], Package["heartbeat"]];
    }

    file {
        "/etc/ha.d/authkeys":
            ensure => present,
            mode   => 0600;

        # ha.cf, only if it doesn't already exist
        # augeas will control settings, this just ensures that everything gets
        # initialized in the right order
        "/etc/ha.d/ha.cf":
            ensure   => present,
            replace  => false,
            mode     => 0644,
            owner    => "root",
            group    => "root",
            source   => "puppet:///modules/ha/etc/ha.d/ha.cf";

        # logd config, it's very simple and can be the same everywhere
        "/etc/ha.d/ha_logd.cf":
            ensure   => present,
            mode     => 0644,
            owner    => "root",
            group    => "root",
            content  => template('ha/ha_logd.cf.erb');
        "/etc/logd.cf":
            ensure   => link,
            target   => 'ha.d/ha_logd.cf';

        # Augeas lenses
        "/usr/share/augeas/lenses/hacf.aug":
            ensure => present,
            mode   => 0644,
            owner  => "root",
            group  => "root",
            source => "puppet:///modules/ha/usr/share/augeas/lenses/hacf.aug";
        "/usr/share/augeas/lenses/haauthkeys.aug":
            ensure => present,
            mode   => 0644,
            owner  => "root",
            group  => "root",
            source => "puppet:///modules/ha/usr/share/augeas/lenses/haauthkeys.aug";
    }

    augeas {
        "Setting /files/etc/ha.d/ha.cf/port":
            require => File["/etc/ha.d/ha.cf"],
            notify  => Exec["restart-email"],
            changes => "set udpport 694";
        "Setting /files/etc/ha.d/ha.cf/autojoin":
            require => File["/etc/ha.d/ha.cf"],
            notify  => Exec["restart-email"],
            changes => "set autojoin ${autojoin}";
        "Setting /files/etc/ha.d/ha.cf/debug":
            require => File["/etc/ha.d/ha.cf"],
            notify  => Exec["restart-email"],
            changes => "set debug ${debuglevel}";
        "Setting /files/etc/ha.d/ha.cf/use_logd":
            require => File["/etc/ha.d/ha.cf"],
            notify  => Exec["restart-email"],
            changes => "set use_logd ${use_logd}";
        "Setting /files/etc/ha.d/ha.cf/traditional_compression":
            require => File["/etc/ha.d/ha.cf"],
            notify  => Exec["restart-email"],
            changes => "set traditional_compression off";
        "Setting /files/etc/ha.d/ha.cf/compression":
            require => File["/etc/ha.d/ha.cf"],
            notify  => Exec["restart-email"],
            changes => "set compression ${compression}";
        "Setting /files/etc/ha.d/ha.cf/keepalive":
            require => File["/etc/ha.d/ha.cf"],
            notify  => Exec["restart-email"],
            changes => "set keepalive ${keepalive}";
        "Setting /files/etc/ha.d/ha.cf/warntime":
            require => File["/etc/ha.d/ha.cf"],
            notify  => Exec["restart-email"],
            changes => "set warntime ${warntime}";
        "Setting /files/etc/ha.d/ha.cf/deadtime":
            require => File["/etc/ha.d/ha.cf"],
            notify  => Exec["restart-email"],
            changes => "set deadtime ${deadtime}";
        "Setting /files/etc/ha.d/ha.cf/initdead":
            require => File["/etc/ha.d/ha.cf"],
            notify  => Exec["restart-email"],
            changes => "set initdead ${initdead}";
        "Setting /files/etc/ha.d/ha.cf/crm":
            require => File["/etc/ha.d/ha.cf"],
            notify  => Exec["restart-email"],
            changes => "set crm respawn";
        "Setting /files/etc/ha.d/ha.cf/node":
            require => File["/etc/ha.d/ha.cf"],
            notify  => Exec["restart-email"],
            changes => $joined_nodes ? { '' => "rm node", default => "set node '${joined_nodes}" };
        "Setting /files/etc/ha.d/authkeys/auth":
            context => "/files/etc/ha.d/authkeys",
            changes => "set auth ${authkey}",
            before  => Ha::Authkey[$authkey],
            notify  => Exec["restart-email"];
    }

    exec { "Send restart email":
        alias       => "restart-email",
        command     => "/bin/echo \"${email_content}\" | $email_bin -s \"Heartbeat restart required\" ${alert_email_address}",
        refreshonly => true,
    }
}

define ha::mcast($group, $port=694, $ttl=1) {
    augeas { "Configure multicast group on ${name}":
        context => "/files/etc/ha.d/ha.cf",
        changes => [
                    "set mcast[last()+1]/interface ${name}",
                    "set mcast[last()]/group ${group}",
                    "set mcast[last()]/port ${port}",
                    "set mcast[last()]/ttl ${ttl}",
                   ],
        onlyif  => "match mcast/interface[.='${name}'] size == 0",
        require => File["/etc/ha.d/ha.cf"],
    }

    augeas { "Disable broadcast on ${name}":
        context => "/files/etc/ha.d/ha.cf",
        changes => "rm bcast",
        require => File["/etc/ha.d/ha.cf"],
    }
}

define ha::ucast($directives) {
    # This only works if the ucast nodes are at the end of the file
    # Need a better way to detect if the current setting is already set
    # but "onlyif" doesn't lend too much support to our cause
    augeas { "Configure unicast nodes on ${name}":
        context => "/files/etc/ha.d/ha.cf",
        changes => ['rm ucast', augeas_array_to_changes('ucast', $directives)],
        require => File["/etc/ha.d/ha.cf"],
    }

    augeas { "Disable broadcast and multicast on ${name}":
        context => "/files/etc/ha.d/ha.cf",
        changes => [
            'rm bcast',
            'rm mcast',
        ],
        require => File["/etc/ha.d/ha.cf"],
    }
}

define ha::ucast($directives) {
    # This only works if the ucast nodes are at the end of the file
    # Need a better way to detect if the current setting is already set
    # but "onlyif" doesn't lend too much support to our cause
    augeas { "Configure unicast nodes on ${name}":
        context => "/files/etc/ha.d/ha.cf",
        changes => ['rm ucast', augeas_array_to_changes('ucast', $directives)],
    }

    augeas { "Disable broadcast and multicast on ${name}":
        context => "/files/etc/ha.d/ha.cf",
        changes => [
            'rm bcast',
            'rm mcast',
        ],
    }
}
