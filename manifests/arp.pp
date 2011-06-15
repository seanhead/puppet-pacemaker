define ha::arp($address, $resource_stickiness="",$nic="", $ensure = present) {
	ha::crm::primitive { "ha-arp-${address}":
		resource_type   => "ocf:heartbeat:SendArp",
		monitor_interval => "5",
		ensure           => $ensure,
		resource_stickiness => $resource_stickiness,
	}
	
	if $ensure != absent {
		ha::crm::parameter { "ha-arp-${address}-arp":
			resource  => "ha-arp-${address}",
			parameter => "ip",
			value     => $address,
			require   => Ha::Crm::Primitive["ha-arp-${address}"],
		}
	}

        if $ensure != absent and $nic != "" {
                ha::crm::parameter { "ha-arp-${address}-nic":
                        resource  => "ha-arp-${address}",
                        parameter => "nic",
                        value     => $nic,
                        require   => Ha::Crm::Primitive["ha-arp-${address}"],
                }
        }
}

