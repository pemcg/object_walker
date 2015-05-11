#
# Nice general purpose
#
@walk_association_whitelist = { "MiqAeServiceServiceTemplateProvisionTask" => ["source", "destination", "miq_request", "miq_request_tasks", "service_resource"],
                                "MiqAeServiceServiceTemplateProvisionRequest" => ["miq_request", "miq_request_tasks", "requester", "resource", "source"],
                                "MiqAeServiceServiceTemplate" => ["service_resources"],
                                "MiqAeServiceServiceResource" => ["resource", "service_template"],
                                "MiqAeServiceMiqProvisionRequest" => ["miq_request", "miq_request_tasks", \
                                                                      "miq_provisions", "requester", "resource", "source", "vm_template"],
                                "MiqAeServiceMiqProvisionRequestTemplate" => ["miq_request", "miq_request_tasks"],
                                "MiqAeServiceMiqProvisionVmware" => ["source", "destination", "miq_provision_request", "miq_request", "miq_request_task", "vm", \
                                                                     "vm_template"],
                                "MiqAeServiceMiqProvisionRedhat" => [:ALL],
                                "MiqAeServiceMiqProvisionRedhatViaPxe" => [:ALL],
                                "MiqAeServiceVmVmware" => ["ems_cluster", "ems_folder", "resource_pool", "ext_management_system", "storage", "service", "hardware", \
                                                           "operating_system"],
                                "MiqAeServiceVmRedhat" => ["ems_cluster", "ems_folder", "resource_pool", "ext_management_system", "storage", "service", "hardware"],
                                "MiqAeServiceHardware" => ["nics", "guest_devices", "ports", "vm" ],
                                "MiqAeServiceUser" => ["current_group"],
                                "MiqAeServiceGuestDevice" => ["hardware", "lan", "network"]}

#
# Whitelist for dumping VM details from a button
#
@walk_association_whitelist = { "MiqAeServiceVmRedhat" => ["hardware", "host", "storage"],
                                "MiqAeServiceVmVmware" => ["hardware", "host", "storage"],
                                "MiqAeServiceHardware" => ["nics", "guest_devices", "ports", "storage_adapters" ],
                                "MiqAeServiceGuestDevice" => ["hardware", "lan", "network"] }

#
# Whitelist for dumping automation requests and tasks
#
@walk_association_whitelist = { "MiqAeServiceAutomationTask" => ["automation_request"] }
#
# Whitelist for dumping provisioning requests and tasks (e.g. call from the VM Provisioning State Machine)
#
@walk_association_whitelist = { "MiqAeServiceMiqProvisionRequest" => ["miq_request", "miq_request_tasks", \
                                                                      "miq_provisions", "requester", "resource", "source", "vm_template"],
                                "MiqAeServiceMiqProvisionRequestTemplate" => ["miq_request", "miq_request_tasks"],
                                "MiqAeServiceMiqProvisionVmware" => [:ALL],
                                "MiqAeServiceMiqProvisionRedhat" => [:ALL],
                                "MiqAeServiceMiqProvisionRedhatViaPxe" => [:ALL],
                                "MiqAeServiceUser" => ["current_group"] }
#
# Whitelist for dumping service requests (e.g. call from the Service Provision State Machone)
#
@walk_association_whitelist = { "MiqAeServiceServiceTemplateProvisionTask" => ["source", "destination", "miq_request", "miq_request_tasks", "service_resource"],
                                "MiqAeServiceServiceTemplateProvisionRequest" => ["miq_request", "miq_request_tasks", "requester", "resource", "source"],
                                "MiqAeServiceServiceTemplate" => ["service_resources"],
                                "MiqAeServiceServiceResource" => ["resource", "service_template"] }