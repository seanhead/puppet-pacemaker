define ha::crm::rscdefault($value, $ensure=present) {
	
    if($ha_cluster_dc == $fqdn) {
        if($ensure == absent) {
            exec { "Deleting Resource Default ${name}":
                command => "/usr/sbin/crm_attribute -t rsc_defaults -n ${name} -D",
                onlyif  => "/usr/sbin/crm_attribute -t rsc_defaults -n ${name} -G -Q",
            }
        } else {
            exec { "Setting Resource Default  ${name} to ${value}":
                command => "/usr/sbin/crm_attribute -t rsc_defaults -n ${name} -v ${value}",
                unless  => "/usr/bin/test `/usr/sbin/crm_attribute -t rsc_defaults -n ${name} -G -Q` = \"${value}\"",
            }
        }
    }
}
