define ha::ip($address, $resource_stickiness="", $ensure = present) {
	ha::crm::primitive { "ha-ip-${address}":
		resource_type   => "ocf:heartbeat:IPaddr2",
		monitor_interval => "20",
		ensure           => $ensure,
		resource_stickiness => $resource_stickiness,
	}
	
	if $ensure != absent {
		ha::crm::parameter { "ha-ip-${address}-ip":
			resource  => "ha-ip-${address}",
			parameter => "ip",
			value     => $address,
			require   => Ha::Crm::Primitive["ha-ip-${address}"],
		}
	}
}

