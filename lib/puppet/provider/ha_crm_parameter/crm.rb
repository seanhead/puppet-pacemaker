require 'rexml/document'

Puppet::Type.type(:ha_crm_parameter).provide(:crm) do

	commands :crm_resource => "crm_resource"

	def create
		if resource[:meta] == :true
			crm_resource "-m", "-r", resource[:resource], "-p", resource[:key], "-v", resource[:value]
		else
			crm_resource "-r", resource[:resource], "-p", resource[:key], "-v", resource[:value]
		end
	end

	def destroy
		if resource[:meta] == :true
			crm_resource "-m", "-r", resource[:resource], "-d", resource[:key]
		else
			crm_resource "-r", resource[:resource], "-d", resource[:key]
		end
	end

	def exists?
		if resource[:only_run_on_dc] and (!(Facter.value(:ha_cluster_dc) == Facter.value(:fqdn) || Facter.value(:ha_cluster_dc) == Facter.value(:hostname)))
			true
		else
			cib = REXML::Document.new File.open("/var/lib/heartbeat/crm/cib.xml")
			if resource[:meta] == :true
				type = "meta"
			else
				type = "instance"
			end
			# Someone with some XPath skills can probably make this more efficient
			nvpair = REXML::XPath.first(cib, "//primitive[@id='#{resource[:resource]}']/#{type}_attributes/nvpair[@name='#{resource[:key]}']")
			nvpair = REXML::XPath.first(cib, "//master[@id='#{resource[:resource]}']/#{type}_attributes/nvpair[@name='#{resource[:key]}']") if nvpair.nil?
			nvpair = REXML::XPath.first(cib, "//clone[@id='#{resource[:resource]}']/#{type}_attributes/nvpair[@name='#{resource[:key]}']") if nvpair.nil?
			if nvpair.nil?
				false
			else
        if nvpair.attribute(:value).value == resource[:value]
				  true
        else
          false
        end
			end
		end
	end
end
